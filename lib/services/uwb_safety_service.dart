import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset;
import '../models/robot_data.dart';
import '../models/safety_zone.dart';
import '../models/setup_config.dart';
import '../models/uwb_distance_event.dart';
import 'map_zone_service.dart';
import 'robot_service.dart';
import 'setup_service.dart';
import 'tag_group_service.dart';

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
/// Threshold는 SetupService.instance.config에서 실시간 조회 (TASK 1).
/// TagGroupService가 제공되면 Relation 기반 threshold 사용 (TASK 2).
class UwbSafetyService {
  final RobotService robotService;
  final Stream<UwbDistanceEvent> uwbStream;
  final Map<String, String> robotTagToIdMap;

  /// null이면 글로벌 threshold 사용 (하위 호환)
  final TagGroupService? tagGroupService;

  // ── 내부 상태 ──────────────────────────────────────────────────────────────

  /// robotId → SafetyState
  final _safetyStates = <String, SafetyState>{};

  /// robotId → { humanTagId → 최신 거리(m) }
  final _distances = <String, Map<String, double>>{};

  /// robotId → 최소 거리 캐시 (UI 표시용)
  final _minDistances = <String, double>{};

  /// robotId → 최근 Safety 명령 발행 시각 (cooldown)
  final _lastActionTime = <String, DateTime>{};

  /// robotId → 최신 RobotStatus
  final _robotStatuses = <String, RobotStatus>{};

  final _log = <SafetyLogEntry>[];
  List<RobotData> _lastRobots = [];

  final _controller = StreamController<List<RobotData>>.broadcast();
  StreamSubscription<List<RobotData>>? _robotSub;
  StreamSubscription<UwbDistanceEvent>? _uwbSub;

  // ── 생성자 (하위 호환 유지) ──────────────────────────────────────────────────

  UwbSafetyService({
    required this.robotService,
    required this.uwbStream,
    required this.robotTagToIdMap,
    this.tagGroupService,
    double thresholdStop = 3.0,
    double thresholdResume = 3.1,
    Duration cooldown = const Duration(milliseconds: 500),
  }) {
    assert(thresholdStop <= thresholdResume,
        'threshold_stop($thresholdStop) must be <= threshold_resume($thresholdResume)');
    // 생성자 파라미터로 SetupConfig 초기값 설정
    final c = SetupService.instance.config;
    c.thresholdStopM = thresholdStop;
    c.thresholdResumeM = thresholdResume;
    c.cooldownMs = cooldown.inMilliseconds;

    _robotSub = robotService.stream.listen(_onRobotUpdate);
    _uwbSub = uwbStream.listen(_onDistanceEvent);
  }

  // ── Config 기반 Threshold 게터 (TASK 1) ───────────────────────────────────

  double get _thresholdStop => SetupService.instance.config.thresholdStopM;
  double get _thresholdResume => SetupService.instance.config.thresholdResumeM;
  Duration get _cooldown =>
      Duration(milliseconds: SetupService.instance.config.cooldownMs);

  /// Safety 설정을 실시간 업데이트 (SafetySettingsTab에서 호출)
  void updateConfig(SetupConfig config) {
    assert(config.thresholdStopM < config.thresholdResumeM);
    final c = SetupService.instance.config;
    c.thresholdStopM = config.thresholdStopM;
    c.thresholdResumeM = config.thresholdResumeM;
    c.cooldownMs = config.cooldownMs;
  }

  // ── Relation 기반 Threshold 결정 (TASK 2) ────────────────────────────────

  double _stopThresholdFor(String humanTagId, String robotTagId) {
    if (tagGroupService != null) {
      final rel = tagGroupService!.getActiveRelation(humanTagId, robotTagId);
      if (rel != null) return rel.thresholdStopM;
    }
    return _thresholdStop;
  }

  double _resumeThresholdFor(String humanTagId, String robotTagId) {
    if (tagGroupService != null) {
      final rel = tagGroupService!.getActiveRelation(humanTagId, robotTagId);
      if (rel != null) return rel.thresholdResumeM;
    }
    return _thresholdResume;
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

    // TASK 2: TagGroupService가 있으면 Relation이 없는 쌍은 무시
    if (tagGroupService != null) {
      final rel =
          tagGroupService!.getActiveRelation(event.humanTagId, event.robotTagId);
      if (rel == null) return;
    }

    _distances.putIfAbsent(robotId, () => {})[event.humanTagId] =
        event.distanceM;
    final minDist = _distances[robotId]!.values.reduce(min);
    _minDistances[robotId] = minDist;

    final safetyState = _safetyStates[robotId] ?? SafetyState.safe;
    final robotStatus = _robotStatuses[robotId] ?? RobotStatus.moving;

    var stopThresh = _stopThresholdFor(event.humanTagId, event.robotTagId);
    var resumeThresh = _resumeThresholdFor(event.humanTagId, event.robotTagId);

    // TASK 3: Zone Safety — 수동 할당 우선, Anchor 위치 기반 폴리곤 fallback
    final zone = _findZoneForEvent(event);
    if (zone != null) {
      if (!zone.safetyEnabled) return; // Zone Safety 비활성 → 이벤트 무시
      if (zone.customThresholdStopM != null) stopThresh = zone.customThresholdStopM!;
      if (zone.customThresholdResumeM != null) resumeThresh = zone.customThresholdResumeM!;
    }

    if (safetyState == SafetyState.safe &&
        robotStatus == RobotStatus.moving &&
        minDist < stopThresh) {
      _triggerPause(robotId, event, minDist);
    } else if (safetyState == SafetyState.stoppedBySafety &&
        minDist > resumeThresh) {
      _triggerResume(robotId, event, minDist);
    }
  }

  // ── Zone 탐색 (TASK 3) ────────────────────────────────────────────────────

  /// anchorId → Zone 탐색.
  /// 우선순위: ① Zone.anchorIds 수동 할당 → ② Anchor 맵 위치가 Zone 폴리곤 내 포함
  SafetyZone? _findZoneForEvent(UwbDistanceEvent event) {
    if (event.anchorId == null) return null;

    // ① 수동 할당
    final byId = MapZoneService.instance.getZoneByAnchorId(event.anchorId!);
    if (byId != null) return byId;

    // ② 위치 기반: Anchor 맵 좌표(0.0~1.0)가 Zone 폴리곤 내에 있는지 판별
    AnchorData? anchor;
    for (final a in SetupService.instance.config.anchors) {
      if (a.id == event.anchorId) {
        anchor = a;
        break;
      }
    }
    if (anchor == null || !anchor.placed) return null;

    return MapZoneService.instance
        .getZoneForPosition(Offset(anchor.mapXRatio, anchor.mapYRatio));
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
    return DateTime.now().difference(last) < _cooldown;
  }

  void _applySafetyStateToRobots(String robotId, SafetyState state) {
    for (final r in _lastRobots) {
      if (r.id == robotId) r.safetyState = state;
    }
    _controller.add(List.from(_lastRobots));
  }

  // ── 공개 API ──────────────────────────────────────────────────────────────

  /// 로봇별 safety state가 반영된 로봇 목록 스트림
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
