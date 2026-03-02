import 'package:flutter/material.dart';
import '../../models/setup_config.dart';
import '../../services/setup_service.dart';

class TagTab extends StatefulWidget {
  const TagTab({super.key});

  @override
  State<TagTab> createState() => _TagTabState();
}

class _TagTabState extends State<TagTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<TagData> get _tags => SetupService.instance.config.tags;
  List<TagData> _discovered = [];
  bool _scanning = false;

  // 모의 브로드캐스트 스캔: 2초 후 TAG 목록 방출
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _discovered = [];
    });
    await Future.delayed(const Duration(seconds: 2));

    final registeredIds = _tags.map((t) => t.id).toSet();
    const mockIds = [
      'TAG_W1', 'TAG_W2', 'TAG_W3',
      'TAG_R1', 'TAG_R2', 'TAG_R3',
    ];
    setState(() {
      _scanning = false;
      _discovered = mockIds
          .where((id) => !registeredIds.contains(id))
          .map((id) => TagData(id: id))
          .toList();
    });
  }

  void _registerAll() {
    setState(() {
      _tags.addAll(_discovered);
      _discovered = [];
    });
  }

  void _registerOne(TagData tag) {
    setState(() {
      _tags.add(tag);
      _discovered.remove(tag);
    });
  }

  void _removeTag(TagData tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 브로드캐스트 검색 ─────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Text('브로드캐스트 검색',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search, size: 18),
                    label: Text(_scanning ? '검색 중...' : '주변 Tag 찾기'),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_discovered.isEmpty && !_scanning)
                  const Expanded(
                    child: Center(
                      child: Text(
                        '주변 Tag 찾기 버튼으로 스캔하세요.\nUWB 태그 전원이 켜져 있어야 합니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  if (_discovered.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Text('${_discovered.length}개 발견',
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                        TextButton(
                            onPressed: _registerAll,
                            child: const Text('전체 등록')),
                      ]),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _discovered.length,
                      itemBuilder: (_, i) {
                        final tag = _discovered[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.nfc,
                                size: 20, color: Colors.grey),
                            title: Text(tag.id,
                                style: const TextStyle(fontFamily: 'monospace')),
                            subtitle: const Text('미등록 장치',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey)),
                            trailing: ElevatedButton(
                              onPressed: () => _registerOne(tag),
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6)),
                              child: const Text('등록', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),
          const VerticalDivider(),
          const SizedBox(width: 8),

          // ── 오른쪽: 등록된 Tag ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('등록된 Tag (${_tags.length}개)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Tag 그룹을 지정하세요: 작업자 Tag / 로봇 Tag',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _tags.isEmpty
                      ? const Center(
                          child: Text('등록된 Tag가 없습니다.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _tags.length,
                          itemBuilder: (_, i) {
                            final tag = _tags[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  _groupIcon(tag.group),
                                  color: _groupColor(tag.group),
                                  size: 20,
                                ),
                                title: Text(tag.id,
                                    style: const TextStyle(
                                        fontFamily: 'monospace')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButton<TagGroup>(
                                      value: tag.group,
                                      isDense: true,
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(
                                            value: TagGroup.unassigned,
                                            child: Text('미지정',
                                                style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: TagGroup.human,
                                            child: Text('작업자',
                                                style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(
                                            value: TagGroup.robot,
                                            child: Text('로봇',
                                                style: TextStyle(fontSize: 13))),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => tag.group = v);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeTag(tag),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.grey),
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
        ],
      ),
    );
  }

  IconData _groupIcon(TagGroup g) => switch (g) {
        TagGroup.human => Icons.person,
        TagGroup.robot => Icons.precision_manufacturing,
        TagGroup.unassigned => Icons.device_unknown,
      };

  Color _groupColor(TagGroup g) => switch (g) {
        TagGroup.human => Colors.teal,
        TagGroup.robot => Colors.blue,
        TagGroup.unassigned => Colors.grey,
      };
}
