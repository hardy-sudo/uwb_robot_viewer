import 'package:flutter/material.dart';
import '../../models/setup_config.dart';
import '../../models/tag_group.dart';
import '../../services/setup_service.dart';
import '../../services/tag_group_service.dart';

class TagTab extends StatefulWidget {
  const TagTab({super.key});

  @override
  State<TagTab> createState() => _TagTabState();
}

class _TagTabState extends State<TagTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<TagData> get _tags => SetupService.instance.config.tags;
  List<TagGroup> get _groups => TagGroupService.instance.groups;
  List<TagData> _discovered = [];
  bool _scanning = false;

  // ── 브로드캐스트 스캔 (모의) ─────────────────────────────────────────────────

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

  // ── 그룹 편집 다이얼로그 ──────────────────────────────────────────────────────

  void _showGroupDialog(TagGroup? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final fmsIpCtrl = TextEditingController(text: existing?.fmsIp ?? '');
    final brandCtrl = TextEditingController(text: existing?.robotBrand ?? '');
    final baseUrlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
    final apiUrlCtrl =
        TextEditingController(text: existing?.robotListApiUrl ?? '');
    TagGroupType type = existing?.type ?? TagGroupType.human;
    Set<String> selectedTagIds = Set.from(existing?.tagIds ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? '그룹 추가' : '그룹 편집'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 그룹명
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '그룹명',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // 타입 선택
                  const Text('그룹 타입',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  SegmentedButton<TagGroupType>(
                    segments: const [
                      ButtonSegment(
                          value: TagGroupType.human,
                          label: Text('작업자'),
                          icon: Icon(Icons.person, size: 16)),
                      ButtonSegment(
                          value: TagGroupType.forklift,
                          label: Text('지게차'),
                          icon: Icon(Icons.forklift, size: 16)),
                      ButtonSegment(
                          value: TagGroupType.robot,
                          label: Text('로봇'),
                          icon: Icon(Icons.precision_manufacturing, size: 16)),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setS(() => type = s.first),
                  ),

                  // 로봇 타입 전용 필드
                  if (type == TagGroupType.robot) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 4),
                    const Text('로봇 시스템 정보',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildTextField(fmsIpCtrl, 'FMS IP'),
                    const SizedBox(height: 8),
                    _buildTextField(brandCtrl, '로봇 Brand (예: Dahua)'),
                    const SizedBox(height: 8),
                    _buildTextField(baseUrlCtrl, 'Base URL'),
                    const SizedBox(height: 8),
                    _buildTextField(apiUrlCtrl, 'Robot List API URL'),
                  ],

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),

                  // 소속 Tag 선택
                  const Text('소속 Tag',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  if (_tags.isEmpty)
                    const Text('등록된 Tag가 없습니다.',
                        style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags.map((tag) {
                        final selected = selectedTagIds.contains(tag.id);
                        return FilterChip(
                          label: Text(tag.id,
                              style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (v) => setS(() => v
                              ? selectedTagIds.add(tag.id)
                              : selectedTagIds.remove(tag.id)),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: nameCtrl.text.isEmpty
                  ? null
                  : () {
                      final group = TagGroup(
                        id: existing?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        type: type,
                        tagIds: selectedTagIds.toList(),
                        fmsIp:
                            fmsIpCtrl.text.trim().isEmpty ? null : fmsIpCtrl.text.trim(),
                        robotBrand: brandCtrl.text.trim().isEmpty
                            ? null
                            : brandCtrl.text.trim(),
                        baseUrl: baseUrlCtrl.text.trim().isEmpty
                            ? null
                            : baseUrlCtrl.text.trim(),
                        robotListApiUrl: apiUrlCtrl.text.trim().isEmpty
                            ? null
                            : apiUrlCtrl.text.trim(),
                      );
                      if (existing == null) {
                        TagGroupService.instance.addGroup(group);
                      } else {
                        TagGroupService.instance.updateGroup(group);
                      }
                      setState(() {});
                      Navigator.pop(ctx);
                    },
              child: Text(existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    ).then((_) {
      nameCtrl.dispose();
      fmsIpCtrl.dispose();
      brandCtrl.dispose();
      baseUrlCtrl.dispose();
      apiUrlCtrl.dispose();
    });
  }

  Widget _buildTextField(TextEditingController ctrl, String label) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );

  // ── 빌드 ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 브로드캐스트 검색 ─────────────────────────────────────────
          Expanded(child: _buildDiscoveryPanel()),

          const SizedBox(width: 8),
          const VerticalDivider(),
          const SizedBox(width: 8),

          // ── 가운데: 등록된 Tag ───────────────────────────────────────────────
          Expanded(child: _buildRegisteredPanel()),

          const SizedBox(width: 8),
          const VerticalDivider(),
          const SizedBox(width: 8),

          // ── 오른쪽: Tag Group 관리 ──────────────────────────────────────────
          Expanded(child: _buildGroupPanel()),
        ],
      ),
    );
  }

  Widget _buildDiscoveryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('브로드캐스트 검색',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                TextButton(onPressed: _registerAll, child: const Text('전체 등록')),
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
                    leading: const Icon(Icons.nfc, size: 20, color: Colors.grey),
                    title: Text(tag.id,
                        style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: const Text('미등록 장치',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
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
    );
  }

  Widget _buildRegisteredPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('등록된 Tag (${_tags.length}개)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Tag 분류 지정: 작업자 / 로봇 / 미지정',
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
                          _categoryIcon(tag.group),
                          color: _categoryColor(tag.group),
                          size: 20,
                        ),
                        title: Text(tag.id,
                            style:
                                const TextStyle(fontFamily: 'monospace')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<TagCategory>(
                              value: tag.group,
                              isDense: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                    value: TagCategory.unassigned,
                                    child: Text('미지정',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: TagCategory.human,
                                    child: Text('작업자',
                                        style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(
                                    value: TagCategory.robot,
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
    );
  }

  Widget _buildGroupPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('Tag Group 관리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            tooltip: '그룹 추가',
            onPressed: () => _showGroupDialog(null),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Relation 탭에서 그룹 간 Safety 조건을 설정합니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _groups.isEmpty
              ? const Center(
                  child: Text(
                    '그룹이 없습니다.\n+ 버튼으로 그룹을 추가하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (_, i) {
                    final g = _groups[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _typeColor(g.type).withAlpha(30),
                          child: Icon(_typeIcon(g.type),
                              size: 18, color: _typeColor(g.type)),
                        ),
                        title: Text(g.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${g.tagIds.length}개 Tag',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _showGroupDialog(g),
                            ),
                            GestureDetector(
                              onTap: () => setState(() =>
                                  TagGroupService.instance.removeGroup(g.id)),
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
    );
  }

  // ── 헬퍼 ─────────────────────────────────────────────────────────────────────

  IconData _categoryIcon(TagCategory g) => switch (g) {
        TagCategory.human => Icons.person,
        TagCategory.robot => Icons.precision_manufacturing,
        TagCategory.unassigned => Icons.device_unknown,
      };

  Color _categoryColor(TagCategory g) => switch (g) {
        TagCategory.human => Colors.teal,
        TagCategory.robot => Colors.blue,
        TagCategory.unassigned => Colors.grey,
      };

  IconData _typeIcon(TagGroupType t) => switch (t) {
        TagGroupType.human => Icons.people,
        TagGroupType.robot => Icons.precision_manufacturing,
        TagGroupType.forklift => Icons.forklift,
      };

  Color _typeColor(TagGroupType t) => switch (t) {
        TagGroupType.human => Colors.teal,
        TagGroupType.robot => Colors.blue,
        TagGroupType.forklift => Colors.orange,
      };
}
