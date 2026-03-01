import 'package:flutter/material.dart';

enum RobotStatus { moving, stopped }

/// UWB Safety 플랫폼 내부 제어 상태.
/// SAFE          : 플랫폼이 제어하지 않는 상태
/// stoppedBySafety : 플랫폼이 급정지(Pause)를 호출한 상태
/// UWB Safety 플랫폼 내부 제어 상태.
/// SAFE          : 플랫폼이 제어하지 않는 상태
/// stoppedBySafety : 플랫폼이 급정지(Pause)를 호출한 상태
enum SafetyState { safe, stoppedBySafety }

/// Dahua 기기 장치 상태 (서버에서 수신한 실제 기기 상태).
/// normal  : 정상 (InTask / InUpgrading / Idle / InCharging)
/// fault   : 장애 (Fault)
/// offline : 오프라인 (Offline)
enum DeviceState { normal, fault, offline }

class RobotData {
  RobotData({
    required this.id,
    required this.color,
    required this.currentX,
    required this.currentY,
    this.status = RobotStatus.moving,
    this.safetyState = SafetyState.safe,
    this.deviceState = DeviceState.normal,
  });

  final String id;
  final Color color;
  double currentX;
  double currentY;
  RobotStatus status;

  /// UWB Safety 상태 — UwbSafetyService 가 갱신
  SafetyState safetyState;

  /// 기기 장치 상태 — DahuaRobotService 가 갱신 (Mock 에서는 항상 normal)
  DeviceState deviceState;
}
