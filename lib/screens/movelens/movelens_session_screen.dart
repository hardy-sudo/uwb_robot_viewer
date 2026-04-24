import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/movelens_center.dart';
import '../../models/movelens_session.dart';
import '../../models/movelens_zone.dart';
import '../../services/movelens_service.dart';
import 'movelens_dashboard_screen.dart';

class MoveLensSessionScreen extends StatefulWidget {
  final MoveLensCenter center;

  const MoveLensSessionScreen({super.key, required this.center});

  @override
  State<MoveLensSessionScreen> createState() => _MoveLensSessionScreenState();
}

class _MoveLensSessionScreenState extends State<MoveLensSessionScreen> {
  final _svc = MoveLensService.instance;
  MoveLensSession? _session;
  StreamSubscription<List<TagPosition>>? _sub;
  List<TagPosition> _positions = [];
  Timer? _clockTimer;
  Duration _elapsed = Duration.zero;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  void _startSession() {
    _session = _svc.startSession(widget.center);
    _sub = _svc.positionStream.listen((positions) {
      if (mounted) setState(() => _positions = positions);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _session != null) {
        setState(() => _elapsed = _session!.elapsed);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _stopSession() async {
    if (_stopping) return;
    setState(() => _stopping = true);

    _sub?.cancel();
    _clockTimer?.cancel();

    _svc.stopSession(widget.center);

    if (!mounted) return;
    final session = widget.center.lastCompletedSession;
    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MoveLensDashboardScreen(
            center: widget.center,
            session: session,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('측정 중'),
            const SizedBox(width: 8),
            Text(
              _fmtDuration(_elapsed),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: hammerYellow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _stopping ? null : _stopSession,
            icon: Icon(Icons.stop_circle,
                color: _stopping ? Colors.grey : Colors.red),
            label: Text(
              '측정 종료',
              style: TextStyle(
                  color: _stopping ? Colors.grey : Colors.red),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 통계 바
          Container(
            color: Colors.black,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('수집 이벤트',
                    '${_session?.rawEvents.length ?? 0}건'),
                _stat('감지 태그', '${_positions.length}개'),
                _stat('센터', widget.center.name),
              ],
            ),
          ),
          // 맵 캔버스
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(builder: (_, box) {
                    return CustomPaint(
                      painter: _SessionMapPainter(
                        zones: widget.center.zones,
                        positions: _positions,
                        tagMappings: widget.center.tagMappings
                            .asMap()
                            .map((_, m) => MapEntry(m.tagId, m.anonymousId)),
                      ),
                      size: Size(box.maxWidth, box.maxHeight),
                    );
                  }),
                ),
              ),
            ),
          ),
          // 태그 목록
          if (_positions.isNotEmpty)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _positions.map((p) {
                  final name = widget.center.tagMappings
                          .firstWhere((m) => m.tagId == p.tagId,
                              orElse: () => widget.center.tagMappings.first)
                          .anonymousId;
                  final zoneName = p.currentZoneId != null
                      ? widget.center.zones
                          .firstWhere((z) => z.id == p.currentZoneId,
                              orElse: () => widget.center.zones.first)
                          .name
                      : '이동 중';
                  return Chip(
                    backgroundColor: Colors.grey[850],
                    label: Text(
                      '$name  [$zoneName]',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                    avatar: const Icon(Icons.person_pin,
                        color: hammerYellow, size: 18),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      );
}

// ────────────────────────────────────────────────────

class _SessionMapPainter extends CustomPainter {
  final List<MoveLensZone> zones;
  final List<TagPosition> positions;
  final Map<String, String> tagMappings;

  _SessionMapPainter({
    required this.zones,
    required this.positions,
    required this.tagMappings,
  });

  static const _colors = [
    Color(0x4D2196F3),
    Color(0x4D4CAF50),
    Color(0x4DFF9800),
    Color(0x4D9C27B0),
    Color(0x4DF44336),
    Color(0x4D009688),
  ];
  static const _borders = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF009688),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    for (int i = 0; i < zones.length; i++) {
      _drawZone(canvas, size, zones[i], i);
    }
    for (int i = 0; i < positions.length; i++) {
      _drawTag(canvas, size, positions[i], i);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(
          Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), p);
      canvas.drawLine(
          Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), p);
    }
  }

  void _drawZone(Canvas canvas, Size size, MoveLensZone zone, int idx) {
    final fill = Paint()..color = _colors[idx % _colors.length];
    final border = Paint()
      ..color = _borders[idx % _borders.length]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (zone.shape == ZoneShape.circle) {
      final c = Offset(zone.center.dx * size.width, zone.center.dy * size.height);
      final r = zone.radius * size.width;
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, border);
      _drawLabel(canvas, size, zone.name, zone.center.dx, zone.center.dy,
          _borders[idx % _borders.length]);
    } else if (zone.polygon.length >= 3) {
      final path = Path()
        ..moveTo(zone.polygon[0].dx * size.width, zone.polygon[0].dy * size.height);
      for (int i = 1; i < zone.polygon.length; i++) {
        path.lineTo(zone.polygon[i].dx * size.width, zone.polygon[i].dy * size.height);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, border);
      double sx = zone.polygon.map((p) => p.dx).reduce((a, b) => a + b) / zone.polygon.length;
      double sy = zone.polygon.map((p) => p.dy).reduce((a, b) => a + b) / zone.polygon.length;
      _drawLabel(canvas, size, zone.name, sx, sy, _borders[idx % _borders.length]);
    }
  }

  void _drawLabel(Canvas canvas, Size size, String label, double nx, double ny,
      Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(nx * size.width - tp.width / 2, ny * size.height - tp.height / 2));
  }

  void _drawTag(Canvas canvas, Size size, TagPosition pos, int idx) {
    final tagColors = [
      hammerYellow,
      Colors.lightBlueAccent,
      Colors.lightGreenAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
    ];
    final color = tagColors[idx % tagColors.length];
    final cx = pos.x * size.width;
    final cy = pos.y * size.height;

    // 원 + 테두리
    canvas.drawCircle(
        Offset(cx, cy), 12, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = color);
    canvas.drawCircle(
        Offset(cx, cy),
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // 이름
    final name = tagMappings[pos.tagId] ?? pos.tagId;
    final tp = TextPainter(
      text: TextSpan(
          text: name,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 10));
  }

  @override
  bool shouldRepaint(covariant _SessionMapPainter old) => true;
}
