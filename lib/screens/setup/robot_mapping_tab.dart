import 'package:flutter/material.dart';
import '../../models/setup_config.dart';
import '../../services/setup_service.dart';

class RobotMappingTab extends StatefulWidget {
  const RobotMappingTab({super.key});

  @override
  State<RobotMappingTab> createState() => _RobotMappingTabState();
}

class _RobotMappingTabState extends State<RobotMappingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _fmsCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  SetupConfig get _cfg => SetupService.instance.config;
  List<RobotMappingEntry> get _mappings => _cfg.robotMappings;
  List<TagData> get _robotTags =>
      _cfg.tags.where((t) => t.group == TagGroup.robot).toList();

  @override
  void initState() {
    super.initState();
    _fmsCtrl.text = _cfg.fmsBaseUrl;
    _areaCtrl.text = _cfg.areaId.toString();
  }

  @override
  void dispose() {
    _fmsCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  void _applyConfig() {
    _cfg.fmsBaseUrl = _fmsCtrl.text.trim();
    _cfg.areaId = int.tryParse(_areaCtrl.text.trim()) ?? 1;
  }

  Future<void> _loadRobots() async {
    _applyConfig();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await SetupService.instance.loadRobotIds();
      setState(() {
        _loading = false;
        final existingIds = _mappings.map((m) => m.robotId).toSet();
        for (final id in ids) {
          if (!existingIds.contains(id)) {
            _mappings.add(RobotMappingEntry(robotId: id));
          }
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('로봇 매핑',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ── FMS 연결 설정 ──────────────────────────────────────────────────
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _fmsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'FMS Base URL',
                    hintText: 'http://192.168.1.100:7000',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _areaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Area ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadRobots,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 18),
                label: const Text('로봇 목록 불러오기'),
              ),
            ]),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 20),

            // ── 로봇 매핑 테이블 ───────────────────────────────────────────────
            if (_mappings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'FMS URL을 입력하고 로봇 목록을 불러오세요.\nTag 탭에서 로봇 Tag를 먼저 등록해야 매핑이 가능합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              Row(children: [
                Text('로봇 목록 (${_mappings.length}개)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_robotTags.isEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tag 탭에서 로봇 Tag를 먼저 등록하세요',
                      style: TextStyle(fontSize: 11, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                  2: FixedColumnWidth(48),
                },
                border: TableBorder.all(color: Colors.grey.shade200),
                children: [
                  // 헤더
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TH('로봇 ID'),
                      _TH('매핑 Tag ID'),
                      _TH(''),
                    ],
                  ),
                  // 로봇 행
                  for (final m in _mappings)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(m.robotId,
                            style: const TextStyle(fontFamily: 'monospace')),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: DropdownButton<String>(
                          value: m.tagId.isEmpty ? null : m.tagId,
                          hint: const Text('Tag 선택',
                              style: TextStyle(fontSize: 13)),
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _robotTags
                              .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.id,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => m.tagId = v);
                          },
                        ),
                      ),
                      Center(
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () =>
                              setState(() => _mappings.remove(m)),
                          tooltip: '제거',
                        ),
                      ),
                    ]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
