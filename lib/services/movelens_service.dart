import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/movelens_center.dart';
import '../models/movelens_session.dart';
import '../models/movelens_zone.dart';
import '../models/movelens_tag_mapping.dart';

// ────────────────────────────────────────────────────
// MoveLensService — 싱글턴
// ────────────────────────────────────────────────────

class MoveLensService {
  static final instance = MoveLensService._();
  MoveLensService._();

  static const _kCenters = 'movelens_centers';

  // ── 상태 ──────────────────────────────────────────
  final List<MoveLensCenter> _centers = [];
  List<MoveLensCenter> get centers => List.unmodifiable(_centers);

  // 활성 세션 스트림 (SessionScreen이 구독)
  final _positionCtrl =
      StreamController<List<TagPosition>>.broadcast();
  Stream<List<TagPosition>> get positionStream => _positionCtrl.stream;

  Timer? _mockTimer;
  final Map<String, _MockTagState> _mockStates = {};

  // ── 퍼시스턴스 ────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCenters);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _centers.addAll(
        list.map((e) => MoveLensCenter.fromJson(e as Map<String, dynamic>)),
      );
    }
  }

  void _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCenters,
      jsonEncode(_centers.map((c) => c.toJson()).toList()),
    );
  }

  // ── 센터 CRUD ────────────────────────────────────
  MoveLensCenter addCenter({
    required String name,
    String clientName = '',
    String description = '',
    String mapImageUrl = '',
  }) {
    final center = MoveLensCenter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      clientName: clientName,
      description: description,
      mapImageUrl: mapImageUrl,
    );
    _centers.add(center);
    _save();
    return center;
  }

  void updateCenter(MoveLensCenter center) => _save();

  void deleteCenter(String id) {
    _centers.removeWhere((c) => c.id == id);
    _save();
  }

  MoveLensCenter? getCenter(String id) {
    try {
      return _centers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Zone CRUD ────────────────────────────────────
  MoveLensZone addZone(
    MoveLensCenter center, {
    required String name,
    String label = '',
    ZoneShape shape = ZoneShape.polygon,
    required List<dynamic> polygon, // List<Offset> for polygon
    double centerX = 0.5,
    double centerY = 0.5,
    double radius = 0.1,
  }) {
    final zone = MoveLensZone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      label: label,
      shape: shape,
    );
    if (shape == ZoneShape.circle) {
      zone.center = Offset(centerX, centerY);
      zone.radius = radius;
    } else {
      zone.polygon = List<Offset>.from(polygon);
    }
    center.zones.add(zone);
    _save();
    return zone;
  }

  void deleteZone(MoveLensCenter center, String zoneId) {
    center.zones.removeWhere((z) => z.id == zoneId);
    center.fromToRules
        .removeWhere((r) => r.fromZoneId == zoneId || r.toZoneId == zoneId);
    _save();
  }

  // ── 태그 매핑 CRUD ───────────────────────────────
  void addTagMapping(MoveLensCenter center, MoveLensTagMapping mapping) {
    center.tagMappings.removeWhere((t) => t.tagId == mapping.tagId);
    center.tagMappings.add(mapping);
    _save();
  }

  void deleteTagMapping(MoveLensCenter center, String tagId) {
    center.tagMappings.removeWhere((t) => t.tagId == tagId);
    _save();
  }

  // ── From-To Rule CRUD ───────────────────────────
  void addFromToRule(MoveLensCenter center, FromToRule rule) {
    center.fromToRules.add(rule);
    _save();
  }

  void deleteFromToRule(MoveLensCenter center, int index) {
    if (index >= 0 && index < center.fromToRules.length) {
      center.fromToRules.removeAt(index);
      _save();
    }
  }

  // ── 세션 관리 ────────────────────────────────────
  MoveLensSession startSession(MoveLensCenter center) {
    final session = MoveLensSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      centerId: center.id,
      startTime: DateTime.now(),
      status: SessionStatus.running,
    );
    center.sessions.add(session);
    _save();

    // Mock 위치 생성 시작
    _startMockPositioning(center, session);
    return session;
  }

  void stopSession(MoveLensCenter center) {
    final session = center.activeSession;
    if (session == null) return;

    _stopMockPositioning();

    session.endTime = DateTime.now();
    session.status = SessionStatus.completed;

    // Trip 이벤트 분석
    _processTripEvents(center, session);
    _save();
  }

  // ── Zone 판별 ────────────────────────────────────
  MoveLensZone? findZoneForPosition(
      MoveLensCenter center, double x, double y) {
    for (final zone in center.zones) {
      if (zone.contains(x, y)) return zone;
    }
    return null;
  }

  // ── Trip 이벤트 생성 ─────────────────────────────
  void _processTripEvents(MoveLensCenter center, MoveLensSession session) {
    // 태그별로 rawEvents를 시간순 정렬 후 zone 진입/이탈 감지
    final tagIds = session.rawEvents.map((e) => e.tagId).toSet();

    for (final tagId in tagIds) {
      final events = session.rawEvents
          .where((e) => e.tagId == tagId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      String? currentZoneId;
      DateTime? zoneEntryTime;

      for (final event in events) {
        final zone = findZoneForPosition(center, event.x, event.y);
        final newZoneId = zone?.id;

        if (newZoneId != currentZoneId) {
          // Zone 전환 감지
          if (currentZoneId != null && newZoneId != null) {
            // From-To Rule 확인
            final ruleExists = center.fromToRules.any((r) =>
                (r.fromZoneId == currentZoneId && r.toZoneId == newZoneId) ||
                (r.bidirectional &&
                    r.fromZoneId == newZoneId &&
                    r.toZoneId == currentZoneId));
            if (ruleExists) {
              session.tripEvents.add(MoveLensTripEvent(
                tagId: tagId,
                fromZoneId: currentZoneId,
                toZoneId: newZoneId,
                departureTime: zoneEntryTime!,
                arrivalTime: event.timestamp,
              ));
            }
          }
          currentZoneId = newZoneId;
          zoneEntryTime = event.timestamp;
        }
      }
    }
  }

  // ── 분석 ─────────────────────────────────────────
  MoveLensAnalysis analyzeSession(
      MoveLensCenter center, MoveLensSession session) {
    final trips = session.tripEvents;
    if (trips.isEmpty) {
      return const MoveLensAnalysis(
        totalTrips: 0,
        totalMovementTime: Duration.zero,
        totalIdleTime: Duration.zero,
        movementRatio: 0,
        tripCountByRoute: {},
        avgDurationByRoute: {},
        topRoutes: [],
      );
    }

    final countByRoute = <String, int>{};
    final durationByRoute = <String, List<Duration>>{};
    Duration totalMovement = Duration.zero;

    for (final trip in trips) {
      final key = _routeKey(center, trip.fromZoneId, trip.toZoneId);
      countByRoute[key] = (countByRoute[key] ?? 0) + 1;
      durationByRoute.putIfAbsent(key, () => []).add(trip.duration);
      totalMovement += trip.duration;
    }

    final avgByRoute = durationByRoute.map((k, durations) => MapEntry(
          k,
          Duration(
            microseconds: durations
                    .map((d) => d.inMicroseconds)
                    .reduce((a, b) => a + b) ~/
                durations.length,
          ),
        ));

    final topRoutes = countByRoute.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalOperatingMs =
        center.schedule.totalOperatingMinutes * 60 * 1000;
    final elapsedMs = session.elapsed.inMilliseconds;
    final operatingMs = min(totalOperatingMs.toDouble(), elapsedMs.toDouble());
    final ratio = operatingMs > 0
        ? (totalMovement.inMilliseconds / operatingMs * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    return MoveLensAnalysis(
      totalTrips: trips.length,
      totalMovementTime: totalMovement,
      totalIdleTime: session.elapsed - totalMovement,
      movementRatio: ratio,
      tripCountByRoute: countByRoute,
      avgDurationByRoute: avgByRoute,
      topRoutes: topRoutes.take(5).map((e) => e.key).toList(),
    );
  }

  String _routeKey(
      MoveLensCenter center, String fromId, String toId) {
    final fromName =
        center.zones.firstWhere((z) => z.id == fromId, orElse: () {
      return MoveLensZone(id: fromId, name: fromId);
    }).name;
    final toName =
        center.zones.firstWhere((z) => z.id == toId, orElse: () {
      return MoveLensZone(id: toId, name: toId);
    }).name;
    return '$fromName→$toName';
  }

  // ── Mock 위치 생성기 ─────────────────────────────
  void _startMockPositioning(
      MoveLensCenter center, MoveLensSession session) {
    _mockStates.clear();

    final zones = center.zones;
    if (zones.isEmpty) return;

    // 태그별 초기 상태 설정
    final tags = center.tagMappings.isNotEmpty
        ? center.tagMappings.map((m) => m.tagId).toList()
        : ['TAG_W1', 'TAG_W2'];

    for (int i = 0; i < tags.length; i++) {
      final startZone = zones[i % zones.length];
      final startPos = _zoneCenterPosition(startZone);
      _mockStates[tags[i]] = _MockTagState(
        tagId: tags[i],
        x: startPos.dx,
        y: startPos.dy,
        currentZoneIdx: i % zones.length,
        targetZoneIdx: (i + 1) % zones.length,
        progress: 0.0,
        zones: zones,
      );
    }

    const interval = Duration(milliseconds: 200);
    _mockTimer = Timer.periodic(interval, (_) {
      _updateMockPositions(center, session);
    });
  }

  void _updateMockPositions(
      MoveLensCenter center, MoveLensSession session) {
    final positions = <TagPosition>[];

    for (final state in _mockStates.values) {
      state.progress += 0.02; // 이동 속도

      if (state.progress >= 1.0) {
        // 다음 Zone으로 이동
        state.progress = 0.0;
        state.currentZoneIdx = state.targetZoneIdx;
        // 랜덤하게 다음 Zone 선택
        final nextOptions = List.generate(state.zones.length, (i) => i)
          ..remove(state.currentZoneIdx);
        if (nextOptions.isNotEmpty) {
          state.targetZoneIdx =
              nextOptions[Random().nextInt(nextOptions.length)];
        }
      }

      final from = _zoneCenterPosition(state.zones[state.currentZoneIdx]);
      final to = _zoneCenterPosition(state.zones[state.targetZoneIdx]);
      final x = from.dx + (to.dx - from.dx) * state.progress;
      final y = from.dy + (to.dy - from.dy) * state.progress;

      // 약간의 노이즈 추가
      final noise = 0.01;
      final nx = x + (Random().nextDouble() - 0.5) * noise;
      final ny = y + (Random().nextDouble() - 0.5) * noise;

      state.x = nx.clamp(0.0, 1.0);
      state.y = ny.clamp(0.0, 1.0);

      final rawEvent = MoveLensRawEvent(
        tagId: state.tagId,
        timestamp: DateTime.now(),
        x: state.x,
        y: state.y,
      );

      // 세션이 너무 커지지 않도록 10초마다 1개만 저장 (200ms 중 50번에 1번)
      if (Random().nextInt(50) == 0) {
        session.rawEvents.add(rawEvent);
      }

      final currentZone = findZoneForPosition(center, state.x, state.y);
      positions.add(TagPosition(
        tagId: state.tagId,
        x: state.x,
        y: state.y,
        currentZoneId: currentZone?.id,
      ));
    }

    if (!_positionCtrl.isClosed) {
      _positionCtrl.add(positions);
    }
  }

  void _stopMockPositioning() {
    _mockTimer?.cancel();
    _mockTimer = null;
    _mockStates.clear();
  }

  Offset _zoneCenterPosition(MoveLensZone zone) {
    if (zone.shape == ZoneShape.circle) {
      return zone.center;
    } else if (zone.polygon.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final p in zone.polygon) {
        sumX += p.dx;
        sumY += p.dy;
      }
      return Offset(sumX / zone.polygon.length, sumY / zone.polygon.length);
    }
    return const Offset(0.5, 0.5);
  }

  void dispose() {
    _stopMockPositioning();
    _positionCtrl.close();
  }
}

class _MockTagState {
  final String tagId;
  double x, y;
  int currentZoneIdx;
  int targetZoneIdx;
  double progress;
  final List<MoveLensZone> zones;

  _MockTagState({
    required this.tagId,
    required this.x,
    required this.y,
    required this.currentZoneIdx,
    required this.targetZoneIdx,
    required this.progress,
    required this.zones,
  });
}
