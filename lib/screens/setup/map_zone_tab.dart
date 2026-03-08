import 'package:flutter/material.dart';
import '../../models/map_config.dart';
import '../../models/safety_zone.dart';
import '../../services/map_zone_service.dart';
import '../../widgets/zone_painter.dart';

class MapZoneTab extends StatefulWidget {
  const MapZoneTab({super.key});

  @override
  State<MapZoneTab> createState() => _MapZoneTabState();
}

class _MapZoneTabState extends State<MapZoneTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  MapZoneService get _svc => MapZoneService.instance;

  final _urlCtrl = TextEditingController();
  bool _drawingMode = false;
  List<Offset> _draftPolygon = [];

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _svc.mapConfig?.imageUrl ?? '';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _applyImageUrl() {
    final url = _urlCtrl.text.trim();
    setState(() {
      _svc.mapConfig = MapConfig(
        id: 'map_1',
        locationId: 'loc_1',
        imageUrl: url,
      );
    });
  }

  void _onCanvasTap(TapDownDetails details, Size canvasSize) {
    if (!_drawingMode) return;
    final norm = Offset(
      details.localPosition.dx / canvasSize.width,
      details.localPosition.dy / canvasSize.height,
    );
    setState(() => _draftPolygon.add(norm));
  }

  void _finishDrawing() {
    if (_draftPolygon.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('꼭짓점을 3개 이상 추가해 주세요.')),
      );
      return;
    }
    _showZoneNameDialog(List.from(_draftPolygon));
  }

  void _cancelDrawing() {
    setState(() {
      _drawingMode = false;
      _draftPolygon = [];
    });
  }

  void _showZoneNameDialog(List<Offset> polygon) {
    showDialog(
      context: context,
      builder: (ctx) => _ZoneNameDialog(
        onSave: (name, safetyOn) {
          final zone = SafetyZone(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            polygon: polygon,
            safetyEnabled: safetyOn,
            zoneColor: safetyOn ? Colors.green : Colors.red,
          );
          setState(() {
            _svc.addZone(zone);
            _drawingMode = false;
            _draftPolygon = [];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 맵 캔버스 ─────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageUrlBar(),
                const SizedBox(height: 8),
                _buildDrawingToolbar(),
                const SizedBox(height: 8),
                Expanded(child: _buildMapCanvas()),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── 오른쪽: Zone 목록 ────────────────────────────────────────────────
          SizedBox(
            width: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Text('Zone 목록',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_svc.zones.length}개',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                Expanded(child: _buildZoneList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUrlBar() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: '맵 이미지 URL',
            hintText: 'https://example.com/map.png',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _applyImageUrl(),
        ),
      ),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: _applyImageUrl, child: const Text('적용')),
    ]);
  }

  Widget _buildDrawingToolbar() {
    if (_drawingMode) {
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '드로잉 모드 — 맵을 탭하여 꼭짓점 추가 (${_draftPolygon.length}개)',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: _cancelDrawing, child: const Text('취소')),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: _draftPolygon.length >= 3 ? _finishDrawing : null,
          child: const Text('완료'),
        ),
      ]);
    }
    return Row(children: [
      ElevatedButton.icon(
        icon: const Icon(Icons.draw, size: 16),
        label: const Text('+ Zone 추가'),
        onPressed: () => setState(() {
          _drawingMode = true;
          _draftPolygon = [];
        }),
      ),
    ]);
  }

  Widget _buildMapCanvas() {
    final imageUrl = _svc.mapConfig?.imageUrl ?? '';
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onTapDown: (d) => _onCanvasTap(d, size),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(
              color: _drawingMode ? Colors.blue : Colors.grey.shade300,
              width: _drawingMode ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              // 맵 이미지 or 격자
              if (imageUrl.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildGridPlaceholder(size),
                  ),
                )
              else
                _buildGridPlaceholder(size),

              // Zone 오버레이
              Positioned.fill(
                child: CustomPaint(
                  painter: ZonePainter(
                    zones: _svc.zones,
                    draftPolygon: _draftPolygon,
                  ),
                ),
              ),

              // 드로잉 힌트
              if (_drawingMode && _draftPolygon.isEmpty)
                const Center(
                  child: Text(
                    '탭하여 꼭짓점 추가',
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _buildGridPlaceholder(Size size) {
    return CustomPaint(painter: _GridPainter());
  }

  Widget _buildZoneList() {
    if (_svc.zones.isEmpty) {
      return const Center(
        child: Text(
          'Zone이 없습니다.\n+ Zone 추가 버튼으로 구역을 그려주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      itemCount: _svc.zones.length,
      itemBuilder: (_, i) {
        final zone = _svc.zones[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor:
                  zone.safetyEnabled ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                zone.safetyEnabled ? Icons.shield : Icons.shield_outlined,
                size: 14,
                color: zone.safetyEnabled ? Colors.green : Colors.red,
              ),
            ),
            title: Text(zone.name, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '${zone.polygon.length}개 꼭짓점',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: zone.safetyEnabled,
                  onChanged: (v) {
                    setState(() {
                      zone.safetyEnabled = v;
                      zone.zoneColor = v ? Colors.green : Colors.red;
                    });
                  },
                ),
                GestureDetector(
                  onTap: () => setState(() => _svc.removeZone(zone.id)),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Zone 이름 입력 다이얼로그 (StatefulWidget으로 분리해 controller 생명주기 관리) ──

class _ZoneNameDialog extends StatefulWidget {
  final void Function(String name, bool safetyOn) onSave;

  const _ZoneNameDialog({required this.onSave});

  @override
  State<_ZoneNameDialog> createState() => _ZoneNameDialogState();
}

class _ZoneNameDialogState extends State<_ZoneNameDialog> {
  final _nameCtrl = TextEditingController();
  bool _safetyOn = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zone 정보 입력'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Zone 이름',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Safety 활성화'),
                const Spacer(),
                Switch(
                  value: _safetyOn,
                  onChanged: (v) => setState(() => _safetyOn = v),
                ),
              ]),
              Text(
                _safetyOn
                    ? '이 구역에서 Safety 감지 활성'
                    : '이 구역에서 Safety 감지 비활성',
                style: TextStyle(
                    fontSize: 12,
                    color: _safetyOn ? Colors.green : Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty
              ? null
              : () {
                  widget.onSave(_nameCtrl.text.trim(), _safetyOn);
                  Navigator.pop(context);
                },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// ── 격자 배경 Painter ─────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    for (int i = 1; i < 10; i++) {
      canvas.drawLine(Offset(size.width * i / 10, 0),
          Offset(size.width * i / 10, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 10),
          Offset(size.width, size.height * i / 10), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
