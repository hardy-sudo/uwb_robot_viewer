import 'package:flutter/material.dart';

enum RobotStatus { moving, stopped }

/// UWB Safety 플랫폼 내부 제어 상태.
/// SAFE          : 플랫폼이 제어하지 않는 상태
/// stoppedBySafety : 플랫폼이 급정지(Pause)를 호출한 상태
enum SafetyState { safe, stoppedBySafety }

class RobotData {
  RobotData({
    required this.id,
    required this.color,
    required this.currentX,
    required this.currentY,
    this.status = RobotStatus.moving,
    this.safetyState = SafetyState.safe,
  });

  final String id;
  final Color color;
  double currentX;
  double currentY;
  RobotStatus status;

  /// UWB Safety 상태 — UwbSafetyService 가 갱신
  SafetyState safetyState;
}
