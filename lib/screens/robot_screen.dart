import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/robot_data.dart';
import '../models/uwb_distance_event.dart';
import '../services/dahua_robot_service.dart';
import '../services/mock_uwb_service.dart';
import '../services/real_uwb_service.dart';
import '../services/robot_service.dart';
import '../services/setup_service.dart';
import '../services/uwb_safety_service.dart';
import '../widgets/robot_dot.dart';
import '../widgets/grid_overlay.dart';

class RobotScreen extends StatefulWidget {
  const RobotScreen({super.key});
  @override
  State<RobotScreen> createState() => _RobotScreenState();
}

class _RobotScreenState extends State<RobotScreen> {
  final double maxX = 6.0;
  final double maxY = 6.0;

  late final RobotService _service;

  // ── UWB 서비스 (Mock ↔ Real 전환 가능) ─────────────────────────────────────
  bool _useMockUwb = true;
  MockUwbService? _mockUwb;
  RealUwbService? _realUwb;
  UwbSafetyService? _safetyService;
  StreamSubscription<List<RobotData>>? _sub;

  List<RobotData> _robots = [];

  // ── 로봇 컨트롤 패널 상태 ──────────────────────────────────────────────────
  String? _selectedRobotId;
  final List<_CommLogEntry> _commLog = [];
  bool _isSendingCommand = false;

  @override
  void initState() {
    super.initState();
    final cfg = SetupService.instance.config;

    _service = DahuaRobotService(
      baseUrl: cfg.fmsBaseUrl,
      areaId: cfg.areaId,
      mapWidthMm: 200000,
      mapHeightMm: 200000,
    );

    // ── UWB 소스 선택 ────────────────────────────────────────────────────────
    _initUwb(mock: true);
  }

  // ── UWB 서비스 초기화 ────────────────────────────────────────────────────────

  void _initUwb({required bool mock, String? portName}) {
    _teardownUwb();

    final Stream<UwbDistanceEvent> uwbStream;
    final Map<String, String> tagMap;

    if (mock) {
      _mockUwb = MockUwbService();
      uwbStream = _mockUwb!.stream;
      tagMap = MockUwbService.robotTagToIdMap;
    } else {
      _realUwb = RealUwbService(portName: portName!);
      uwbStream = _realUwb!.stream;
      tagMap = _buildRealTagMap();
    }

    final cfg = SetupService.instance.config;
    _safetyService = UwbSafetyService(
      robotService: _service,
      uwbStream: uwbStream,
      robotTagToIdMap: tagMap,
      thresholdStop: cfg.thresholdStopM,
      thresholdResume: cfg.thresholdResumeM,
      cooldown: Duration(milliseconds: cfg.cooldownMs),
    );

    _sub = _safetyService!.stream.listen((robots) {
      if (mounted) setState(() => _robots = robots);
    });

    _useMockUwb = mock;
  }

  void _teardownUwb() {
    _sub?.cancel();
    _safetyService?.dispose();
    _mockUwb?.dispose();
    _realUwb?.dispose();
    _sub = null;
    _safetyService = null;
    _mockUwb = null;
    _realUwb = null;
  }

  /// SetupService.config.robotMappings 에서 tagId → robotId 맵 생성
  Map<String, String> _buildRealTagMap() {
    return {
      for (final m in SetupService.instance.config.robotMappings)
        if (m.tagId.isNotEmpty) m.tagId: m.robotId,
    };
  }

  @override
  void dispose() {
    _teardownUwb();
    _service.dispose();
    super.dispose();
  }

  // ── UWB 소스 선택 다이얼로그 ─────────────────────────────────────────────────

  void _showUwbSourceDialog() {
    final ports = RealUwbService.availablePorts;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UWB 소스 선택'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.science),
                title: const Text('Mock (시뮬레이션)'),
                subtitle: const Text('R1↔W1 코사인 파형, R2↔W2 안전 거리'),
                selected: _useMockUwb,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _initUwb(mock: true));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  '실 하드웨어 (UART 115200)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              if (ports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '연결된 시리얼 포트 없음\n(USB 케이블 연결 후 재시도)',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                for (final port in ports)
                  ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text(port),
                    selected: !_useMockUwb,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _initUwb(mock: false, portName: port));
                    },
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentLog = _safetyService?.log.reversed.take(5).toList() ?? [];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 지도 + 로봇 컨트롤 ────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRobotId = null),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: Stack(children: [
                      Positioned.fill(child: GridOverlay(maxX: maxX, maxY: maxY)),
                      for (final r in _robots) _marker(r, w, h),
                      // ── 선택된 로봇 컨트롤 바 (맵 하단 오버레이) ─────────
                      if (_selectedRobotId != null)
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: _mapControlBar(),
                        ),
                    ]),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // ── UWB Safety 상태 헤더 ────────────────────────────────────────
            _safetyStatusHeader(),

            const SizedBox(height: 8),

            // ── UWB 소스 배지 ────────────────────────────────────────────────
            Row(
              children: [
                _uwbSourceBadge(),
              ],
            ),

            const SizedBox(height: 16),

            // ── 로봇 상태 목록 ───────────────────────────────────────────────
            const Text('로봇 상태', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_robots.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              for (final r in _robots) _statusTile(r),

            // ── Safety 이벤트 로그 ──────────────────────────────────────────
            if (recentLog.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Safety 이벤트 로그',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final entry in recentLog) _logTile(entry),
            ],
          ],
        ),
      ),
    );
  }

  // ── 로봇 컨트롤 패널 ──────────────────────────────────────────────────────

  Widget _robotControlPanel() {
    final cfg = SetupService.instance.config;
    final selectedRobot = _selectedRobotId != null
        ? _robots.cast<RobotData?>().firstWhere(
              (r) => r!.id == _selectedRobotId,
              orElse: () => null,
            )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 설정 바 ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
            ),
            child: Row(children: [
              _cfgLabel('FMS'),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cfg.fmsBaseUrl.isEmpty ? '(미설정)' : cfg.fmsBaseUrl,
                  style: const TextStyle(
                    color: Color(0xFFC9D1D9),
                    fontFamily: 'Courier New',
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              _cfgLabel('ROBOT ID'),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRobotId,
                    isDense: true,
                    dropdownColor: const Color(0xFF161B22),
                    hint: const Text('선택',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                    style: const TextStyle(
                      color: Color(0xFFC9D1D9),
                      fontFamily: 'Courier New',
                      fontSize: 12,
                    ),
                    items: _robots
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.id),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRobotId = v),
                  ),
                ),
              ),
            ]),
          ),

          // ── 상태 바 ──────────────────────────────────────────────────────
          if (selectedRobot != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF16213E),
                border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
              ),
              child: Row(children: [
                _statItem('STATE',
                    selectedRobot.status == RobotStatus.moving ? 'Moving' : 'Stopped',
                    selectedRobot.status == RobotStatus.moving
                        ? const Color(0xFF79C0FF)
                        : const Color(0xFFF85149)),
                const SizedBox(width: 14),
                _statItem('POS',
                    selectedRobot.devicePosition ?? '—',
                    const Color(0xFFE3B341)),
                const SizedBox(width: 14),
                _statItem('PAUSE',
                    selectedRobot.pauseFlag ? 'ON' : 'OFF',
                    selectedRobot.pauseFlag
                        ? const Color(0xFFF85149)
                        : const Color(0xFF3FB950)),
                const SizedBox(width: 14),
                _statItem('BAT',
                    selectedRobot.battery != null ? '${selectedRobot.battery}%' : '—',
                    const Color(0xFF3FB950)),
                const Spacer(),
                // 연결 상태 인디케이터
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedRobot.deviceState == DeviceState.offline
                        ? const Color(0xFFF85149)
                        : const Color(0xFF3FB950),
                  ),
                ),
              ]),
            ),

          // ── PAUSE / RESUME / CHARGE 버튼 ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: _controlButton(
                  label: 'PAUSE',
                  color: const Color(0xFFF85149),
                  icon: Icons.pause_circle_filled,
                  enabled: _selectedRobotId != null && !_isSendingCommand,
                  onPressed: () => _sendControlCommand(0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _controlButton(
                  label: 'RESUME',
                  color: const Color(0xFF238636),
                  icon: Icons.play_circle_filled,
                  enabled: _selectedRobotId != null && !_isSendingCommand,
                  onPressed: () => _sendControlCommand(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _controlButton(
                  label: 'CHARGE',
                  color: const Color(0xFF1F6FEB),
                  icon: Icons.battery_charging_full,
                  enabled: _selectedRobotId != null && !_isSendingCommand,
                  onPressed: () => _sendChargeCommand(),
                ),
              ),
            ]),
          ),

          // ── 통신 로그 ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                top: BorderSide(color: Color(0xFF21262D)),
              ),
            ),
            child: Row(children: [
              const Text('통신 로그',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _commLog.clear()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear',
                    style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 11)),
              ),
            ]),
          ),
          Container(
            height: 120,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: _commLog.isEmpty
                ? const Center(
                    child: Text('로봇을 선택하고 명령을 보내세요.',
                        style: TextStyle(color: Color(0xFF484F58), fontSize: 12)))
                : ListView.builder(
                    reverse: true,
                    itemCount: _commLog.length,
                    itemBuilder: (_, i) {
                      final entry = _commLog[_commLog.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '[${_fmtTs(entry.timestamp)}]  ',
                              style: const TextStyle(color: Color(0xFF484F58)),
                            ),
                            TextSpan(
                              text: entry.isSuccess ? '✓ ' : '✗ ',
                              style: TextStyle(
                                color: entry.isSuccess
                                    ? const Color(0xFF3FB950)
                                    : const Color(0xFFF85149),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '${entry.action}  ',
                              style: TextStyle(
                                color: _actionColor(entry.action),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: entry.message,
                              style: const TextStyle(color: Color(0xFF8B949E)),
                            ),
                          ]),
                          style: const TextStyle(
                            fontFamily: 'Courier New',
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cfgLabel(String text) {
    return Text(text,
        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11));
  }

  Widget _statItem(String label, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label ',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10)),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _controlButton({
    required String label,
    required Color color,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withAlpha(100),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    return switch (action) {
      'PAUSE' => const Color(0xFFF85149),
      'RESUME' => const Color(0xFF3FB950),
      'CHARGE' => const Color(0xFF388BFD),
      _ => const Color(0xFF8B949E),
    };
  }

  String _fmtTs(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.'
      '${dt.millisecond.toString().padLeft(3, '0')}';

  // ── API 명령 전송 ─────────────────────────────────────────────────────────

  void _addLog(String action, bool success, String message) {
    setState(() {
      _commLog.add(_CommLogEntry(
        timestamp: DateTime.now(),
        action: action,
        isSuccess: success,
        message: message,
      ));
      // 최대 50개 유지
      if (_commLog.length > 50) _commLog.removeAt(0);
    });
  }

  /// Dahua RCS API: controlDevice (Pause / Resume)
  /// Dahua RCS API: controlDevice (Pause / Resume)
  /// [robotId] 지정 시 해당 로봇에, 없으면 현재 _selectedRobotId 에 명령
  Future<void> _sendControlCommand(int controlWay, {String? robotId}) async {
    final id = robotId ?? _selectedRobotId;
    if (id == null) return;
    final action = controlWay == 0 ? 'PAUSE' : 'RESUME';
    final cfg = SetupService.instance.config;
    final url = '${cfg.fmsBaseUrl}/ics/out/controlDevice';
    final payload = <String, dynamic>{
      'areaId': cfg.areaId,
      'deviceNumber': id,
      'all': 0,
      'controlWay': controlWay,
    };
    if (controlWay == 0) payload['stopType'] = 1; // 즉시 정지

    setState(() => _isSendingCommand = true);
    _addLog(action, true, 'POST $url → ${jsonEncode(payload)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = response.statusCode == 200 && body['code'] == 1000;
      _addLog(action, ok, 'HTTP ${response.statusCode} ← ${jsonEncode(body)}');

      if (ok) {
        if (controlWay == 0) {
          _service.sendStop(id);
        } else {
          _service.sendResume(id);
        }
      }
    } catch (e) {
      _addLog(action, false, 'ERROR: $e');
    } finally {
      setState(() => _isSendingCommand = false);
    }
  }

  /// Dahua RCS API: gocharging (Charge)
  Future<void> _sendChargeCommand({String? robotId}) async {
    final id = robotId ?? _selectedRobotId;
    if (id == null) return;
    const action = 'CHARGE';
    final cfg = SetupService.instance.config;
    final url = '${cfg.fmsBaseUrl}/ics/out/gocharging';
    final payload = {'deviceNumber': id};

    setState(() => _isSendingCommand = true);
    _addLog(action, true, 'POST $url → ${jsonEncode(payload)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = response.statusCode == 200 && body['code'] == 1000;
      _addLog(action, ok, 'HTTP ${response.statusCode} ← ${jsonEncode(body)}');
    } catch (e) {
      _addLog(action, false, 'ERROR: $e');
    } finally {
      setState(() => _isSendingCommand = false);
    }
  }

  // ── UWB 소스 배지 ─────────────────────────────────────────────────────────

  Widget _uwbSourceBadge() {
    final isMock = _useMockUwb;
    final color = isMock ? Colors.blue : Colors.green;
    return GestureDetector(
      onTap: _showUwbSourceDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isMock ? Icons.science : Icons.usb, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isMock ? 'Mock' : _realUwb?.portName ?? 'Real UART',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 4),
          Icon(Icons.swap_horiz, size: 13, color: color),
        ]),
      ),
    );
  }

  // ── UWB Safety 상태 헤더 ──────────────────────────────────────────────────

  Widget _safetyStatusHeader() {
    final anyStopped = _robots.any((r) => r.safetyState == SafetyState.stoppedBySafety);
    final cfg = SetupService.instance.config;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: anyStopped ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: anyStopped ? Colors.red : Colors.green,
        ),
      ),
      child: Row(children: [
        Icon(
          anyStopped ? Icons.warning_rounded : Icons.shield,
          color: anyStopped ? Colors.red : Colors.green,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          anyStopped ? 'UWB Safety — 정지 중인 로봇 있음' : 'UWB Safety — 전체 안전',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: anyStopped ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '  ▸ stop < ${cfg.thresholdStopM}m  |  resume > ${cfg.thresholdResumeM}m',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]),
    );
  }

  // ── 로봇 상태 타일 ────────────────────────────────────────────────────────

  Widget _statusTile(RobotData r) {
    final isStopped = r.status == RobotStatus.stopped;
    final isSafetyStopped = r.safetyState == SafetyState.stoppedBySafety;
    final isFault = r.deviceState == DeviceState.fault;
    final isOffline = r.deviceState == DeviceState.offline;
    final uwbDist = _safetyService?.latestMinDistances[r.id];
    final busy = _isSendingCommand;

    // 카드 테두리 색 결정
    final borderColor = isSafetyStopped
        ? Colors.red
        : isFault
            ? Colors.yellow.shade700
            : isOffline
                ? Colors.grey
                : r.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withAlpha(180), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단: 로봇 정보 행 ────────────────────────────────
            Row(children: [
              // 색상 인디케이터
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: r.color),
              ),
              const SizedBox(width: 8),

              // 로봇 ID
              Text(r.id,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 10),

              // 좌표
              Text(
                'X: ${r.currentX.toStringAsFixed(2)}  Y: ${r.currentY.toStringAsFixed(2)}',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[700]),
              ),

              const Spacer(),

              // UWB 거리
              if (uwbDist != null) ...[
                Icon(Icons.sensors, size: 14,
                    color: uwbDist < 3.0 ? Colors.red : Colors.grey),
                const SizedBox(width: 3),
                Text(
                  '${uwbDist.toStringAsFixed(2)}m',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: uwbDist < 3.0
                        ? Colors.red
                        : uwbDist < 3.5
                            ? Colors.orange
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // 배터리
              if (r.battery != null) ...[
                Icon(
                  r.battery! > 50 ? Icons.battery_full
                      : r.battery! > 20 ? Icons.battery_3_bar
                      : Icons.battery_alert,
                  size: 14,
                  color: r.battery! > 20 ? Colors.grey : Colors.red,
                ),
                const SizedBox(width: 3),
                Text('${r.battery}%',
                    style: TextStyle(
                        fontSize: 12,
                        color: r.battery! > 20 ? Colors.grey[600] : Colors.red)),
                const SizedBox(width: 10),
              ],
            ]),

            const SizedBox(height: 8),

            // ── 중단: 상태 뱃지 행 ───────────────────────────────
            Row(children: [
              _badge(isStopped ? 'STOPPED' : 'MOVING',
                  isStopped ? Colors.red : Colors.green),
              const SizedBox(width: 6),
              if (isSafetyStopped)
                _badge('SAFETY STOP', Colors.red, icon: Icons.warning_rounded)
              else
                _badge('SAFE', Colors.teal, icon: Icons.shield),
              if (isFault) ...[
                const SizedBox(width: 6),
                _badge('FAULT', Colors.yellow.shade700, icon: Icons.error_outline),
              ] else if (isOffline) ...[
                const SizedBox(width: 6),
                _badge('OFFLINE', Colors.grey, icon: Icons.wifi_off),
              ],
              if (r.pauseFlag) ...[
                const SizedBox(width: 6),
                _badge('PAUSED', Colors.deepOrange, icon: Icons.pause_circle_outline),
              ],
              if (r.devicePosition != null && r.devicePosition!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text(r.devicePosition!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ]),

            const SizedBox(height: 10),

            // ── 하단: 제어 버튼 행 ───────────────────────────────
            Row(children: [
              // PAUSE
              Expanded(
                child: _tileActionButton(
                  label: 'PAUSE',
                  icon: Icons.pause_circle_filled,
                  color: const Color(0xFFE53935),
                  enabled: !busy && !isOffline && !isStopped,
                  onPressed: () => _sendControlCommand(0, robotId: r.id),
                ),
              ),
              const SizedBox(width: 8),
              // RESUME
              Expanded(
                child: _tileActionButton(
                  label: 'RESUME',
                  icon: Icons.play_circle_filled,
                  color: const Color(0xFF2E7D32),
                  enabled: !busy && !isOffline && isStopped,
                  onPressed: () => _sendControlCommand(1, robotId: r.id),
                ),
              ),
              const SizedBox(width: 8),
              // CHARGE
              Expanded(
                child: _tileActionButton(
                  label: 'CHARGE',
                  icon: Icons.battery_charging_full,
                  color: const Color(0xFF1565C0),
                  enabled: !busy && !isOffline,
                  onPressed: () => _sendChargeCommand(robotId: r.id),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 2),
        ],
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── Safety 이벤트 로그 타일 ───────────────────────────────────────────────

  Widget _logTile(SafetyLogEntry entry) {
    final isPause = entry.action == SafetyAction.pause;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        _badge(isPause ? 'PAUSE' : 'RESUME',
            isPause ? Colors.deepOrange : Colors.teal),
        const SizedBox(width: 8),
        Text(entry.robotId, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text('← ${entry.causeHumanTagId}',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 8),
        Text('${entry.distanceM.toStringAsFixed(2)}m',
            style: TextStyle(
                fontFamily: 'monospace',
                color: isPause ? Colors.red : Colors.green)),
        const Spacer(),
        Text(
          _formatTime(entry.timestamp),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ]),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  // ── 지도 마커 ─────────────────────────────────────────────────────────────

  Widget _marker(RobotData r, double w, double h) {
    const dotSize = 24.0;
    const labelHeight = 14.0;
    const spacing = 2.0;
    const totalHeight = dotSize + spacing + labelHeight;

    final isStopped = r.status == RobotStatus.stopped;
    final isSafetyStopped = r.safetyState == SafetyState.stoppedBySafety;
    final isFault = r.deviceState == DeviceState.fault;
    final isOffline = r.deviceState == DeviceState.offline;

    Color dotColor;
    IconData? overlayIcon;
    if (isSafetyStopped) {
      dotColor = Colors.red;
      overlayIcon = Icons.warning_rounded;
    } else if (isFault) {
      dotColor = Colors.yellow.shade700;
      overlayIcon = Icons.error_outline;
    } else if (isOffline) {
      dotColor = Colors.grey;
      overlayIcon = Icons.wifi_off;
    } else if (isStopped) {
      dotColor = Colors.grey.shade400;
      overlayIcon = Icons.stop;
    } else {
      dotColor = r.color;
    }

    final isSelected = r.id == _selectedRobotId;

    return Positioned(
      left: (r.currentX / maxX) * w - dotSize / 2,
      top: (1 - r.currentY / maxY) * h - totalHeight / 2,
      child: GestureDetector(
        onTap: () => setState(() =>
            _selectedRobotId = _selectedRobotId == r.id ? null : r.id),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            // 선택 링
            if (isSelected)
              Container(
                width: dotSize + 12,
                height: dotSize + 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
            // 상태별 링 표시
            else if (isSafetyStopped)
              Container(
                width: dotSize + 8,
                height: dotSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
              )
            else if (isFault)
              Container(
                width: dotSize + 8,
                height: dotSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellow.shade700, width: 2),
                ),
              )
            else if (isOffline)
              Container(
                width: dotSize + 8,
                height: dotSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 2),
                ),
              ),
            RobotDot(color: dotColor),
            if (overlayIcon != null)
              Icon(overlayIcon, color: Colors.white, size: 14),
          ]),
          const SizedBox(height: spacing),
          Text(r.id, style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.blue : Colors.black,
          )),
        ]),
      ),
    );
  }

  // ── 맵 내부 컨트롤 바 ────────────────────────────────────────────────────

  Widget _mapControlBar() {
    final selectedRobot = _robots.cast<RobotData?>().firstWhere(
          (r) => r!.id == _selectedRobotId,
          orElse: () => null,
        );
    if (selectedRobot == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withAlpha(230),
        border: const Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단: 로봇 정보
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedRobot.color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selectedRobot.id,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 12),
            _miniStat('STATE',
                selectedRobot.status == RobotStatus.moving ? 'Moving' : 'Stopped',
                selectedRobot.status == RobotStatus.moving
                    ? const Color(0xFF79C0FF) : const Color(0xFFF85149)),
            const SizedBox(width: 10),
            if (selectedRobot.battery != null)
              _miniStat('BAT', '${selectedRobot.battery}%',
                  const Color(0xFF3FB950)),
            const SizedBox(width: 10),
            _miniStat('PAUSE',
                selectedRobot.pauseFlag ? 'ON' : 'OFF',
                selectedRobot.pauseFlag
                    ? const Color(0xFFF85149) : const Color(0xFF3FB950)),
            const Spacer(),
            // 연결 상태 도트
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectedRobot.deviceState == DeviceState.offline
                    ? const Color(0xFFF85149)
                    : const Color(0xFF3FB950),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // 하단: PAUSE / RESUME / CHARGE 버튼
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSendingCommand ? null : () => _sendControlCommand(0, robotId: selectedRobot.id),
                  icon: const Icon(Icons.pause_circle_filled, size: 18),
                  label: const Text('PAUSE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF85149),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF85149).withAlpha(100),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSendingCommand ? null : () => _sendControlCommand(1, robotId: selectedRobot.id),
                  icon: const Icon(Icons.play_circle_filled, size: 18),
                  label: const Text('RESUME',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF238636).withAlpha(100),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSendingCommand ? null : () => _sendChargeCommand(robotId: selectedRobot.id),
                  icon: const Icon(Icons.battery_charging_full, size: 18),
                  label: const Text('CHARGE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6FEB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1F6FEB).withAlpha(100),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label ',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 9)),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}

/// 통신 로그 항목
class _CommLogEntry {
  final DateTime timestamp;
  final String action;
  final bool isSuccess;
  final String message;

  const _CommLogEntry({
    required this.timestamp,
    required this.action,
    required this.isSuccess,
    required this.message,
  });
}
