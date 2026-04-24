import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/app_context.dart';
import '../models/setup_config.dart';
import '../services/setup_service.dart';
import 'login_screen.dart';
import 'robot_map_router.dart';
import 'setup/setup_screen.dart';
import 'movelens/movelens_home_screen.dart';

class ContextSelectScreen extends StatefulWidget {
  const ContextSelectScreen({super.key});
  @override
  State<ContextSelectScreen> createState() => _ContextSelectScreenState();
}

class _ContextSelectScreenState extends State<ContextSelectScreen> {
  final List<String> regions = const ['KR', 'US'];
  final List<String> sites = const ['Office', 'ICN'];
  final List<String> floors = const ['1F', '2F', '3F', '4F'];
  int _step = 0;
  String? _region, _site, _floor;
  bool get _canEnter => _region != null && _site != null && _floor != null;

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  void _enter() {
    final ctx = AppContext(region: _region!, site: _site!, floor: _floor!);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RobotMapRouterScreen(ctx: ctx)));
  }

  void _enterRegistered(SetupConfig center) {
    final ctx = AppContext(
      region: center.region.isNotEmpty ? center.region : '등록',
      site: center.centerName,
      floor: center.floor.isNotEmpty
          ? center.floor
          : (center.locationName.isNotEmpty ? center.locationName : '-'),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RobotMapRouterScreen(ctx: ctx)));
  }

  void _showCenterOptions(SetupConfig center) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.business, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.centerName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (center.locationName.isNotEmpty)
                      Text(center.locationName,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Divider(),
            if (center.fmsBaseUrl.isNotEmpty)
              _infoRow(Icons.link, 'FMS URL', center.fmsBaseUrl),
            if (center.panId.isNotEmpty)
              _infoRow(Icons.router, 'PAN ID', center.panId),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('설정 편집'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SetupService.instance.setActiveCenter(center);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SetupScreen(initialTab: 0)),
                    ).then((_) => setState(() {}));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('맵 바로 가기'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _enterRegistered(center);
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildRegisteredCenters(List<SetupConfig> centers) {
    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('등록된 센터',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final c in centers)
              ListTile(
                leading: const Icon(Icons.business),
                title: Text(c.centerName),
                subtitle: c.locationName.isNotEmpty ? Text(c.locationName) : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showCenterOptions(c),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hammerYellow,
      appBar: AppBar(
        backgroundColor: hammerYellow, foregroundColor: Colors.black, elevation: 0,
        title: const Text('Select Context'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Setup',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetupScreen()))
                .then((_) => setState(() {})),
          ),
          TextButton(onPressed: _logout, child: const Text('Logout')),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/hammer_industry.png', fit: BoxFit.contain)),
        Positioned.fill(child: Container(color: hammerYellow.withOpacity(0.88))),
        Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 등록된 센터 목록 ──────────────────────────────────────────
                Builder(builder: (_) {
                  final centers = SetupService.instance.centers;
                  if (centers.isEmpty) return const SizedBox.shrink();
                  return Column(children: [
                    _buildRegisteredCenters(centers),
                    const SizedBox(height: 16),
                  ]);
                }),

                // ── Region / Site / Floor Stepper ────────────────────────────
                Card(elevation: 10,
                  child: Padding(padding: const EdgeInsets.all(16),
                    child: Stepper(
                    currentStep: _step,
                    onStepTapped: (i) => setState(() => _step = i),
                    controlsBuilder: (context, details) => Row(children: [
                      ElevatedButton(
                        onPressed: _step == 2 ? (_canEnter ? _enter : null) : details.onStepContinue,
                        child: Text(_step == 2 ? 'Enter' : 'Next')),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _step == 0 ? null : details.onStepCancel, child: const Text('Back')),
                    ]),
                    onStepContinue: () => setState(() => _step = (_step + 1).clamp(0, 2)),
                    onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 2)),
                    steps: [
                      Step(title: const Text('Region'), subtitle: Text(_region ?? 'Select KR / US'),
                        isActive: _step >= 0,
                        content: Wrap(spacing: 8, runSpacing: 8,
                          children: regions.map((r) => ChoiceChip(label: Text(r), selected: _region == r,
                            onSelected: (_) => setState(() { _region = r; _site = null; _floor = null; }))).toList())),
                      Step(title: const Text('Site / Location'), subtitle: Text(_site ?? 'Select Office / ICN'),
                        isActive: _step >= 1,
                        content: Wrap(spacing: 8, runSpacing: 8,
                          children: sites.map((s) => ChoiceChip(label: Text(s), selected: _site == s,
                            onSelected: _region == null ? null : (_) => setState(() { _site = s; _floor = null; }))).toList())),
                      Step(title: const Text('Floor'), subtitle: Text(_floor ?? 'Select 1F~4F'),
                        isActive: _step >= 2,
                        content: Wrap(spacing: 8, runSpacing: 8,
                          children: floors.map((f) => ChoiceChip(label: Text(f), selected: _floor == f,
                            onSelected: (_region == null || _site == null) ? null : (_) => setState(() => _floor = f))).toList())),
                    ],
                  ),
                )),
              ],
            ),
          )),
        )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_business),
                label: const Text('신규 센터 등록'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SetupScreen(initialTab: 0)),
                ).then((_) => setState(() {})),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('MoveLens 공정 진단'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black45),
                  foregroundColor: Colors.black87,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MoveLensHomeScreen()),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
