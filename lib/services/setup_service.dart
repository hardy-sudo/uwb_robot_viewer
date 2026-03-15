import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/setup_config.dart';

enum TestStatus { idle, running, success, failure }

class HeartbeatAttempt {
  final int index;
  final TestStatus status;
  final String message;

  const HeartbeatAttempt({
    required this.index,
    required this.status,
    this.message = '',
  });
}

class SetupService {
  static final instance = SetupService._();
  SetupService._();

  final config = SetupConfig();

  final List<SetupConfig> _centers = [];

  /// 등록된 센터 목록 (불변 뷰)
  List<SetupConfig> get centers => List.unmodifiable(_centers);

  /// 센터 등록 (동일 centerName이 있으면 덮어씀)
  void addCenter(SetupConfig config) {
    if (config.centerName.isEmpty) return;
    _centers.removeWhere((c) => c.centerName == config.centerName);
    _centers.add(config);
  }

  /// FMS에서 로봇 ID 목록 조회
  Future<List<String>> loadRobotIds() async {
    final response = await http
        .post(
          Uri.parse('${config.fmsBaseUrl}/ics/out/device/list/deviceInfo'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'areaId': config.areaId.toString(),
            'deviceType': '0',
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 1000) {
      throw Exception('code=${body['code']}: ${body['desc'] ?? ''}');
    }
    return (body['data'] as List)
        .map((e) => ((e['deviceName'] as String?) ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Heartbeat Test: 1Hz × 5회 호출, 스트림으로 결과 방출
  Stream<HeartbeatAttempt> heartbeatTest() async* {
    for (int i = 1; i <= 5; i++) {
      yield HeartbeatAttempt(index: i, status: TestStatus.running, message: '...');
      try {
        final response = await http
            .post(
              Uri.parse('${config.fmsBaseUrl}/ics/out/device/list/deviceInfo'),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: jsonEncode({
                'areaId': config.areaId.toString(),
                'deviceType': '0',
              }),
            )
            .timeout(const Duration(seconds: 3));

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200 && body['code'] == 1000) {
          yield HeartbeatAttempt(index: i, status: TestStatus.success, message: 'OK');
        } else {
          yield HeartbeatAttempt(
              index: i, status: TestStatus.failure, message: 'code=${body['code']}');
        }
      } catch (e) {
        final msg = e.toString().split('\n').first;
        yield HeartbeatAttempt(index: i, status: TestStatus.failure, message: msg);
      }
      if (i < 5) await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Safety Function Test: Pause → 3초 대기 → Resume
  Stream<String> safetyFunctionTest(String robotId) async* {
    yield '▶ Pause 전송 → $robotId';
    try {
      await _controlDevice(robotId, controlWay: 0, stopType: 1);
      yield '✓ Pause 성공';
    } catch (e) {
      yield '✗ Pause 실패: $e';
      return;
    }

    for (int s = 3; s > 0; s--) {
      yield '  대기 중... ${s}s';
      await Future.delayed(const Duration(seconds: 1));
    }

    yield '▶ Resume 전송 → $robotId';
    try {
      await _controlDevice(robotId, controlWay: 1);
      yield '✓ Resume 성공';
      yield '✓ Safety Function Test PASSED';
    } catch (e) {
      yield '✗ Resume 실패: $e';
    }
  }

  Future<void> _controlDevice(
    String robotId, {
    required int controlWay,
    int? stopType,
  }) async {
    final body = <String, dynamic>{
      'areaId': config.areaId,
      'deviceNumber': robotId,
      'all': 0,
      'controlWay': controlWay,
    };
    if (stopType != null) body['stopType'] = stopType;

    final response = await http
        .post(
          Uri.parse('${config.fmsBaseUrl}/ics/out/controlDevice'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    final resBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || resBody['code'] != 1000) {
      throw Exception('code=${resBody['code']}');
    }
  }
}
