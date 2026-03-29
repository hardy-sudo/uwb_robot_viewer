import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import 'robot_service.dart';

class MockRobotService implements RobotService {
  final _controller = StreamController<List<RobotData>>.broadcast();
  final _random = Random();
  late final Timer _timer;

  final List<RobotData> _robots = [
    RobotData(id: 'R1', color: Colors.blue,   currentX: 1.0, currentY: 1.0),
    RobotData(id: 'R2', color: Colors.green,  currentX: 3.0, currentY: 2.0),
    RobotData(id: 'R3', color: Colors.orange, currentX: 5.0, currentY: 5.0),
  ];

  MockRobotService() {
    // 500ms마다 moving 상태 로봇 위치 랜덤 이동
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    for (final r in _robots) {
      if (r.status == RobotStatus.stopped) continue;
      r.currentX = (r.currentX + (_random.nextDouble() - 0.5) * 0.3).clamp(0.0, 6.0);
      r.currentY = (r.currentY + (_random.nextDouble() - 0.5) * 0.3).clamp(0.0, 6.0);
    }
    _controller.add(List.from(_robots));
  }

  @override
  Stream<List<RobotData>> get stream => _controller.stream;

  @override
  void sendStop(String robotId) {
    final robot = _robots.firstWhere((r) => r.id == robotId);
    robot.status = RobotStatus.stopped;
    _controller.add(List.from(_robots));
  }

  @override
  void sendResume(String robotId) {
    final robot = _robots.firstWhere((r) => r.id == robotId);
    robot.status = RobotStatus.moving;
    _controller.add(List.from(_robots));
  }

  @override
  void sendCharge(String robotId) {
    // Mock: 충전 명령 — 상태만 stopped으로 변경 (실제 이동 없음)
    final robot = _robots.firstWhere((r) => r.id == robotId);
    robot.status = RobotStatus.stopped;
    _controller.add(List.from(_robots));
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
