import 'package:flutter/material.dart';

class RobotData {
  RobotData({
    required this.id,
    required this.color,
    required this.currentX,
    required this.currentY,
  });

  final String id;
  final Color color;
  double currentX;
  double currentY;
}
