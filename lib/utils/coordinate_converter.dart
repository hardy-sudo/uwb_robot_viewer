import 'package:flutter/material.dart';

/// 맵 픽셀 좌표 ↔ 실제 좌표(m) 변환 유틸리티.
///
/// 좌표계:
///   - 이미지: 좌측 상단이 (0, 0)
///   - 실좌표: 좌측 하단이 (0, 0) — Y축 반전
///   - 해상도: pixelResolutionCm px당 cm (기본 5.0 → 1px = 5cm)
class CoordinateConverter {
  final double pixelResolutionCm;
  final Size mapSizePixels;

  const CoordinateConverter({
    required this.pixelResolutionCm,
    required this.mapSizePixels,
  });

  /// 픽셀 좌표 → 실좌표 (m)
  Offset pixelToReal(Offset pixel) {
    return Offset(
      pixel.dx * pixelResolutionCm / 100.0,
      (mapSizePixels.height - pixel.dy) * pixelResolutionCm / 100.0,
    );
  }

  /// 실좌표 (m) → 픽셀 좌표
  Offset realToPixel(Offset real) {
    return Offset(
      real.dx / pixelResolutionCm * 100.0,
      mapSizePixels.height - real.dy / pixelResolutionCm * 100.0,
    );
  }

  /// Ray Casting 알고리즘으로 점이 다각형 내부에 있는지 판별.
  /// polygon은 임의의 일관된 좌표계로 표현된 꼭짓점 리스트.
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (((a.dy <= point.dy && point.dy < b.dy) ||
              (b.dy <= point.dy && point.dy < a.dy)) &&
          point.dx <
              (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        crossings++;
      }
    }
    return crossings % 2 == 1;
  }
}
