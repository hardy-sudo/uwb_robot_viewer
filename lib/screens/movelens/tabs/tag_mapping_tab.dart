import 'package:flutter/material.dart';

import '../../../models/movelens_center.dart';
import '../../../models/movelens_tag_mapping.dart';
import '../../../services/movelens_service.dart';

class MoveLensTagMappingTab extends StatefulWidget {
  final MoveLensCenter center;

  const MoveLensTagMappingTab({super.key, required this.center});

  @override
  State<MoveLensTagMappingTab> createState() => _MoveLensTagMappingTabState();
}

class _MoveLensTagMappingTabState extends State<MoveLensTagMappingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = MoveLensService.instance;

  void _addMapping() {
    _showMappingDialog(null);
  }

  void _editMapping(MoveLensTagMapping mapping) {
    _showMappingDialog(mapping);
  }

  void _showMappingDialog(MoveLensTagMapping? existing) {
    final tagCtrl = TextEditingController(text: existing?.tagId ?? '');
    final anonCtrl =
        TextEditingController(text: existing?.anonymousId ?? '');
    TagObjectType type = existing?.type ?? TagObjectType.worker;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? '태그 매핑 추가' : '태그 매핑 편집'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagCtrl,
                  decoration: const InputDecoration(
                    labelText: '태그 ID *',
                    hintText: '예: TAG_W1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: anonCtrl,
                  decoration: const InputDecoration(
                    labelText: '익명 식별자 *',
                    hintText: '예: 작업자 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TagObjectType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '유형',
                    border: OutlineInputBorder(),
                  ),
                  items: TagObjectType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => type = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tagCtrl.text.trim().isEmpty ||
                    anonCtrl.text.trim().isEmpty) {
                  return;
                }
                final mapping = MoveLensTagMapping(
                  tagId: tagCtrl.text.trim(),
                  anonymousId: anonCtrl.text.trim(),
                  type: type,
                );
                _svc.addTagMapping(widget.center, mapping);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mappings = widget.center.tagMappings;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '태그 매핑',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '작업자 실명 대신 익명 ID를 사용합니다',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addMapping,
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              ),
            ],
          ),
        ),
        Expanded(
          child: mappings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('등록된 태그 매핑이 없습니다',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: mappings.length,
                  itemBuilder: (_, i) {
                    final m = mappings[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: _typeIcon(m.type),
                        title: Text(m.anonymousId),
                        subtitle: Text('태그: ${m.tagId}  |  ${m.type.label}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18),
                              onPressed: () => _editMapping(m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              onPressed: () {
                                _svc.deleteTagMapping(
                                    widget.center, m.tagId);
                                setState(() {});
                              },
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

  Widget _typeIcon(TagObjectType type) {
    switch (type) {
      case TagObjectType.worker:
        return const CircleAvatar(
          backgroundColor: Color(0xFF1976D2),
          child: Icon(Icons.person, color: Colors.white, size: 20),
        );
      case TagObjectType.cart:
        return const CircleAvatar(
          backgroundColor: Color(0xFF388E3C),
          child: Icon(Icons.shopping_cart, color: Colors.white, size: 20),
        );
      case TagObjectType.forklift:
        return const CircleAvatar(
          backgroundColor: Color(0xFFE64A19),
          child: Icon(Icons.forklift, color: Colors.white, size: 20),
        );
      case TagObjectType.towingCar:
        return const CircleAvatar(
          backgroundColor: Color(0xFF7B1FA2),
          child: Icon(Icons.airport_shuttle, color: Colors.white, size: 20),
        );
    }
  }
}
