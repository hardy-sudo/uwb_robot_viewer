import 'movelens_zone.dart';
import 'movelens_tag_mapping.dart';
import 'movelens_session.dart';

class MoveLensCenter {
  final String id;
  String name;        // 센터명
  String clientName;  // 고객사명
  String description;
  String mapImageUrl;
  List<MoveLensZone> zones;
  List<MoveLensTagMapping> tagMappings;
  OperatingSchedule schedule;
  List<FromToRule> fromToRules;
  List<MoveLensSession> sessions;

  MoveLensCenter({
    required this.id,
    required this.name,
    this.clientName = '',
    this.description = '',
    this.mapImageUrl = '',
    List<MoveLensZone>? zones,
    List<MoveLensTagMapping>? tagMappings,
    OperatingSchedule? schedule,
    List<FromToRule>? fromToRules,
    List<MoveLensSession>? sessions,
  })  : zones = zones ?? [],
        tagMappings = tagMappings ?? [],
        schedule = schedule ?? OperatingSchedule(),
        fromToRules = fromToRules ?? [],
        sessions = sessions ?? [];

  MoveLensSession? get activeSession => sessions.isEmpty
      ? null
      : sessions.lastOrNull?.status == SessionStatus.running
          ? sessions.last
          : null;

  MoveLensSession? get lastCompletedSession {
    for (int i = sessions.length - 1; i >= 0; i--) {
      if (sessions[i].status == SessionStatus.completed) return sessions[i];
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clientName': clientName,
        'description': description,
        'mapImageUrl': mapImageUrl,
        'zones': zones.map((z) => z.toJson()).toList(),
        'tagMappings': tagMappings.map((t) => t.toJson()).toList(),
        'schedule': schedule.toJson(),
        'fromToRules': fromToRules.map((r) => r.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory MoveLensCenter.fromJson(Map<String, dynamic> j) => MoveLensCenter(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        clientName: j['clientName'] as String? ?? '',
        description: j['description'] as String? ?? '',
        mapImageUrl: j['mapImageUrl'] as String? ?? '',
        zones: (j['zones'] as List<dynamic>?)
                ?.map((e) =>
                    MoveLensZone.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tagMappings: (j['tagMappings'] as List<dynamic>?)
                ?.map((e) =>
                    MoveLensTagMapping.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        schedule: j['schedule'] != null
            ? OperatingSchedule.fromJson(
                j['schedule'] as Map<String, dynamic>)
            : OperatingSchedule(),
        fromToRules: (j['fromToRules'] as List<dynamic>?)
                ?.map((e) =>
                    FromToRule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        sessions: (j['sessions'] as List<dynamic>?)
                ?.map((e) =>
                    MoveLensSession.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
