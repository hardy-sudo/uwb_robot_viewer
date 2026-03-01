import 'dart:async';
import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../services/mock_robot_service.dart';
import '../services/mock_uwb_service.dart';
import '../services/robot_service.dart';
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
  late final MockUwbService _uwbService;
  late final UwbSafetyService _safetyService;
  late final StreamSubscription<List<RobotData>> _sub;
  List<RobotData> _robots = [];

  @override
  void initState() {
    super.initState();
    _service = MockRobotService();
    // Dahua 실서버 연동 시 아래로 교체:
    // import '../services/dahua_robot_service.dart';
    // _service = DahuaRobotService(
    //   baseUrl: 'http://192.168.1.100:7000',
    //   mapWidthMm: 200000,
    //   mapHeightMm: 200000,
    // );

    _uwbService = MockUwbService();

    _safetyService = UwbSafetyService(
      robotService: _service,
      uwbStream: _uwbService.stream,
      robotTagToIdMap: MockUwbService.robotTagToIdMap,
      thresholdStop: 3.0,
      thresholdResume: 3.1,
      cooldown: const Duration(milliseconds: 500),
    );

    _sub = _safetyService.stream.listen((robots) {
      setState(() => _robots = robots);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _safetyService.dispose();
    _uwbService.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentLog = _safetyService.log.reversed.take(5).toList();

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

  // ── UWB Safety 상태 헤더 ──────────────────────────────────────────────────

  Widget _safetyStatusHeader() {
    final anyStopped = _robots.any((r) => r.safetyState == SafetyState.stoppedBySafety);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: anyStopped ? Colors.deepOrange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: anyStopped ? Colors.deepOrange : Colors.green,
        ),
      ),
      child: Row(children: [
        Icon(
          anyStopped ? Icons.warning_rounded : Icons.shield,
          color: anyStopped ? Colors.deepOrange : Colors.green,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          anyStopped ? 'UWB Safety — 정지 중인 로봇 있음' : 'UWB Safety — 전체 안전',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: anyStopped ? Colors.deepOrange : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '  ▸ stop < 3.0m  |  resume > 3.1m',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]),
    );
  }

  // ── 로봇 상태 타일 ────────────────────────────────────────────────────────

  Widget _statusTile(RobotData r) {
    final isStopped = r.status == RobotStatus.stopped;
    final isSafetyStopped = r.safetyState == SafetyState.stoppedBySafety;
    final uwbDist = _safetyService.latestMinDistances[r.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
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
          _badge('SAFETY STOP', Colors.deepOrange,
              icon: Icons.warning_rounded)
        else
          _badge('SAFE', Colors.teal, icon: Icons.shield),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Stop'),
        ),
      ]),
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

    Color dotColor;
    IconData? overlayIcon;
    if (isSafetyStopped) {
      dotColor = Colors.deepOrange;
      overlayIcon = Icons.warning_rounded;
    } else if (isStopped) {
      dotColor = Colors.grey;
      overlayIcon = Icons.stop;
    } else {
      dotColor = r.color;
    }

    return Positioned(
      left: (r.currentX / maxX) * w - dotSize / 2,
      top: (1 - r.currentY / maxY) * h - totalHeight / 2,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          // Safety stop 시 주황 링 표시
          if (isSafetyStopped)
            Container(
              width: dotSize + 8,
              height: dotSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepOrange, width: 2),
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
