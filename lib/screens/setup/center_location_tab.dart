import 'package:flutter/material.dart';
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
  final _fmsUrlCtrl = TextEditingController();
  final _areaIdCtrl = TextEditingController();

  // Region / Floor (선택)
  String? _selectedRegion;
  final _floorCtrl = TextEditingController();

  static const _regions = ['KR', 'US', 'EU', 'CN', 'JP'];

  @override
  void initState() {
    super.initState();
    final c = SetupService.instance.config;
    _centerCtrl.text = c.centerName;
    _locationCtrl.text = c.locationName;
    _panIdCtrl.text = c.panId;
    _fmsUrlCtrl.text = c.fmsBaseUrl;
    _areaIdCtrl.text = c.areaId.toString();
    _selectedRegion = c.region.isNotEmpty ? c.region : null;
    _floorCtrl.text = c.floor;
  }

  @override
  void dispose() {
    _centerCtrl.dispose();
    _locationCtrl.dispose();
    _panIdCtrl.dispose();
    _fmsUrlCtrl.dispose();
    _areaIdCtrl.dispose();
    _floorCtrl.dispose();
    super.dispose();
  }

  bool get _canRegister => _centerCtrl.text.trim().isNotEmpty;

  void _applyToConfig() {
    final c = SetupService.instance.config;
    c.centerName = _centerCtrl.text.trim();
    c.locationName = _locationCtrl.text.trim();
    c.region = _selectedRegion ?? '';
    c.floor = _floorCtrl.text.trim();
    c.panId = _panIdCtrl.text.trim();
    c.fmsBaseUrl = _fmsUrlCtrl.text.trim();
    c.areaId = int.tryParse(_areaIdCtrl.text.trim()) ?? 1;
  }

  void _save() {
    _applyToConfig();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.'), duration: Duration(seconds: 1)),
    );
  }

  void _register() {
    _applyToConfig();
    SetupService.instance.addCenter(SetupService.instance.config);
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
                labelText: '센터 이름 *',
                hintText: '예: 인천 물류 센터',
                helperText: '1 Platform = 1 Center (필수)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── 지역 / 층 (선택) ──────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.location_on, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Text('지역 / 층',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('선택사항',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              // Region 드롭다운
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRegion,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('선택', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('선택 안함', style: TextStyle(color: Colors.grey)),
                        ),
                        ..._regions.map((r) =>
                            DropdownMenuItem(value: r, child: Text(r))),
                      ],
                      onChanged: (v) => setState(() => _selectedRegion = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Floor 텍스트
              Expanded(
                child: TextField(
                  controller: _floorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
                    hintText: '예: 1F',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ]),

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
                helperText: '1 Center = N Location (선택사항)',
                border: OutlineInputBorder(),
              ),
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

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── FMS 서버 설정 ─────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.cloud, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Text('FMS 서버 설정',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            Text(
              '현장별 Dahua RCS 서버 주소를 입력하세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fmsUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'FMS Base URL',
                hintText: 'http://192.168.0.100:8080',
                helperText: 'Dahua RCS 서버의 IP와 포트 (http://IP:PORT)',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _areaIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Area ID',
                hintText: '1',
                helperText: 'Dahua RCS 구역 ID (숫자)',
                prefixIcon: Icon(Icons.grid_view),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
