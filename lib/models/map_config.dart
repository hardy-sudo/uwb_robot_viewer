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
}
