import 'dart:ui';

enum ZoneShape { circle, polygon }

class MoveLensZone {
  final String id;
  String name;
  String label; // 입고/피킹/출고 등
  ZoneShape shape;

  // circle용 (0.0~1.0 정규화 좌표)
  Offset center;
  double radius;

  // polygon용 (0.0~1.0 정규화 좌표)
  List<Offset> polygon;

  MoveLensZone({
    required this.id,
    required this.name,
    this.label = '',
    this.shape = ZoneShape.polygon,
    this.center = const Offset(0.5, 0.5),
    this.radius = 0.1,
    List<Offset>? polygon,
  }) : polygon = polygon ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'label': label,
        'shape': shape.name,
        'centerX': center.dx,
        'centerY': center.dy,
        'radius': radius,
        'polygon': polygon.map((o) => {'x': o.dx, 'y': o.dy}).toList(),
      };

  factory MoveLensZone.fromJson(Map<String, dynamic> j) => MoveLensZone(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        label: j['label'] as String? ?? '',
        shape: ZoneShape.values.firstWhere(
          (s) => s.name == j['shape'],
          orElse: () => ZoneShape.polygon,
        ),
        center: Offset(
          (j['centerX'] as num?)?.toDouble() ?? 0.5,
          (j['centerY'] as num?)?.toDouble() ?? 0.5,
        ),
        radius: (j['radius'] as num?)?.toDouble() ?? 0.1,
        polygon: (j['polygon'] as List<dynamic>?)
                ?.map((e) => Offset(
                      (e['x'] as num).toDouble(),
                      (e['y'] as num).toDouble(),
                    ))
                .toList() ??
            [],
      );

  /// 주어진 정규화 좌표(x, y)가 이 Zone 안에 있는지 판별
  bool contains(double x, double y) {
    if (shape == ZoneShape.circle) {
      final dx = x - center.dx;
      final dy = y - center.dy;
      return dx * dx + dy * dy <= radius * radius;
    } else {
      return _pointInPolygon(x, y);
    }
  }

  bool _pointInPolygon(double px, double py) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      if ((yi > py) != (yj > py) &&
          px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}
