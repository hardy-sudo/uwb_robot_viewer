import 'package:flutter/material.dart';

enum RobotStatus { moving, stopped }

class RobotData {
  RobotData({
    required this.id,
    required this.color,
    required this.currentX,
    required this.currentY,
    this.status = RobotStatus.moving,
  });

  final String id;
  final Color color;
  double currentX;
  double currentY;
  RobotStatus status;
}
