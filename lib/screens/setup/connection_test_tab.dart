import 'package:flutter/material.dart';
import '../../services/setup_service.dart';
import '../../models/setup_config.dart';

class ConnectionTestTab extends StatefulWidget {
  const ConnectionTestTab({super.key});

  @override
  State<ConnectionTestTab> createState() => _ConnectionTestTabState();
}

class _ConnectionTestTabState extends State<ConnectionTestTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<HeartbeatAttempt> _hbResults = [];
  List<String> _safetyLog = [];
  bool _hbRunning = false;
  bool _safetyRunning = false;
  String? _selectedRobotId;

  SetupConfig get _cfg => SetupService.instance.config;
  List<String> get _robotIds =>
      _cfg.robotMappings.map((m) => m.robotId).toList();

  Future<void> _runHeartbeat() async {
    setState(() {
      _hbRunning = true;
      _hbResults = List.generate(
          5,
          (i) => const HeartbeatAttempt(
              index: 0, status: TestStatus.idle)); // placeholder
    });
    await for (final attempt in SetupService.instance.heartbeatTest()) {
      setState(() => _hbResults[attempt.index - 1] = attempt);
    }
    setState(() => _hbRunning = false);
  }

  Future<void> _runSafetyTest() async {
    if (_selectedRobotId == null) return;
    setState(() {
      _safetyRunning = true;
      _safetyLog = [];
    });
    await for (final msg
        in SetupService.instance.safetyFunctionTest(_selectedRobotId!)) {
      setState(() => _safetyLog.add(msg));
    }
    setState(() => _safetyRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 현재 설정 정보 ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('FMS URL',
                      _cfg.fmsBaseUrl.isEmpty ? '(미설정)' : _cfg.fmsBaseUrl),
                  _infoRow('Area ID', _cfg.areaId.toString()),
                  _infoRow('등록 로봇 수', '${_cfg.robotMappings.length}개'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Heartbeat Test ───────────────────────────────────────────────
            const Text('Heartbeat Test',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'POST /ics/out/device/list/deviceInfo  — 1Hz × 5회',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _hbRunning ? null : _runHeartbeat,
              icon: _hbRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: const Text('Heartbeat Test 시작'),
            ),
            if (_hbResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              _heartbeatRow(),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Safety Function Test ─────────────────────────────────────────
            const Text('Safety Function Test',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Pause → 3초 대기 → Resume (1회 성공 기준)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '테스트 로봇',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedRobotId,
                    isDense: true,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: Text(
                      _robotIds.isEmpty
                          ? '로봇 매핑 없음 (로봇 매핑 탭 참조)'
                          : '로봇 선택',
                      style: const TextStyle(fontSize: 13),
                    ),
                    items: _robotIds
                        .map((id) =>
                            DropdownMenuItem(value: id, child: Text(id)))
                        .toList(),
                    onChanged: _robotIds.isEmpty
                        ? null
                        : (v) => setState(() => _selectedRobotId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed:
                    (_safetyRunning || _selectedRobotId == null)
                        ? null
                        : _runSafetyTest,
                icon: _safetyRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: const Text('Safety Test 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ]),

            if (_safetyLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _safetyLog.map((line) {
                    final isOk = line.contains('✓');
                    final isFail = line.contains('✗');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isOk
                              ? Colors.greenAccent
                              : isFail
                                  ? Colors.redAccent
                                  : Colors.white70,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(
            width: 90,
            child: Text('$label:',
                style: const TextStyle(color: Colors.grey, fontSize: 12))),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }

  Widget _heartbeatRow() {
    return Row(
      children: List.generate(_hbResults.length, (i) {
        if (i >= _hbResults.length) return const SizedBox();
        final r = _hbResults[i];
        final color = switch (r.status) {
          TestStatus.success => Colors.green,
          TestStatus.failure => Colors.red,
          TestStatus.running => Colors.orange,
          TestStatus.idle => Colors.grey,
        };
        final icon = switch (r.status) {
          TestStatus.success => Icons.check_circle,
          TestStatus.failure => Icons.cancel,
          TestStatus.running => Icons.hourglass_top,
          TestStatus.idle => Icons.radio_button_unchecked,
        };
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              Text('#${i + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold)),
              if (r.message.isNotEmpty)
                Text(r.message,
                    style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        );
      }),
    );
  }
}
