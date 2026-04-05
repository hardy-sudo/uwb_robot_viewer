import 'package:flutter/material.dart';

class SafetyZone {
  final String id;
  String name;

  /// 꼭짓점 좌표 (0.0~1.0 정규화된 캔버스 비율)
  /// 실제 픽셀 변환은 CoordinateConverter 사용
  List<Offset> polygon;

  /// 이 Zone에 속한 Anchor ID 목록 (UWB anchorId 기반 Zone 매핑용)
  List<String> anchorIds;

  bool safetyEnabled;
  double? customThresholdStopM; // null이면 Relation 기본값 사용
  double? customThresholdResumeM;
  Color zoneColor;

  SafetyZone({
    required this.id,
    required this.name,
    List<Offset>? polygon,
    List<String>? anchorIds,
    this.safetyEnabled = true,
    this.customThresholdStopM,
    this.customThresholdResumeM,
    this.zoneColor = const Color(0xFF4CAF50),
  })  : polygon = polygon ?? [],
        anchorIds = anchorIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'polygon': polygon.map((o) => {'dx': o.dx, 'dy': o.dy}).toList(),
        'anchorIds': anchorIds,
        'safetyEnabled': safetyEnabled,
        'customThresholdStopM': customThresholdStopM,
        'customThresholdResumeM': customThresholdResumeM,
        'zoneColor': zoneColor.value,
      };

  factory SafetyZone.fromJson(Map<String, dynamic> j) => SafetyZone(
        id: j['id'] as String,
        name: j['name'] as String,
        polygon: (j['polygon'] as List<dynamic>?)
                ?.map((o) => Offset(
                      (o['dx'] as num).toDouble(),
                      (o['dy'] as num).toDouble(),
                    ))
                .toList() ??
            [],
        anchorIds: (j['anchorIds'] as List<dynamic>?)?.cast<String>() ?? [],
        safetyEnabled: j['safetyEnabled'] as bool? ?? true,
        customThresholdStopM:
            (j['customThresholdStopM'] as num?)?.toDouble(),
        customThresholdResumeM:
            (j['customThresholdResumeM'] as num?)?.toDouble(),
        zoneColor: Color(j['zoneColor'] as int? ?? 0xFF4CAF50),
      );
}
