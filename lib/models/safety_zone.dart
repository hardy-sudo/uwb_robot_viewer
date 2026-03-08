import 'package:flutter/material.dart';

class SafetyZone {
  final String id;
  String name;

  /// 꼭짓점 좌표 (0.0~1.0 정규화된 캔버스 비율)
  /// 실제 픽셀 변환은 CoordinateConverter 사용
  List<Offset> polygon;
  bool safetyEnabled;
  double? customThresholdStopM; // null이면 Relation 기본값 사용
  double? customThresholdResumeM;
  Color zoneColor;

  SafetyZone({
    required this.id,
    required this.name,
    List<Offset>? polygon,
    this.safetyEnabled = true,
    this.customThresholdStopM,
    this.customThresholdResumeM,
    this.zoneColor = const Color(0xFF4CAF50),
  }) : polygon = polygon ?? [];
}
