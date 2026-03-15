import 'dart:async';
import 'dart:convert';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../models/uwb_distance_event.dart';

/// Qorvo DW3110 UWB 하드웨어 UART 연동 서비스.
///
/// ## 지원 파싱 포맷 (라인 단위)
///
/// **1. SDK Native (SESSION_INFO_NTF)** — QM33 SDK 1.1.1 기본 출력:
///   ```
///   SESSION_INFO_NTF: {session_handle=1, ...,
///   [mac_address=0x0000], status="SUCCESS", distance[cm]=235, ...}
///   ```
///   - `mac_address` → robotTagToIdMap 키 (e.g. '0x0000')
///   - `distance[cm]` → cm 정수 → m 변환
///   - `humanTagId` 파라미터로 인간 태그 ID 지정
///
/// **2. CSV** (커스텀 펌웨어):
///   `TAG_W1,TAG_R1,2.650`
///
/// **3. JSON** (커스텀 펌웨어):
///   `{"h":"TAG_W1","r":"TAG_R1","d":2.650}`
///
/// ## 시리얼 설정
///   115200 baud, 8N1
///
/// ## macOS 설치 요구사항
///   `brew install libserialport`
///   DebugProfile.entitlements + Release.entitlements: com.apple.security.device.usb = true
class RealUwbService {
  /// robotTagId → robotId 매핑 (기본값 예시).
  ///
  /// SDK Native 포맷에서는 MAC 주소 문자열(e.g. '0x0000'),
  /// CSV/JSON 커스텀 포맷에서는 태그 이름(e.g. 'TAG_R1')을 키로 사용.
  ///
  /// 실제 운용 시 SetupService.config.robotMappings 로 대체됨
  /// (robot_screen.dart의 _buildRealTagMap() 참고).
  static const robotTagToIdMap = <String, String>{
    '0x0000': 'R1', // SDK 포맷: 로봇 1 MAC 주소
    '0x0001': 'R2', // SDK 포맷: 로봇 2 MAC 주소
    'TAG_R1': 'R1', // CSV/JSON 커스텀 포맷
    'TAG_R2': 'R2', // CSV/JSON 커스텀 포맷
  };

  final String portName;
  final int baudRate;

  /// SESSION_INFO_NTF 파싱 시 사용할 인간 태그 ID.
  /// CSV/JSON 포맷에서는 라인 내 ID가 우선 사용됨.
  final String humanTagId;

  static const _reconnectDelayMs = 2000;

  final _controller = StreamController<UwbDistanceEvent>.broadcast();
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<List<int>>? _byteSub;
  String _lineBuf = '';
  bool _disposed = false;
  Timer? _reconnectTimer;

  RealUwbService({
    required this.portName,
    this.baudRate = 115200,
    this.humanTagId = 'TAG_W1',
  }) {
    _open();
  }

  // ── 포트 연결 / 재연결 ─────────────────────────────────────────────────────

  void _open() {
    if (_disposed) return;
    try {
      _port = SerialPort(portName);
      if (!_port!.openReadWrite()) {
        _controller.addError(
            Exception('Cannot open $portName: ${SerialPort.lastError}'));
        _scheduleReconnect();
        return;
      }
      _port!.config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _reader = SerialPortReader(_port!);
      _byteSub = _reader!.stream.listen(
        _onBytes,
        onError: (Object e) {
          _controller.addError(e);
          _closePort();
          _scheduleReconnect();
        },
        onDone: () {
          _closePort();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _controller.addError(e);
      _scheduleReconnect();
    }
  }

  void _closePort() {
    _byteSub?.cancel();
    _reader?.close();
    _port?.close();
    _byteSub = null;
    _reader = null;
    _port = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(milliseconds: _reconnectDelayMs),
      _open,
    );
  }

  // ── 바이트 수신 / 라인 파싱 ───────────────────────────────────────────────

  void _onBytes(List<int> bytes) {
    _lineBuf += utf8.decode(bytes, allowMalformed: true);
    final lines = _lineBuf.split('\n');
    _lineBuf = lines.removeLast(); // 마지막 불완전 라인 버퍼 유지
    for (final raw in lines) {
      _parseLine(raw.trim());
    }
  }

  void _parseLine(String line) {
    if (line.isEmpty) return;
    try {
      if (line.startsWith('SESSION_INFO_NTF')) {
        _parseSessionInfoNtf(line);
      } else if (line.startsWith('{')) {
        _parseJson(line);
      } else if (line.contains(',')) {
        _parseCsv(line);
      }
    } catch (_) {
      // 파싱 실패 → 해당 라인 무시
    }
  }

  /// QM33 SDK 1.1.1 SESSION_INFO_NTF 파싱.
  ///
  /// 포맷:
  ///   SESSION_INFO_NTF: {..., [mac_address=0x0000], status="SUCCESS", distance[cm]=235, ...}
  ///
  /// - status="SUCCESS" 인 경우만 처리
  /// - mac_address가 robotTagToIdMap 키 → robotTagId
  /// - distance[cm] cm 정수 → m 변환
  void _parseSessionInfoNtf(String line) {
    if (!line.contains('status="SUCCESS"')) return;

    final macMatch =
        RegExp(r'\[mac_address=(0x[0-9A-Fa-f]+)\]').firstMatch(line);
    if (macMatch == null) return;
    final macAddr = macMatch.group(1)!.toLowerCase();

    final distMatch = RegExp(r'distance\[cm\]=(\d+)').firstMatch(line);
    if (distMatch == null) return;
    final distCm = int.tryParse(distMatch.group(1)!);
    if (distCm == null || distCm < 0) return;

    _emit(humanTagId, macAddr, distCm / 100.0);
  }

  /// CSV 포맷: `humanTagId,robotTagId,distanceM`
  void _parseCsv(String line) {
    final parts = line.split(',');
    if (parts.length < 3) return;
    final dist = double.tryParse(parts[2].trim());
    if (dist == null || dist < 0) return;
    _emit(parts[0].trim(), parts[1].trim(), dist);
  }

  /// JSON 포맷: `{"h":"TAG_W1","r":"TAG_R1","d":2.650}`
  void _parseJson(String line) {
    final map = jsonDecode(line) as Map<String, dynamic>;
    final h = map['h'] as String?;
    final r = map['r'] as String?;
    final d = (map['d'] as num?)?.toDouble();
    if (h == null || r == null || d == null || d < 0) return;
    _emit(h, r, d);
  }

  void _emit(String hTagId, String rTagId, double distanceM) {
    _controller.add(UwbDistanceEvent(
      humanTagId: hTagId,
      robotTagId: rTagId,
      distanceM: distanceM,
      timestamp: DateTime.now(),
    ));
  }

  // ── 공개 API ──────────────────────────────────────────────────────────────

  Stream<UwbDistanceEvent> get stream => _controller.stream;

  /// 시스템에서 사용 가능한 시리얼 포트 목록
  static List<String> get availablePorts => SerialPort.availablePorts;

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _closePort();
    _controller.close();
  }
}
