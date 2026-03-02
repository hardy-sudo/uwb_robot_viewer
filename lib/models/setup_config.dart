enum TagGroup { unassigned, human, robot }

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
  TagGroup group;

  TagData({required this.id, this.group = TagGroup.unassigned});
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
  final List<AnchorData> anchors;
  final List<TagData> tags;
  final List<RobotMappingEntry> robotMappings;

  SetupConfig({
    this.centerName = '',
    this.locationName = '',
    this.panId = '',
    this.fmsBaseUrl = 'http://192.168.1.100:7000',
    this.areaId = 1,
    List<AnchorData>? anchors,
    List<TagData>? tags,
    List<RobotMappingEntry>? robotMappings,
  })  : anchors = anchors ?? [],
        tags = tags ?? [],
        robotMappings = robotMappings ?? [];
}
