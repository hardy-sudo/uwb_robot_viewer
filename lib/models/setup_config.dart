/// 개별 Tag의 단순 분류 (TagGroup 클래스와 구분하기 위해 TagCategory로 명명)
enum TagCategory { unassigned, human, robot }

class AnchorData {
  String id;
  double mapXRatio; // 0.0 ~ 1.0 relative to canvas
  double mapYRatio;
  bool placed;

  AnchorData({
    required this.id,
    this.mapXRatio = 0.5,
    this.mapYRatio = 0.5,
    this.placed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mapXRatio': mapXRatio,
        'mapYRatio': mapYRatio,
        'placed': placed,
      };

  factory AnchorData.fromJson(Map<String, dynamic> j) => AnchorData(
        id: j['id'] as String,
        mapXRatio: (j['mapXRatio'] as num).toDouble(),
        mapYRatio: (j['mapYRatio'] as num).toDouble(),
        placed: j['placed'] as bool? ?? false,
      );
}

class TagData {
  final String id;
  TagCategory group;

  TagData({required this.id, this.group = TagCategory.unassigned});

  Map<String, dynamic> toJson() => {'id': id, 'group': group.name};

  factory TagData.fromJson(Map<String, dynamic> j) => TagData(
        id: j['id'] as String,
        group: TagCategory.values.firstWhere(
          (e) => e.name == j['group'],
          orElse: () => TagCategory.unassigned,
        ),
      );
}

class RobotMappingEntry {
  final String robotId;
  String tagId;

  RobotMappingEntry({required this.robotId, this.tagId = ''});

  Map<String, dynamic> toJson() => {'robotId': robotId, 'tagId': tagId};

  factory RobotMappingEntry.fromJson(Map<String, dynamic> j) =>
      RobotMappingEntry(
        robotId: j['robotId'] as String,
        tagId: j['tagId'] as String? ?? '',
      );
}

class SetupConfig {
  String centerName;
  String locationName;
  String region;   // 지역 (선택)
  String floor;    // 층 (선택)
  String panId;
  String fmsBaseUrl;
  int areaId;

  // Safety Distance 설정 (TASK 1)
  double thresholdStopM;   // 정지 거리 (m), 기본 3.0
  double thresholdResumeM; // 재개 거리 (m), 기본 3.1
  int cooldownMs;          // Pause 난사 방지 (ms), 기본 1000

  final List<AnchorData> anchors;
  final List<TagData> tags;
  final List<RobotMappingEntry> robotMappings;

  SetupConfig({
    this.centerName = '',
    this.locationName = '',
    this.region = '',
    this.floor = '',
    this.panId = '',
    this.fmsBaseUrl = 'http://10.0.4.94:8080',
    this.areaId = 1,
    this.thresholdStopM = 3.0,
    this.thresholdResumeM = 3.1,
    this.cooldownMs = 1000,
    List<AnchorData>? anchors,
    List<TagData>? tags,
    List<RobotMappingEntry>? robotMappings,
  })  : anchors = anchors ?? [],
        tags = tags ?? [],
        robotMappings = robotMappings ?? [];

  Map<String, dynamic> toJson() => {
        'centerName': centerName,
        'locationName': locationName,
        'region': region,
        'floor': floor,
        'panId': panId,
        'fmsBaseUrl': fmsBaseUrl,
        'areaId': areaId,
        'thresholdStopM': thresholdStopM,
        'thresholdResumeM': thresholdResumeM,
        'cooldownMs': cooldownMs,
        'anchors': anchors.map((a) => a.toJson()).toList(),
        'tags': tags.map((t) => t.toJson()).toList(),
        'robotMappings': robotMappings.map((m) => m.toJson()).toList(),
      };

  factory SetupConfig.fromJson(Map<String, dynamic> j) => SetupConfig(
        centerName: j['centerName'] as String? ?? '',
        locationName: j['locationName'] as String? ?? '',
        region: j['region'] as String? ?? '',
        floor: j['floor'] as String? ?? '',
        panId: j['panId'] as String? ?? '',
        fmsBaseUrl: j['fmsBaseUrl'] as String? ?? 'http://10.0.4.94:8080',
        areaId: j['areaId'] as int? ?? 1,
        thresholdStopM: (j['thresholdStopM'] as num?)?.toDouble() ?? 3.0,
        thresholdResumeM: (j['thresholdResumeM'] as num?)?.toDouble() ?? 3.1,
        cooldownMs: j['cooldownMs'] as int? ?? 1000,
        anchors: (j['anchors'] as List<dynamic>?)
            ?.map((e) => AnchorData.fromJson(e as Map<String, dynamic>))
            .toList(),
        tags: (j['tags'] as List<dynamic>?)
            ?.map((e) => TagData.fromJson(e as Map<String, dynamic>))
            .toList(),
        robotMappings: (j['robotMappings'] as List<dynamic>?)
            ?.map((e) => RobotMappingEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 전체 필드를 복사한 새 인스턴스 반환 (저장 시 참조 분리용)
  SetupConfig copy() => SetupConfig(
        centerName: centerName,
        locationName: locationName,
        region: region,
        floor: floor,
        panId: panId,
        fmsBaseUrl: fmsBaseUrl,
        areaId: areaId,
        thresholdStopM: thresholdStopM,
        thresholdResumeM: thresholdResumeM,
        cooldownMs: cooldownMs,
        anchors: anchors.map((a) => AnchorData(
              id: a.id,
              mapXRatio: a.mapXRatio,
              mapYRatio: a.mapYRatio,
              placed: a.placed,
            )).toList(),
        tags: tags.map((t) => TagData(id: t.id, group: t.group)).toList(),
        robotMappings: robotMappings
            .map((m) => RobotMappingEntry(robotId: m.robotId, tagId: m.tagId))
            .toList(),
      );
}
