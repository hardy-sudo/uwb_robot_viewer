import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../../models/movelens_center.dart';
import '../../../models/movelens_zone.dart';
import '../../../services/movelens_service.dart';

class MoveLensMapAnnotationTab extends StatefulWidget {
  final MoveLensCenter center;

  const MoveLensMapAnnotationTab({super.key, required this.center});

  @override
  State<MoveLensMapAnnotationTab> createState() =>
      _MoveLensMapAnnotationTabState();
}

class _MoveLensMapAnnotationTabState extends State<MoveLensMapAnnotationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = MoveLensService.instance;
  final _urlCtrl = TextEditingController();

  bool _drawingMode = false;
  ZoneShape _drawShape = ZoneShape.polygon;
  final List<Offset> _draftPoints = [];

  // Circle 드래그용
  Offset? _circleCenter;
  double _circleRadius = 0.0;
  bool _draggingCircle = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.center.mapImageUrl;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _saveMapUrl() {
    widget.center.mapImageUrl = _urlCtrl.text.trim();
    _svc.updateCenter(widget.center);
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('맵 이미지 URL 저장됨')));
  }

  void _onCanvasTap(TapUpDetails d, BoxConstraints box) {
    if (!_drawingMode || _drawShape == ZoneShape.circle) return;
    final x = d.localPosition.dx / box.maxWidth;
    final y = d.localPosition.dy / box.maxHeight;
    setState(() {
      _draftPoints.add(Offset(x.clamp(0, 1), y.clamp(0, 1)));
    });
  }

  void _onPanStart(DragStartDetails d, BoxConstraints box) {
    if (!_drawingMode || _drawShape != ZoneShape.circle) return;
    final x = d.localPosition.dx / box.maxWidth;
    final y = d.localPosition.dy / box.maxHeight;
    setState(() {
      _circleCenter = Offset(x.clamp(0, 1), y.clamp(0, 1));
      _circleRadius = 0.0;
      _draggingCircle = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, BoxConstraints box) {
    if (!_draggingCircle || _circleCenter == null) return;
    final x = d.localPosition.dx / box.maxWidth;
    final y = d.localPosition.dy / box.maxHeight;
    final dx = x - _circleCenter!.dx;
    final dy = (y - _circleCenter!.dy) * (box.maxHeight / box.maxWidth);
    setState(() {
      _circleRadius = (dx * dx + dy * dy) < 0.0001
          ? 0.01
          : (dx.abs() + dy.abs()) / 2;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_draggingCircle || _circleCenter == null) return;
    setState(() => _draggingCircle = false);
    if (_circleRadius > 0.01) {
      _showZoneNameDialog(ZoneShape.circle);
    }
  }

  void _completePolygon() {
    if (_draftPoints.length < 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('최소 3개 꼭짓점이 필요합니다')));
      return;
    }
    _showZoneNameDialog(ZoneShape.polygon);
  }

  void _showZoneNameDialog(ZoneShape shape) {
    final nameCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zone 이름 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Zone 이름 *',
                hintText: '예: 입고 Zone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: '역할 라벨',
                hintText: '입고 / 피킹 / 출고 / 저장',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              _saveZone(shape, nameCtrl.text.trim(), labelCtrl.text.trim());
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _saveZone(ZoneShape shape, String name, String label) {
    if (shape == ZoneShape.circle && _circleCenter != null) {
      _svc.addZone(
        widget.center,
        name: name,
        label: label,
        shape: ZoneShape.circle,
        polygon: [],
        centerX: _circleCenter!.dx,
        centerY: _circleCenter!.dy,
        radius: _circleRadius,
      );
    } else {
      _svc.addZone(
        widget.center,
        name: name,
        label: label,
        shape: ZoneShape.polygon,
        polygon: List<Offset>.from(_draftPoints),
      );
    }
    setState(() {
      _drawingMode = false;
      _draftPoints.clear();
      _circleCenter = null;
      _circleRadius = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // 맵 URL 입력
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: '맵 이미지 URL',
                    hintText: 'http://...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveMapUrl,
                child: const Text('적용'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 그리기 툴바
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              ToggleButtons(
                isSelected: [
                  _drawShape == ZoneShape.polygon,
                  _drawShape == ZoneShape.circle
                ],
                onPressed: (i) => setState(
                    () => _drawShape = i == 0 ? ZoneShape.polygon : ZoneShape.circle),
                borderRadius: BorderRadius.circular(6),
                children: const [
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('폴리곤')),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('원형')),
                ],
              ),
              const SizedBox(width: 8),
              if (!_drawingMode)
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _drawingMode = true;
                    _draftPoints.clear();
                    _circleCenter = null;
                    _circleRadius = 0.0;
                  }),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Zone 추가'),
                )
              else ...[
                if (_drawShape == ZoneShape.polygon)
                  ElevatedButton.icon(
                    onPressed: _completePolygon,
                    icon: const Icon(Icons.check),
                    label: const Text('완료'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _drawingMode = false;
                    _draftPoints.clear();
                    _circleCenter = null;
                  }),
                  child: const Text('취소'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 캔버스 + Zone 목록
        Expanded(
          child: Row(
            children: [
              // 캔버스
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 6, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: LayoutBuilder(builder: (_, box) {
                      return GestureDetector(
                        onTapUp: (d) => _onCanvasTap(d, box),
                        onPanStart: (d) => _onPanStart(d, box),
                        onPanUpdate: (d) => _onPanUpdate(d, box),
                        onPanEnd: _onPanEnd,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            painter: _MapCanvasPainter(
                              zones: widget.center.zones,
                              draftPoints: _draftPoints,
                              circleCenter: _circleCenter,
                              circleRadius: _circleRadius,
                              drawingMode: _drawingMode,
                              drawShape: _drawShape,
                              imageUrl: widget.center.mapImageUrl,
                            ),
                            size: Size(box.maxWidth, box.maxHeight),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Zone 목록
              SizedBox(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  child: _ZoneList(
                    center: widget.center,
                    onDelete: (z) {
                      _svc.deleteZone(widget.center, z.id);
                      setState(() {});
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────

class _ZoneList extends StatelessWidget {
  final MoveLensCenter center;
  final void Function(MoveLensZone) onDelete;

  const _ZoneList({required this.center, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final zones = center.zones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Zones (${zones.length})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: zones.isEmpty
              ? Center(
                  child: Text('Zone 없음',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)))
              : ListView.builder(
                  itemCount: zones.length,
                  itemBuilder: (_, i) {
                    final z = zones[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          z.shape == ZoneShape.circle
                              ? Icons.circle_outlined
                              : Icons.pentagon_outlined,
                          size: 20,
                          color: _zoneColor(i),
                        ),
                        title: Text(z.name,
                            style:
                                const TextStyle(fontSize: 13)),
                        subtitle: z.label.isNotEmpty
                            ? Text(z.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600]))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => onDelete(z),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _zoneColor(int i) {
    const colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];
    return colors[i % colors.length];
  }
}

// ────────────────────────────────────────────────────

class _MapCanvasPainter extends CustomPainter {
  final List<MoveLensZone> zones;
  final List<Offset> draftPoints;
  final Offset? circleCenter;
  final double circleRadius;
  final bool drawingMode;
  final ZoneShape drawShape;
  final String imageUrl;

  _MapCanvasPainter({
    required this.zones,
    required this.draftPoints,
    required this.circleCenter,
    required this.circleRadius,
    required this.drawingMode,
    required this.drawShape,
    required this.imageUrl,
  });

  static const _zoneColors = [
    Color(0x332196F3), // blue
    Color(0x334CAF50), // green
    Color(0x33FF9800), // orange
    Color(0x339C27B0), // purple
    Color(0x33F44336), // red
    Color(0x33009688), // teal
  ];

  static const _zoneBorders = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 그리드
    _drawGrid(canvas, size);

    // 기존 Zone 그리기
    for (int i = 0; i < zones.length; i++) {
      _drawZone(canvas, size, zones[i], i);
    }

    // 드래프트 그리기
    if (drawingMode) {
      if (drawShape == ZoneShape.polygon && draftPoints.isNotEmpty) {
        _drawDraftPolygon(canvas, size);
      } else if (drawShape == ZoneShape.circle && circleCenter != null) {
        _drawDraftCircle(canvas, size);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
    const divisions = 10;
    for (int i = 0; i <= divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawZone(Canvas canvas, Size size, MoveLensZone zone, int idx) {
    final fillColor = _zoneColors[idx % _zoneColors.length];
    final borderColor = _zoneBorders[idx % _zoneBorders.length];
    final fill = Paint()..color = fillColor;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (zone.shape == ZoneShape.circle) {
      final cx = zone.center.dx * size.width;
      final cy = zone.center.dy * size.height;
      final r = zone.radius * size.width;
      canvas.drawCircle(Offset(cx, cy), r, fill);
      canvas.drawCircle(Offset(cx, cy), r, border);
    } else if (zone.polygon.length >= 3) {
      final path = Path()
        ..moveTo(zone.polygon[0].dx * size.width,
            zone.polygon[0].dy * size.height);
      for (int i = 1; i < zone.polygon.length; i++) {
        path.lineTo(zone.polygon[i].dx * size.width,
            zone.polygon[i].dy * size.height);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
    }

    // 라벨
    final label = zone.label.isNotEmpty ? zone.label : zone.name;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: borderColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    double tx, ty;
    if (zone.shape == ZoneShape.circle) {
      tx = zone.center.dx * size.width - tp.width / 2;
      ty = zone.center.dy * size.height - tp.height / 2;
    } else if (zone.polygon.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final p in zone.polygon) {
        sumX += p.dx;
        sumY += p.dy;
      }
      tx = sumX / zone.polygon.length * size.width - tp.width / 2;
      ty = sumY / zone.polygon.length * size.height - tp.height / 2;
    } else {
      return;
    }
    tp.paint(canvas, Offset(tx, ty));
  }

  void _drawDraftPolygon(Canvas canvas, Size size) {
    final pts = draftPoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < pts.length - 1; i++) {
      canvas.drawLine(pts[i], pts[i + 1], paint);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.red);
    }
  }

  void _drawDraftCircle(Canvas canvas, Size size) {
    if (circleCenter == null) return;
    final cx = circleCenter!.dx * size.width;
    final cy = circleCenter!.dy * size.height;
    final r = circleRadius * size.width;
    final fill = Paint()..color = const Color(0x33F44336);
    final border = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r, fill);
    canvas.drawCircle(Offset(cx, cy), r, border);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter old) => true;
}
