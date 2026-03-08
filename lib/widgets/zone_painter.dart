import 'package:flutter/material.dart';
import '../models/safety_zone.dart';

/// Safety Zone 다각형을 캔버스에 렌더링하는 CustomPainter.
/// polygon 좌표는 0.0~1.0 정규화 비율로 저장되어 있으며,
/// 실제 캔버스 크기에 맞게 스케일링하여 그린다.
class ZonePainter extends CustomPainter {
  final List<SafetyZone> zones;

  /// 현재 드로잉 모드에서 추가 중인 꼭짓점 (미완성 폴리곤)
  final List<Offset> draftPolygon;

  const ZonePainter({
    required this.zones,
    this.draftPolygon = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 기존 완성 Zone 렌더링
    for (final zone in zones) {
      if (zone.polygon.length < 3) continue;
      _drawZone(canvas, size, zone);
    }

    // 드로잉 중인 미완성 폴리곤
    if (draftPolygon.isNotEmpty) {
      _drawDraft(canvas, size, draftPolygon);
    }
  }

  void _drawZone(Canvas canvas, Size size, SafetyZone zone) {
    final color = zone.safetyEnabled ? Colors.green : Colors.red;
    // ON=반투명 녹색, OFF=반투명 빨강
    final fillColor = zone.safetyEnabled
        ? const Color(0x3300FF00)
        : const Color(0x33FF0000);

    final pts = zone.polygon
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    canvas.drawPath(
        path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // 영역 이름 라벨
    final centroid = _centroid(pts);
    final tp = TextPainter(
      text: TextSpan(
        text: zone.name,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centroid - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDraft(Canvas canvas, Size size, List<Offset> pts) {
    final scaled = pts
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < scaled.length - 1; i++) {
      canvas.drawLine(scaled[i], scaled[i + 1], linePaint);
    }
    // 첫 번째 꼭짓점과 마지막 꼭짓점 사이 점선 (닫힘 예상)
    if (scaled.length >= 2) {
      canvas.drawLine(
          scaled.last, scaled.first, linePaint..color = Colors.blue.shade200);
    }

    // 꼭짓점 마커
    for (final p in scaled) {
      canvas.drawCircle(
          p, 5, Paint()..color = Colors.blue..style = PaintingStyle.fill);
    }
  }

  Offset _centroid(List<Offset> pts) {
    double x = 0, y = 0;
    for (final p in pts) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  @override
  bool shouldRepaint(ZonePainter old) => true;
}
