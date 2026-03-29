import 'dart:async';
import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../models/uwb_distance_event.dart';
import '../services/dahua_robot_service.dart';
import '../services/mock_uwb_service.dart';
import '../services/real_uwb_service.dart';
import '../services/robot_service.dart';
import '../services/setup_service.dart';
import '../services/uwb_safety_service.dart';
import '../widgets/robot_dot.dart';
import '../widgets/grid_overlay.dart';

class RobotScreen extends StatefulWidget {
  const RobotScreen({super.key});
  @override
  State<RobotScreen> createState() => _RobotScreenState();
}

class _RobotScreenState extends State<RobotScreen> {
  final double maxX = 6.0;
  final double maxY = 6.0;

  late final RobotService _service;

  // ── UWB 서비스 (Mock ↔ Real 전환 가능) ─────────────────────────────────────
  bool _useMockUwb = true;
  MockUwbService? _mockUwb;
  RealUwbService? _realUwb;
  UwbSafetyService? _safetyService;
  StreamSubscription<List<RobotData>>? _sub;

  List<RobotData> _robots = [];

  @override
  void initState() {
    super.initState();
    final cfg = SetupService.instance.config;

    _service = DahuaRobotService(
      baseUrl: cfg.fmsBaseUrl,
      areaId: cfg.areaId,
      mapWidthMm: 200000,
      mapHeightMm: 200000,
    );

    // ── UWB 소스 선택 ────────────────────────────────────────────────────────
    _initUwb(mock: true);
  }

  // ── UWB 서비스 초기화 ────────────────────────────────────────────────────────

  void _initUwb({required bool mock, String? portName}) {
    _teardownUwb();

    final Stream<UwbDistanceEvent> uwbStream;
    final Map<String, String> tagMap;

    if (mock) {
      _mockUwb = MockUwbService();
      uwbStream = _mockUwb!.stream;
      tagMap = MockUwbService.robotTagToIdMap;
    } else {
      _realUwb = RealUwbService(portName: portName!);
      uwbStream = _realUwb!.stream;
      tagMap = _buildRealTagMap();
    }

    final cfg = SetupService.instance.config;
    _safetyService = UwbSafetyService(
      robotService: _service,
      uwbStream: uwbStream,
      robotTagToIdMap: tagMap,
      thresholdStop: cfg.thresholdStopM,
      thresholdResume: cfg.thresholdResumeM,
      cooldown: Duration(milliseconds: cfg.cooldownMs),
    );

    _sub = _safetyService!.stream.listen((robots) {
      if (mounted) setState(() => _robots = robots);
    });

    _useMockUwb = mock;
  }

  void _teardownUwb() {
    _sub?.cancel();
    _safetyService?.dispose();
    _mockUwb?.dispose();
    _realUwb?.dispose();
    _sub = null;
    _safetyService = null;
    _mockUwb = null;
    _realUwb = null;
  }

  /// SetupService.config.robotMappings 에서 tagId → robotId 맵 생성
  Map<String, String> _buildRealTagMap() {
    return {
      for (final m in SetupService.instance.config.robotMappings)
        if (m.tagId.isNotEmpty) m.tagId: m.robotId,
    };
  }

  @override
  void dispose() {
    _sub?.cancel();
    _safetyService?.dispose();
    _mockUwb?.dispose();
    _realUwb?.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── UWB 소스 선택 다이얼로그 ─────────────────────────────────────────────────

  void _showUwbSourceDialog() {
    final ports = RealUwbService.availablePorts;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UWB 소스 선택'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.science),
                title: const Text('Mock (시뮬레이션)'),
                subtitle: const Text('R1↔W1 코사인 파형, R2↔W2 안전 거리'),
                selected: _useMockUwb,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _initUwb(mock: true));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  '실 하드웨어 (UART 115200)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              if (ports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '연결된 시리얼 포트 없음\n(USB 케이블 연결 후 재시도)',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                for (final port in ports)
                  ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text(port),
                    selected: !_useMockUwb,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _initUwb(mock: false, portName: port));
                    },
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentLog = _safetyService?.log.reversed.take(5).toList() ?? [];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 지도 ────────────────────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: Stack(children: [
                    Positioned.fill(child: GridOverlay(maxX: maxX, maxY: maxY)),
                    for (final r in _robots) _marker(r, w, h),
                  ]),
                );
              }),
            ),

            const SizedBox(height: 20),

            // ── UWB Safety 상태 헤더 ────────────────────────────────────────
            _safetyStatusHeader(),

            const SizedBox(height: 8),

            // ── UWB 소스 배지 ────────────────────────────────────────────────
            Row(
              children: [
                _uwbSourceBadge(),
              ],
            ),

            const SizedBox(height: 12),

            // ── 로봇 상태 목록 ───────────────────────────────────────────────
            const Text('로봇 상태', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_robots.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              for (final r in _robots) _statusTile(r),

            // ── Safety 이벤트 로그 ──────────────────────────────────────────
            if (recentLog.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Safety 이벤트 로그',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final entry in recentLog) _logTile(entry),
            ],
          ],
        ),
      ),
    );
  }

  // ── UWB 소스 배지 ─────────────────────────────────────────────────────────

  Widget _uwbSourceBadge() {
    final isMock = _useMockUwb;
    final color = isMock ? Colors.blue : Colors.green;
    return GestureDetector(
      onTap: _showUwbSourceDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isMock ? Icons.science : Icons.usb, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isMock ? 'Mock' : _realUwb?.portName ?? 'Real UART',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.swap_horiz, size: 13, color: color),
        ]),
      ),
    );
  }

  // ── UWB Safety 상태 헤더 ──────────────────────────────────────────────────

  Widget _safetyStatusHeader() {
    final anyStopped = _robots.any((r) => r.safetyState == SafetyState.stoppedBySafety);
    final cfg = SetupService.instance.config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: anyStopped ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: anyStopped ? Colors.red : Colors.green,
        ),
      ),
      child: Row(children: [
        Icon(
          anyStopped ? Icons.warning_rounded : Icons.shield,
          color: anyStopped ? Colors.red : Colors.green,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          anyStopped ? 'UWB Safety — 정지 중인 로봇 있음' : 'UWB Safety — 전체 안전',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: anyStopped ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '  ▸ stop < ${cfg.thresholdStopM}m  |  resume > ${cfg.thresholdResumeM}m',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]),
    );
  }

  // ── 로봇 상태 타일 ────────────────────────────────────────────────────────

  Widget _statusTile(RobotData r) {
    final isStopped = r.status == RobotStatus.stopped;
    final isSafetyStopped = r.safetyState == SafetyState.stoppedBySafety;
    final isFault = r.deviceState == DeviceState.fault;
    final isOffline = r.deviceState == DeviceState.offline;
    final uwbDist = _safetyService?.latestMinDistances[r.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // 색상 인디케이터
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(shape: BoxShape.circle, color: r.color),
            ),
            const SizedBox(width: 8),

            // 로봇 ID
            SizedBox(width: 30, child: Text(r.id, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),

            // 좌표
            SizedBox(
              width: 160,
              child: Text(
                'X: ${r.currentX.toStringAsFixed(2)}  Y: ${r.currentY.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),

            // 이동 상태 뱃지
            _badge(
              isStopped ? 'STOPPED' : 'MOVING',
              isStopped ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 4),

            // Safety 상태 뱃지
            if (isSafetyStopped)
              _badge('SAFETY STOP', Colors.red, icon: Icons.warning_rounded)
            else
              _badge('SAFE', Colors.teal, icon: Icons.shield),
            const SizedBox(width: 4),

            // 기기 장치 상태 뱃지
            if (isFault)
              _badge('FAULT', Colors.yellow.shade700, icon: Icons.error_outline)
            else if (isOffline)
              _badge('OFFLINE', Colors.grey, icon: Icons.wifi_off),
            const SizedBox(width: 4),

            // pauseFlag 뱃지
            if (r.pauseFlag)
              _badge('PAUSE', Colors.deepOrange, icon: Icons.pause_circle_outline),
            const SizedBox(width: 8),

            // UWB 거리
            if (uwbDist != null)
              SizedBox(
                width: 72,
                child: Text(
                  'UWB ${uwbDist.toStringAsFixed(2)}m',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: uwbDist < 3.0
                        ? Colors.red
                        : uwbDist < 3.5
                            ? Colors.orange
                            : Colors.grey,
                  ),
                ),
              )
            else
              const SizedBox(width: 72),

            const Spacer(),

            // 수동 Stop 버튼
            ElevatedButton(
              onPressed: isStopped ? null : () => _service.sendStop(r.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Stop'),
            ),
            const SizedBox(width: 4),

            // Charge 버튼
            ElevatedButton(
              onPressed: isOffline ? null : () => _service.sendCharge(r.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Charge'),
            ),
          ]),

          // 배터리 / 위치 정보 (있을 때만 표시)
          if (r.battery != null || r.devicePosition != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Row(children: [
                if (r.battery != null) ...[
                  Icon(
                    r.battery! > 50
                        ? Icons.battery_full
                        : r.battery! > 20
                            ? Icons.battery_3_bar
                            : Icons.battery_alert,
                    size: 13,
                    color: r.battery! > 20 ? Colors.grey : Colors.red,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${r.battery}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: r.battery! > 20 ? Colors.grey.shade600 : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (r.devicePosition != null && r.devicePosition!.isNotEmpty) ...[
                  Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 2),
                  Text(
                    r.devicePosition!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 2),
        ],
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── Safety 이벤트 로그 타일 ───────────────────────────────────────────────

  Widget _logTile(SafetyLogEntry entry) {
    final isPause = entry.action == SafetyAction.pause;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        _badge(isPause ? 'PAUSE' : 'RESUME',
            isPause ? Colors.deepOrange : Colors.teal),
        const SizedBox(width: 8),
        Text(entry.robotId, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('← ${entry.causeHumanTagId}',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 8),
        Text('${entry.distanceM.toStringAsFixed(2)}m',
            style: TextStyle(
                fontFamily: 'monospace',
                color: isPause ? Colors.red : Colors.green)),
        const Spacer(),
        Text(
          _formatTime(entry.timestamp),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ]),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  // ── 지도 마커 ─────────────────────────────────────────────────────────────

  Widget _marker(RobotData r, double w, double h) {
    const dotSize = 24.0;
    const labelHeight = 14.0;
    const spacing = 2.0;
    const totalHeight = dotSize + spacing + labelHeight;

    final isStopped = r.status == RobotStatus.stopped;
    final isSafetyStopped = r.safetyState == SafetyState.stoppedBySafety;
    final isFault = r.deviceState == DeviceState.fault;
    final isOffline = r.deviceState == DeviceState.offline;

    Color dotColor;
    IconData? overlayIcon;
    if (isSafetyStopped) {
      dotColor = Colors.red;
      overlayIcon = Icons.warning_rounded;
    } else if (isFault) {
      dotColor = Colors.yellow.shade700;
      overlayIcon = Icons.error_outline;
    } else if (isOffline) {
      dotColor = Colors.grey;
      overlayIcon = Icons.wifi_off;
    } else if (isStopped) {
      dotColor = Colors.grey.shade400;
      overlayIcon = Icons.stop;
    } else {
      dotColor = r.color;
    }

    return Positioned(
      left: (r.currentX / maxX) * w - dotSize / 2,
      top: (1 - r.currentY / maxY) * h - totalHeight / 2,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          // 상태별 링 표시
          if (isSafetyStopped)
            Container(
              width: dotSize + 8,
              height: dotSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
              ),
            )
          else if (isFault)
            Container(
              width: dotSize + 8,
              height: dotSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.yellow.shade700, width: 2),
              ),
            )
          else if (isOffline)
            Container(
              width: dotSize + 8,
              height: dotSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 2),
              ),
            ),
          RobotDot(color: dotColor),
          if (overlayIcon != null)
            Icon(overlayIcon, color: Colors.white, size: 14),
        ]),
        const SizedBox(height: spacing),
        Text(r.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
