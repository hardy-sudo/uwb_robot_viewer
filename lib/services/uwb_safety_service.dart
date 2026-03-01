import 'dart:async';
import 'dart:math';
import '../models/robot_data.dart';
import '../models/uwb_distance_event.dart';
import 'robot_service.dart';

// ── 로그 ─────────────────────────────────────────────────────────────────────

enum SafetyAction { pause, resume }

class SafetyLogEntry {
  const SafetyLogEntry({
    required this.timestamp,
    required this.robotId,
    required this.causeHumanTagId,
    required this.distanceM,
    required this.action,
  });

  final DateTime timestamp;
  final String robotId;
  final String causeHumanTagId;
  final double distanceM;
  final SafetyAction action;
}

// ── UWB Safety 서비스 ─────────────────────────────────────────────────────────

/// UWB 거리 이벤트를 수신해 로봇 자동 정지/재가동을 수행하는 Safety 제어 서비스.
///
/// 상태 전이:
///   SAFE → STOPPED_BY_SAFETY
///     조건: robot==MOVING  &&  minDist < threshold_stop  &&  safetyState==SAFE
///     동작: controlDevice(controlWay=0, stopType=1) — 즉시 정지
///
///   STOPPED_BY_SAFETY → SAFE
///     조건: minDist > threshold_resume  &&  safetyState==STOPPED_BY_SAFETY
///     동작: controlDevice(controlWay=1) — 재가동
///
/// 중복 호출 방지:
///   - STOPPED_BY_SAFETY 상태에서는 추가 Pause 호출 없음
///   - SAFE 상태에서는 추가 Resume 호출 없음
///   - cooldown 기간 내 동일 명령 재호출 방지
class UwbSafetyService {
  final RobotService robotService;
  final Stream<UwbDistanceEvent> uwbStream;

  /// robotTagId → robot_id 매핑 (예: {'TAG_R1': 'R1'})
  final Map<String, String> robotTagToIdMap;

  final double thresholdStop;   // 정지 트리거 거리 (m)
  final double thresholdResume; // 재가동 트리거 거리 (m)
  final Duration cooldown;      // Pause/Resume 중복 호출 방지 간격

  // ── 내부 상태 ──────────────────────────────────────────────────────────────

  /// robotId → SafetyState
  final _safetyStates = <String, SafetyState>{};

  /// robotId → { humanTagId → 최신 거리(m) }  (다중 작업자 대응)
  final _distances = <String, Map<String, double>>{};

  /// robotId → 최소 거리 캐시 (UI 표시용)
  final _minDistances = <String, double>{};

  /// robotId → 최근 Safety 명령 발행 시각 (cooldown)
  final _lastActionTime = <String, DateTime>{};

  /// robotId → 최신 RobotStatus (로봇 서비스 스트림에서 수신)
  final _robotStatuses = <String, RobotStatus>{};

  final _log = <SafetyLogEntry>[];
  List<RobotData> _lastRobots = [];

  final _controller = StreamController<List<RobotData>>.broadcast();
  StreamSubscription<List<RobotData>>? _robotSub;
  StreamSubscription<UwbDistanceEvent>? _uwbSub;

  UwbSafetyService({
    required this.robotService,
    required this.uwbStream,
    required this.robotTagToIdMap,
    this.thresholdStop = 3.0,
    this.thresholdResume = 3.1,
    this.cooldown = const Duration(milliseconds: 500),
  }) {
    assert(thresholdStop <= thresholdResume,
        'threshold_stop($thresholdStop) must be <= threshold_resume($thresholdResume)');
    _robotSub = robotService.stream.listen(_onRobotUpdate);
    _uwbSub = uwbStream.listen(_onDistanceEvent);
  }

  // ── 스트림 핸들러 ──────────────────────────────────────────────────────────

  void _onRobotUpdate(List<RobotData> robots) {
    for (final r in robots) {
      final prevStatus = _robotStatuses[r.id];
      _robotStatuses[r.id] = r.status;

      // 운영자가 수동으로 재가동한 경우: STOPPED_BY_SAFETY → SAFE 자동 해제
      if (_safetyStates[r.id] == SafetyState.stoppedBySafety &&
          r.status == RobotStatus.moving &&
          prevStatus == RobotStatus.stopped) {
        _safetyStates[r.id] = SafetyState.safe;
      }

      r.safetyState = _safetyStates[r.id] ?? SafetyState.safe;
    }
    _lastRobots = robots;
    _controller.add(robots);
  }

  void _onDistanceEvent(UwbDistanceEvent event) {
    final robotId = robotTagToIdMap[event.robotTagId];
    if (robotId == null) return;

    // 해당 로봇에 대해 작업자별 거리 갱신 후 최솟값 계산
    _distances.putIfAbsent(robotId, () => {})[event.humanTagId] = event.distanceM;
    final minDist = _distances[robotId]!.values.reduce(min);
    _minDistances[robotId] = minDist;

    final safetyState = _safetyStates[robotId] ?? SafetyState.safe;
    final robotStatus = _robotStatuses[robotId] ?? RobotStatus.moving;

    if (safetyState == SafetyState.safe &&
        robotStatus == RobotStatus.moving &&
        minDist < thresholdStop) {
      _triggerPause(robotId, event, minDist);
    } else if (safetyState == SafetyState.stoppedBySafety &&
               minDist > thresholdResume) {
      _triggerResume(robotId, event, minDist);
    }
  }

  // ── Pause / Resume 트리거 ──────────────────────────────────────────────────

  void _triggerPause(String robotId, UwbDistanceEvent event, double minDist) {
    if (_isCooldownActive(robotId)) return;

    _safetyStates[robotId] = SafetyState.stoppedBySafety;
    _lastActionTime[robotId] = DateTime.now();
    _applySafetyStateToRobots(robotId, SafetyState.stoppedBySafety);

    robotService.sendStop(robotId);

    _log.add(SafetyLogEntry(
      timestamp: DateTime.now(),
      robotId: robotId,
      causeHumanTagId: event.humanTagId,
      distanceM: minDist,
      action: SafetyAction.pause,
    ));
  }

  void _triggerResume(String robotId, UwbDistanceEvent event, double minDist) {
    if (_isCooldownActive(robotId)) return;

    _safetyStates[robotId] = SafetyState.safe;
    _lastActionTime[robotId] = DateTime.now();
    _applySafetyStateToRobots(robotId, SafetyState.safe);

    robotService.sendResume(robotId);

    _log.add(SafetyLogEntry(
      timestamp: DateTime.now(),
      robotId: robotId,
      causeHumanTagId: event.humanTagId,
      distanceM: minDist,
      action: SafetyAction.resume,
    ));
  }

  // ── 헬퍼 ──────────────────────────────────────────────────────────────────

  bool _isCooldownActive(String robotId) {
    final last = _lastActionTime[robotId];
    if (last == null) return false;
    return DateTime.now().difference(last) < cooldown;
  }

  void _applySafetyStateToRobots(String robotId, SafetyState state) {
    for (final r in _lastRobots) {
      if (r.id == robotId) r.safetyState = state;
    }
    _controller.add(List.from(_lastRobots));
  }

  // ── 공개 API ──────────────────────────────────────────────────────────────

  /// 로봇별 safety state 가 반영된 로봇 목록 스트림
  Stream<List<RobotData>> get stream => _controller.stream;

  /// 로봇별 최소 UWB 거리 (UI 표시용). key = robot_id
  Map<String, double> get latestMinDistances => Map.unmodifiable(_minDistances);

  /// Safety 이벤트 로그 (불변 뷰)
  List<SafetyLogEntry> get log => List.unmodifiable(_log);

  void dispose() {
    _robotSub?.cancel();
    _uwbSub?.cancel();
    _controller.close();
  }
}
