import 'package:flutter/material.dart';

class GridOverlay extends StatelessWidget {
  const GridOverlay({super.key, required this.maxX, required this.maxY});
  final double maxX;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(maxX: maxX, maxY: maxY));
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.maxX, required this.maxY});
  final double maxX;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.grey.shade300;
    for (int i = 0; i <= maxX.toInt(); i++) {
      final x = (i / maxX) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int j = 0; j <= maxY.toInt(); j++) {
      final y = (j / maxY) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
