import 'dart:async';
import 'package:flutter/material.dart';
import '../models/robot_data.dart';
// import '../services/dahua_robot_service.dart'; // 실서버 연동 시 활성화
import '../services/mock_robot_service.dart';
import '../services/robot_service.dart';
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
  late final StreamSubscription<List<RobotData>> _sub;
  List<RobotData> _robots = [];

  @override
  void initState() {
    super.initState();
    // Mock 서비스 (개발/테스트용)
    _service = MockRobotService();
    // Dahua 실서버 연동 시 아래로 교체:
    // _service = DahuaRobotService(
    //   baseUrl: 'http://192.168.1.100:7000',
    //   areaId: 1,
    //   mapWidthMm: 200000,   // 실제 맵 너비(mm)
    //   mapHeightMm: 200000,  // 실제 맵 높이(mm)
    // );
    _sub = _service.stream.listen((robots) {
      setState(() => _robots = robots);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 지도
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
            const Text('로봇 상태', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_robots.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              for (final r in _robots) _statusTile(r),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(RobotData r) {
    final isStopped = r.status == RobotStatus.stopped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        // 로봇 색상 인디케이터
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: r.color),
        ),
        const SizedBox(width: 8),
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
        // 상태 뱃지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isStopped ? Colors.red : Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isStopped ? 'STOPPED' : 'MOVING',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        // Stop 버튼
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

  Widget _marker(RobotData r, double w, double h) {
    const dotSize = 24.0;
    const labelHeight = 14.0;
    const spacing = 2.0;
    const totalHeight = dotSize + spacing + labelHeight;
    final isStopped = r.status == RobotStatus.stopped;

    return Positioned(
      left: (r.currentX / maxX) * w - dotSize / 2,
      top: (1 - r.currentY / maxY) * h - totalHeight / 2,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          RobotDot(color: isStopped ? Colors.grey : r.color),
          if (isStopped) const Icon(Icons.stop, color: Colors.white, size: 14),
        ]),
        const SizedBox(height: spacing),
        Text(r.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
