import 'package:flutter/material.dart';
import '../../models/setup_config.dart';
import '../../services/setup_service.dart';

class CenterLocationTab extends StatefulWidget {
  const CenterLocationTab({super.key});

  @override
  State<CenterLocationTab> createState() => _CenterLocationTabState();
}

class _CenterLocationTabState extends State<CenterLocationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _centerCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _panIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = SetupService.instance.config;
    _centerCtrl.text = c.centerName;
    _locationCtrl.text = c.locationName;
    _panIdCtrl.text = c.panId;
  }

  @override
  void dispose() {
    _centerCtrl.dispose();
    _locationCtrl.dispose();
    _panIdCtrl.dispose();
    super.dispose();
  }

  bool get _canRegister =>
      _centerCtrl.text.trim().isNotEmpty && _locationCtrl.text.trim().isNotEmpty;

  void _save() {
    final c = SetupService.instance.config;
    c.centerName = _centerCtrl.text.trim();
    c.locationName = _locationCtrl.text.trim();
    c.panId = _panIdCtrl.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.'), duration: Duration(seconds: 1)),
    );
  }

  void _register() {
    final centerName = _centerCtrl.text.trim();
    final locationName = _locationCtrl.text.trim();
    final panId = _panIdCtrl.text.trim();

    final c = SetupService.instance.config;
    c.centerName = centerName;
    c.locationName = locationName;
    c.panId = panId;

    SetupService.instance.addCenter(SetupConfig(
      centerName: centerName,
      locationName: locationName,
      panId: panId,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('센터 / 로케이션 등록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // ── 센터 ──────────────────────────────────────────────────────────
            const Text('센터', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _centerCtrl,
              decoration: const InputDecoration(
                labelText: '센터 이름',
                hintText: '예: 인천 물류 센터',
                helperText: '1 Platform = 1 Center',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── 로케이션 ───────────────────────────────────────────────────────
            const Text('로케이션', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: '로케이션 이름',
                hintText: '예: 1창고 2층',
                helperText: '1 Center = N Location',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _panIdCtrl,
              decoration: const InputDecoration(
                labelText: 'PAN ID',
                hintText: '0x1234',
                helperText: 'UWB 네트워크 식별자 (16진수)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('센터 등록 완료'),
              onPressed: _canRegister ? _register : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
