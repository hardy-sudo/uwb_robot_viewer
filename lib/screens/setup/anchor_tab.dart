import 'package:flutter/material.dart';
import '../../models/setup_config.dart';
import '../../services/setup_service.dart';

class AnchorTab extends StatefulWidget {
  const AnchorTab({super.key});

  @override
  State<AnchorTab> createState() => _AnchorTabState();
}

class _AnchorTabState extends State<AnchorTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _idCtrl = TextEditingController();
  String? _selectedId;

  List<AnchorData> get _anchors => SetupService.instance.config.anchors;

  void _addAnchor() {
    final id = _idCtrl.text.trim();
    if (id.isEmpty || _anchors.any((a) => a.id == id)) return;
    setState(() {
      _anchors.add(AnchorData(id: id));
      _idCtrl.clear();
    });
  }

  void _removeAnchor(String id) {
    setState(() {
      _anchors.removeWhere((a) => a.id == id);
      if (_selectedId == id) _selectedId = null;
    });
  }

  void _onMapTap(TapDownDetails details, Size canvasSize) {
    if (_selectedId == null) return;
    final idx = _anchors.indexWhere((a) => a.id == _selectedId);
    if (idx < 0) return;
    setState(() {
      _anchors[idx].mapXRatio =
          (details.localPosition.dx / canvasSize.width).clamp(0.02, 0.98);
      _anchors[idx].mapYRatio =
          (details.localPosition.dy / canvasSize.height).clamp(0.02, 0.98);
      _anchors[idx].placed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: Anchor 목록 ───────────────────────────────────────────────
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Anchor 목록',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Anchor ID',
                        hintText: 'ANC-001',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addAnchor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: _addAnchor, child: const Text('추가')),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: _anchors.isEmpty
                      ? const Center(
                          child: Text('Anchor를 추가하세요.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _anchors.length,
                          itemBuilder: (context, idx) {
                            final anchor = _anchors[idx];
                            final isSelected = _selectedId == anchor.id;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              color: isSelected ? Colors.blue.shade50 : null,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  anchor.placed
                                      ? Icons.router
                                      : Icons.router_outlined,
                                  color: anchor.placed
                                      ? Colors.deepOrange
                                      : Colors.grey,
                                  size: 20,
                                ),
                                title: Text(anchor.id,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  anchor.placed
                                      ? '${(anchor.mapXRatio * 100).toStringAsFixed(0)}%, ${(anchor.mapYRatio * 100).toStringAsFixed(0)}%'
                                      : '미배치',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: anchor.placed
                                          ? Colors.green.shade700
                                          : Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() =>
                                          _selectedId = isSelected
                                              ? null
                                              : anchor.id),
                                      child: Text(
                                        isSelected ? '취소' : '배치',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.grey
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeAnchor(anchor.id),
                                      child: const Icon(Icons.close, size: 16,
                                          color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── 오른쪽: 맵 캔버스 ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Text('맵',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (_selectedId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_selectedId — 탭하여 배치',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  else if (_anchors.any((a) => !a.placed))
                    const Text('배치할 Anchor를 선택하세요.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapDown: (d) => _onMapTap(d, size),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          painter: _AnchorMapPainter(
                            anchors: _anchors,
                            selectedId: _selectedId,
                          ),
                          size: size,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _AnchorMapPainter extends CustomPainter {
  final List<AnchorData> anchors;
  final String? selectedId;

  _AnchorMapPainter({required this.anchors, this.selectedId});

  @override
  void paint(Canvas canvas, Size size) {
    // 격자
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    for (int i = 1; i < 10; i++) {
      canvas.drawLine(
          Offset(size.width * i / 10, 0),
          Offset(size.width * i / 10, size.height),
          gridPaint);
      canvas.drawLine(
          Offset(0, size.height * i / 10),
          Offset(size.width, size.height * i / 10),
          gridPaint);
    }

    // Anchor 마커
    for (final a in anchors.where((x) => x.placed)) {
      final cx = a.mapXRatio * size.width;
      final cy = a.mapYRatio * size.height;
      final isSelected = a.id == selectedId;

      // 선택 링
      if (isSelected) {
        canvas.drawCircle(
          Offset(cx, cy),
          14,
          Paint()..color = Colors.blue.withAlpha(60),
        );
      }

      // 원
      canvas.drawCircle(
        Offset(cx, cy),
        8,
        Paint()..color = isSelected ? Colors.blue : Colors.deepOrange,
      );

      // 라벨
      final tp = TextPainter(
        text: TextSpan(
          text: a.id,
          style: const TextStyle(
              color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + 10, cy - 6));
    }
  }

  @override
  bool shouldRepaint(_AnchorMapPainter old) => true;
}
