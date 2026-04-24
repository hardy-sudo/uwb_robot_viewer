import 'package:flutter/material.dart';

import '../../../models/movelens_center.dart';
import '../../../services/movelens_service.dart';

class MoveLensCenterTab extends StatefulWidget {
  final MoveLensCenter? center;
  final void Function(MoveLensCenter) onSaved;

  const MoveLensCenterTab({
    super.key,
    this.center,
    required this.onSaved,
  });

  @override
  State<MoveLensCenterTab> createState() => _MoveLensCenterTabState();
}

class _MoveLensCenterTabState extends State<MoveLensCenterTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _nameCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final c = widget.center;
    if (c != null) {
      _nameCtrl.text = c.name;
      _clientCtrl.text = c.clientName;
      _descCtrl.text = c.description;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clientCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final svc = MoveLensService.instance;

    if (widget.center == null) {
      final created = svc.addCenter(
        name: _nameCtrl.text.trim(),
        clientName: _clientCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      widget.onSaved(created);
    } else {
      final c = widget.center!;
      c.name = _nameCtrl.text.trim();
      c.clientName = _clientCtrl.text.trim();
      c.description = _descCtrl.text.trim();
      svc.updateCenter(c);
      widget.onSaved(c);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('센터 정보가 저장되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('기본 정보'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '센터명 *',
                hintText: '예: 인천 물류센터 A동',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.factory_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '센터명을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: '고객사명',
                hintText: '예: ㈜모브렉스 물류',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '설명 / 비고',
                hintText: '현장 특이사항, 측정 목적 등',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
}
