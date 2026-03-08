import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/app_context.dart';
import 'login_screen.dart';
import 'robot_map_router.dart';
import 'setup/setup_screen.dart';

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
                MaterialPageRoute(builder: (_) => const SetupScreen())),
          ),
          TextButton(onPressed: _logout, child: const Text('Logout')),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/hammer_industry.png', fit: BoxFit.contain)),
        Positioned.fill(child: Container(color: hammerYellow.withOpacity(0.88))),
        Column(children: [
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(padding: const EdgeInsets.all(16), child: Card(elevation: 10,
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
            ),
          )),
        ))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_business),
                label: const Text('신규 센터 등록'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SetupScreen(initialTab: 0)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
