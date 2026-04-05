import 'package:flutter/material.dart';

class MapConfig {
  final String id;
  String locationId;
  String imageUrl; // 맵 이미지 URL (빈 문자열이면 미설정)
  double pixelResolutionCm; // 1px = N cm, 기본 5.0
  Offset origin; // (0,0) = 좌측 하단
  Size mapSizePixels;

  MapConfig({
    required this.id,
    required this.locationId,
    this.imageUrl = '',
    this.pixelResolutionCm = 5.0,
    this.origin = Offset.zero,
    this.mapSizePixels = Size.zero,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'locationId': locationId,
        'imageUrl': imageUrl,
        'pixelResolutionCm': pixelResolutionCm,
        'originDx': origin.dx,
        'originDy': origin.dy,
        'mapWidthPx': mapSizePixels.width,
        'mapHeightPx': mapSizePixels.height,
      };

  factory MapConfig.fromJson(Map<String, dynamic> j) => MapConfig(
        id: j['id'] as String,
        locationId: j['locationId'] as String,
        imageUrl: j['imageUrl'] as String? ?? '',
        pixelResolutionCm:
            (j['pixelResolutionCm'] as num?)?.toDouble() ?? 5.0,
        origin: Offset(
          (j['originDx'] as num?)?.toDouble() ?? 0.0,
          (j['originDy'] as num?)?.toDouble() ?? 0.0,
        ),
        mapSizePixels: Size(
          (j['mapWidthPx'] as num?)?.toDouble() ?? 0.0,
          (j['mapHeightPx'] as num?)?.toDouble() ?? 0.0,
        ),
      );
}
