import 'package:flutter/material.dart';
import '../../services/setup_service.dart';

class SafetySettingsTab extends StatefulWidget {
  const SafetySettingsTab({super.key});

  @override
  State<SafetySettingsTab> createState() => _SafetySettingsTabState();
}

class _SafetySettingsTabState extends State<SafetySettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late double _stopM;
  late int _cooldownMs;

  @override
  void initState() {
    super.initState();
    final c = SetupService.instance.config;
    _stopM = c.thresholdStopM;
    _cooldownMs = c.cooldownMs;
  }

  double get _resumeM => double.parse((_stopM + 0.1).toStringAsFixed(1));

  void _apply() {
    final c = SetupService.instance.config;
    setState(() {
      c.thresholdStopM = _stopM;
      c.thresholdResumeM = _resumeM;
      c.cooldownMs = _cooldownMs;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safety 설정이 적용되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Safety Distance 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '로봇과 작업자 간 거리 기반 자동 정지/재가동 임계값을 설정합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // ── 정지 거리 ──────────────────────────────────────────────────────
            Row(children: [
              const Text('정지 거리 (Threshold Stop)',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${_stopM.toStringAsFixed(1)} m',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Slider(
              value: _stopM,
              min: 1.0,
              max: 10.0,
              divisions: 18,
              label: '${_stopM.toStringAsFixed(1)} m',
              onChanged: (v) =>
                  setState(() => _stopM = (v * 2).round() / 2), // 0.5m 단위
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Text('재개 거리 (자동 계산)',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              Text('${_resumeM.toStringAsFixed(1)} m  (정지 + 0.1m)',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ]),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            // ── Cooldown ───────────────────────────────────────────────────────
            Row(children: [
              const Text('Cooldown (중복 명령 방지)',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('$_cooldownMs ms',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Slider(
              value: _cooldownMs.toDouble(),
              min: 500,
              max: 3000,
              divisions: 5,
              label: '$_cooldownMs ms',
              onChanged: (v) => setState(() => _cooldownMs = v.round()),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pause/Resume 명령이 연속으로 중복 발행되는 것을 방지합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                child: const Text('적용'),
              ),
            ),

            const SizedBox(height: 24),
            // ── 현재 설정 요약 ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('현재 적용 중인 설정',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _cfgRow('정지 거리',
                      '${SetupService.instance.config.thresholdStopM.toStringAsFixed(1)} m'),
                  _cfgRow('재개 거리',
                      '${SetupService.instance.config.thresholdResumeM.toStringAsFixed(1)} m'),
                  _cfgRow('Cooldown', '${SetupService.instance.config.cooldownMs} ms'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cfgRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text('$label:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
}
