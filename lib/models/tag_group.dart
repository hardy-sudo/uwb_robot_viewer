enum TagGroupType { robot, human, forklift }

class TagGroup {
  final String id;
  String name;
  TagGroupType type;
  List<String> tagIds;

  // 로봇 그룹 전용 필드
  String? fmsIp;
  String? robotBrand;
  String? robotModel;
  String? baseUrl;
  String? robotListApiUrl;

  TagGroup({
    required this.id,
    required this.name,
    required this.type,
    List<String>? tagIds,
    this.fmsIp,
    this.robotBrand,
    this.robotModel,
    this.baseUrl,
    this.robotListApiUrl,
  }) : tagIds = tagIds ?? [];
}
