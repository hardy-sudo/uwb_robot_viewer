import 'package:flutter/material.dart';
import '../../models/tag_group.dart';
import '../../models/tag_group_relation.dart';
import '../../services/tag_group_service.dart';
import '../../services/setup_service.dart';

class RelationTab extends StatefulWidget {
  const RelationTab({super.key});

  @override
  State<RelationTab> createState() => _RelationTabState();
}

class _RelationTabState extends State<RelationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<TagGroupRelation> get _relations => TagGroupService.instance.relations;
  List<TagGroup> get _groups => TagGroupService.instance.groups;

  List<TagGroup> get _humanGroups => _groups
      .where((g) =>
          g.type == TagGroupType.human || g.type == TagGroupType.forklift)
      .toList();
  List<TagGroup> get _robotGroups =>
      _groups.where((g) => g.type == TagGroupType.robot).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _relations.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _relations.length,
              itemBuilder: (_, i) => _buildRelationCard(_relations[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Relation 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Relation이 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              'Tag 탭에서 그룹을 먼저 만든 뒤\n+ 버튼으로 Relation을 추가하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _buildRelationCard(TagGroupRelation rel) {
    final groupA = TagGroupService.instance.getGroupById(rel.groupAId);
    final groupB = TagGroupService.instance.getGroupById(rel.groupBId);
    final nameA = groupA?.name ?? rel.groupAId;
    final nameB = groupB?.name ?? rel.groupBId;

    return Dismissible(
      key: ValueKey(rel.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade100,
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) {
        setState(() => TagGroupService.instance.removeRelation(rel.id));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: rel.isActive
                ? Colors.green.shade100
                : Colors.grey.shade200,
            child: Icon(
              Icons.link,
              color: rel.isActive ? Colors.green : Colors.grey,
            ),
          ),
          title: Text('$nameA  ↔  $nameB',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '정지: ${rel.thresholdStopM.toStringAsFixed(1)} m  |  재개: ${rel.thresholdResumeM.toStringAsFixed(1)} m',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: rel.isActive,
                onChanged: (v) {
                  setState(() => rel.isActive = v);
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _showEditDialog(rel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 다이얼로그 ──────────────────────────────────────────────────────────────

  void _showAddDialog() {
    if (_humanGroups.isEmpty || _robotGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tag 탭에서 사람/로봇 그룹을 먼저 만들어 주세요.')),
      );
      return;
    }
    _showRelationDialog(null);
  }

  void _showEditDialog(TagGroupRelation rel) => _showRelationDialog(rel);

  void _showRelationDialog(TagGroupRelation? existing) {
    String? groupAId =
        existing?.groupAId ?? (_humanGroups.isNotEmpty ? _humanGroups[0].id : null);
    String? groupBId =
        existing?.groupBId ?? (_robotGroups.isNotEmpty ? _robotGroups[0].id : null);
    double stopM = existing?.thresholdStopM ?? 3.0;
    bool isActive = existing?.isActive ?? true;
    List<String> safetyLog = [];
    bool safetyRunning = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Relation 추가' : 'Relation 편집'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GroupA
                  const Text('사람 / 지게차 그룹',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  InputDecorator(
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: DropdownButton<String>(
                      value: groupAId,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _humanGroups
                          .map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Row(children: [
                                Icon(_groupIcon(g.type), size: 16),
                                const SizedBox(width: 6),
                                Text(g.name),
                              ])))
                          .toList(),
                      onChanged: (v) => setS(() => groupAId = v),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // GroupB
                  const Text('로봇 그룹',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  InputDecorator(
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: DropdownButton<String>(
                      value: groupBId,
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _robotGroups
                          .map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Row(children: [
                                const Icon(Icons.precision_manufacturing,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text(g.name),
                              ])))
                          .toList(),
                      onChanged: (v) => setS(() => groupBId = v),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 정지 거리
                  Row(children: [
                    const Text('정지 거리',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const Spacer(),
                    Text('${stopM.toStringAsFixed(1)} m',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  Slider(
                    value: stopM,
                    min: 0.5,
                    max: 10.0,
                    divisions: 19,
                    onChanged: (v) =>
                        setS(() => stopM = (v * 2).round() / 2),
                  ),
                  Text(
                    '재개 거리: ${(stopM + 0.1).toStringAsFixed(1)} m (자동)',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  // 활성/비활성
                  Row(children: [
                    const Text('활성화',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const Spacer(),
                    Switch(
                        value: isActive,
                        onChanged: (v) => setS(() => isActive = v)),
                  ]),

                  const Divider(height: 24),

                  // Safety Test 버튼
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: safetyRunning
                            ? null
                            : () async {
                                final robots = SetupService
                                    .instance.config.robotMappings;
                                if (robots.isEmpty) {
                                  setS(() => safetyLog = [
                                        '로봇 매핑 없음 (로봇 매핑 탭 참조)'
                                      ]);
                                  return;
                                }
                                final robotId = robots.first.robotId;
                                setS(() {
                                  safetyRunning = true;
                                  safetyLog = [];
                                });
                                await for (final msg in SetupService.instance
                                    .safetyFunctionTest(robotId)) {
                                  setS(() => safetyLog.add(msg));
                                }
                                setS(() => safetyRunning = false);
                              },
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Safety Test', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ]),
                  if (safetyLog.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: safetyLog
                            .map((l) => Text(l,
                                style: TextStyle(
                                    color: l.contains('✓')
                                        ? Colors.greenAccent
                                        : l.contains('✗')
                                            ? Colors.redAccent
                                            : Colors.white70,
                                    fontSize: 11,
                                    fontFamily: 'monospace')))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: groupAId == null || groupBId == null
                  ? null
                  : () {
                      final resumeM =
                          double.parse((stopM + 0.1).toStringAsFixed(1));
                      if (existing == null) {
                        TagGroupService.instance.addRelation(TagGroupRelation(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          groupAId: groupAId!,
                          groupBId: groupBId!,
                          thresholdStopM: stopM,
                          thresholdResumeM: resumeM,
                          isActive: isActive,
                        ));
                      } else {
                        existing.groupAId = groupAId!;
                        existing.groupBId = groupBId!;
                        existing.thresholdStopM = stopM;
                        existing.thresholdResumeM = resumeM;
                        existing.isActive = isActive;
                        TagGroupService.instance.updateRelation(existing);
                      }
                      setState(() {});
                      Navigator.pop(ctx);
                    },
              child: Text(existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _groupIcon(TagGroupType t) => switch (t) {
        TagGroupType.human => Icons.person,
        TagGroupType.robot => Icons.precision_manufacturing,
        TagGroupType.forklift => Icons.forklift,
      };
}
