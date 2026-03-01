import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/robot_data.dart';
import 'robot_service.dart';

/// Dahua ICS RCS API 기반 실제 AMR 연동 서비스.
///
/// 위치 조회: POST /ics/out/device/list/deviceInfo  (폴링)
/// 정지 명령: POST /ics/out/controlDevice           (controlWay=0)
///
/// 좌표 변환: Dahua는 mm 단위 절대 좌표를 반환함.
/// [mapWidthMm] / [mapHeightMm] 을 기준으로 앱의 0~[maxX], 0~[maxY] 범위로 변환.
class DahuaRobotService implements RobotService {
  final String baseUrl;
  final int areaId;
  final Duration pollInterval;
  final double mapWidthMm;
  final double mapHeightMm;
  final double maxX;
  final double maxY;

  final _controller = StreamController<List<RobotData>>.broadcast();
  late final Timer _timer;

  // deviceName → RobotData: 색상을 폴 사이에 유지
  final Map<String, RobotData> _robotMap = {};

  static const _palette = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  DahuaRobotService({
    required this.baseUrl,
    this.areaId = 1,
    this.pollInterval = const Duration(milliseconds: 500),
    this.mapWidthMm = 200000,   // 기본값 200m 맵 너비
    this.mapHeightMm = 200000,  // 기본값 200m 맵 높이
    this.maxX = 6.0,
    this.maxY = 6.0,
  }) {
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  // ── 위치 폴링 ──────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ics/out/device/list/deviceInfo'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'areaId': areaId.toString(),
              'deviceType': '0',
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 1000) return;

      final dataList = body['data'];
      if (dataList is! List) return;

      int colorIdx = _robotMap.length;

      for (final item in dataList) {
        final deviceName = (item['deviceName'] as String?)?.trim() ?? '';
        if (deviceName.isEmpty) continue;

        // API 문서에 오타 있음: devicePostionRec (i 빠짐) / devicePositionRec 모두 대응
        final posRec = (item['devicePostionRec'] ?? item['devicePositionRec']) as List?;
        if (posRec == null || posRec.length < 2) continue;

        final xMm = (posRec[0] as num).toDouble();
        final yMm = (posRec[1] as num).toDouble();
        final state = (item['state'] as String?) ?? 'Idle';

        final x = (xMm / mapWidthMm * maxX).clamp(0.0, maxX);
        final y = (yMm / mapHeightMm * maxY).clamp(0.0, maxY);
        final status = _toRobotStatus(state);

        if (_robotMap.containsKey(deviceName)) {
          final r = _robotMap[deviceName]!;
          r.currentX = x;
          r.currentY = y;
          r.status = status;
        } else {
          final color = _palette[colorIdx % _palette.length];
          _robotMap[deviceName] = RobotData(
            id: deviceName,
            color: color,
            currentX: x,
            currentY: y,
            status: status,
          );
          colorIdx++;
        }
      }

      _controller.add(List.from(_robotMap.values));
    } on TimeoutException {
      // 서버 무응답 → 마지막 상태 유지
    } catch (_) {
      // 네트워크 오류 → 마지막 상태 유지
    }
  }

  /// Dahua 기기 상태 문자열 → RobotStatus 변환.
  /// InTask / InUpgrading → moving, 나머지(Idle·Offline·Fault·InCharging) → stopped
  RobotStatus _toRobotStatus(String state) {
    return switch (state) {
      'InTask' || 'InUpgrading' => RobotStatus.moving,
      _ => RobotStatus.stopped,
    };
  }

  // ── 정지 / 재가동 명령 ────────────────────────────────────────────────────

  @override
  void sendStop(String robotId) {
    if (_robotMap.containsKey(robotId)) {
      _robotMap[robotId]!.status = RobotStatus.stopped;
      _controller.add(List.from(_robotMap.values));
    }
    _controlDevice(robotId, controlWay: 0, stopType: 1); // 즉시 정지 (Safety)
  }

  @override
  void sendResume(String robotId) {
    if (_robotMap.containsKey(robotId)) {
      _robotMap[robotId]!.status = RobotStatus.moving;
      _controller.add(List.from(_robotMap.values));
    }
    _controlDevice(robotId, controlWay: 1);
  }

  Future<void> _controlDevice(
    String deviceNumber, {
    required int controlWay,
    int? stopType,
  }) async {
    try {
      final body = <String, dynamic>{
        'areaId': areaId,
        'deviceNumber': deviceNumber,
        'all': 0,
        'controlWay': controlWay,
      };
      if (stopType != null) body['stopType'] = stopType;

      await http
          .post(
            Uri.parse('$baseUrl/ics/out/controlDevice'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // 명령 전송 실패 시 다음 폴링에서 실제 상태로 복원됨
    }
  }

  // ── RobotService 인터페이스 ────────────────────────────────────────────────

  @override
  Stream<List<RobotData>> get stream => _controller.stream;

  @override
  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
