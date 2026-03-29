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
}

class TagData {
  final String id;
  TagCategory group;

  TagData({required this.id, this.group = TagCategory.unassigned});
}

class RobotMappingEntry {
  final String robotId;
  String tagId;

  RobotMappingEntry({required this.robotId, this.tagId = ''});
}

class SetupConfig {
  String centerName;
  String locationName;
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

  /// 전체 필드를 복사한 새 인스턴스 반환 (저장 시 참조 분리용)
  SetupConfig copy() => SetupConfig(
        centerName: centerName,
        locationName: locationName,
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
