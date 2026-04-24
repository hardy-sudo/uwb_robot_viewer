
// ────────────────────────────────────────────────────
// 운영 일정 설정
// ────────────────────────────────────────────────────

class TimeRange {
  final int startHour, startMinute, endHour, endMinute;
  const TimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get label =>
      '${_pad(startHour)}:${_pad(startMinute)} ~ ${_pad(endHour)}:${_pad(endMinute)}';
  String _pad(int v) => v.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'sh': startHour,
        'sm': startMinute,
        'eh': endHour,
        'em': endMinute,
      };
  factory TimeRange.fromJson(Map<String, dynamic> j) => TimeRange(
        startHour: j['sh'] as int,
        startMinute: j['sm'] as int,
        endHour: j['eh'] as int,
        endMinute: j['em'] as int,
      );
}

class OperatingSchedule {
  int operatingStartHour;
  int operatingStartMinute;
  int operatingEndHour;
  int operatingEndMinute;
  List<TimeRange> excludedRanges; // 점심시간 등

  OperatingSchedule({
    this.operatingStartHour = 9,
    this.operatingStartMinute = 0,
    this.operatingEndHour = 18,
    this.operatingEndMinute = 0,
    List<TimeRange>? excludedRanges,
  }) : excludedRanges = excludedRanges ?? [];

  String get startLabel =>
      '${_pad(operatingStartHour)}:${_pad(operatingStartMinute)}';
  String get endLabel =>
      '${_pad(operatingEndHour)}:${_pad(operatingEndMinute)}';
  String _pad(int v) => v.toString().padLeft(2, '0');

  /// 총 운영 시간(분)
  int get totalOperatingMinutes {
    int total = (operatingEndHour * 60 + operatingEndMinute) -
        (operatingStartHour * 60 + operatingStartMinute);
    for (final r in excludedRanges) {
      final excluded = (r.endHour * 60 + r.endMinute) -
          (r.startHour * 60 + r.startMinute);
      total -= excluded;
    }
    return total.clamp(0, 24 * 60);
  }

  Map<String, dynamic> toJson() => {
        'osh': operatingStartHour,
        'osm': operatingStartMinute,
        'oeh': operatingEndHour,
        'oem': operatingEndMinute,
        'excluded': excludedRanges.map((r) => r.toJson()).toList(),
      };

  factory OperatingSchedule.fromJson(Map<String, dynamic> j) =>
      OperatingSchedule(
        operatingStartHour: j['osh'] as int? ?? 9,
        operatingStartMinute: j['osm'] as int? ?? 0,
        operatingEndHour: j['oeh'] as int? ?? 18,
        operatingEndMinute: j['oem'] as int? ?? 0,
        excludedRanges: (j['excluded'] as List<dynamic>?)
                ?.map((e) => TimeRange.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ────────────────────────────────────────────────────
// From-To 분석 규칙
// ────────────────────────────────────────────────────

class FromToRule {
  String fromZoneId;
  String toZoneId;
  bool bidirectional;

  FromToRule({
    required this.fromZoneId,
    required this.toZoneId,
    this.bidirectional = false,
  });

  Map<String, dynamic> toJson() => {
        'from': fromZoneId,
        'to': toZoneId,
        'bi': bidirectional,
      };

  factory FromToRule.fromJson(Map<String, dynamic> j) => FromToRule(
        fromZoneId: j['from'] as String,
        toZoneId: j['to'] as String,
        bidirectional: j['bi'] as bool? ?? false,
      );
}

// ────────────────────────────────────────────────────
// 원시 위치 이벤트 (수집용)
// ────────────────────────────────────────────────────

class MoveLensRawEvent {
  final String tagId;
  final DateTime timestamp;
  final double x; // 0.0~1.0 정규화
  final double y; // 0.0~1.0 정규화

  const MoveLensRawEvent({
    required this.tagId,
    required this.timestamp,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'tag': tagId,
        'ts': timestamp.millisecondsSinceEpoch,
        'x': x,
        'y': y,
      };

  factory MoveLensRawEvent.fromJson(Map<String, dynamic> j) =>
      MoveLensRawEvent(
        tagId: j['tag'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
      );
}

// ────────────────────────────────────────────────────
// 이동 트립 이벤트 (분석 결과)
// ────────────────────────────────────────────────────

class MoveLensTripEvent {
  final String tagId;
  final String fromZoneId;
  final String toZoneId;
  final DateTime departureTime;
  final DateTime arrivalTime;

  const MoveLensTripEvent({
    required this.tagId,
    required this.fromZoneId,
    required this.toZoneId,
    required this.departureTime,
    required this.arrivalTime,
  });

  Duration get duration => arrivalTime.difference(departureTime);

  String get routeKey => '$fromZoneId→$toZoneId';

  Map<String, dynamic> toJson() => {
        'tag': tagId,
        'from': fromZoneId,
        'to': toZoneId,
        'dep': departureTime.millisecondsSinceEpoch,
        'arr': arrivalTime.millisecondsSinceEpoch,
      };

  factory MoveLensTripEvent.fromJson(Map<String, dynamic> j) =>
      MoveLensTripEvent(
        tagId: j['tag'] as String,
        fromZoneId: j['from'] as String,
        toZoneId: j['to'] as String,
        departureTime:
            DateTime.fromMillisecondsSinceEpoch(j['dep'] as int),
        arrivalTime:
            DateTime.fromMillisecondsSinceEpoch(j['arr'] as int),
      );
}

// ────────────────────────────────────────────────────
// 측정 세션
// ────────────────────────────────────────────────────

enum SessionStatus { running, completed }

class MoveLensSession {
  final String id;
  final String centerId;
  final DateTime startTime;
  DateTime? endTime;
  SessionStatus status;
  List<MoveLensRawEvent> rawEvents;
  List<MoveLensTripEvent> tripEvents;

  MoveLensSession({
    required this.id,
    required this.centerId,
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.running,
    List<MoveLensRawEvent>? rawEvents,
    List<MoveLensTripEvent>? tripEvents,
  })  : rawEvents = rawEvents ?? [],
        tripEvents = tripEvents ?? [];

  Duration get elapsed => (endTime ?? DateTime.now()).difference(startTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'centerId': centerId,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime?.millisecondsSinceEpoch,
        'status': status.name,
        'rawEvents': rawEvents.map((e) => e.toJson()).toList(),
        'tripEvents': tripEvents.map((e) => e.toJson()).toList(),
      };

  factory MoveLensSession.fromJson(Map<String, dynamic> j) => MoveLensSession(
        id: j['id'] as String,
        centerId: j['centerId'] as String,
        startTime:
            DateTime.fromMillisecondsSinceEpoch(j['startTime'] as int),
        endTime: j['endTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['endTime'] as int)
            : null,
        status: SessionStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => SessionStatus.completed,
        ),
        rawEvents: (j['rawEvents'] as List<dynamic>?)
                ?.map((e) =>
                    MoveLensRawEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tripEvents: (j['tripEvents'] as List<dynamic>?)
                ?.map((e) =>
                    MoveLensTripEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ────────────────────────────────────────────────────
// 분석 결과
// ────────────────────────────────────────────────────

class MoveLensAnalysis {
  final int totalTrips;
  final Duration totalMovementTime;
  final Duration totalIdleTime;
  final double movementRatio; // 이동 공수 비율 %
  final Map<String, int> tripCountByRoute; // "A→B": 건수
  final Map<String, Duration> avgDurationByRoute; // "A→B": 평균 시간
  final List<String> topRoutes; // 상위 자동화 후보 경로

  const MoveLensAnalysis({
    required this.totalTrips,
    required this.totalMovementTime,
    required this.totalIdleTime,
    required this.movementRatio,
    required this.tripCountByRoute,
    required this.avgDurationByRoute,
    required this.topRoutes,
  });
}

// ────────────────────────────────────────────────────
// 현재 태그 위치 (실시간 표시용)
// ────────────────────────────────────────────────────

class TagPosition {
  final String tagId;
  final double x;
  final double y;
  final String? currentZoneId;

  const TagPosition({
    required this.tagId,
    required this.x,
    required this.y,
    this.currentZoneId,
  });
}
