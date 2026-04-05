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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'tagIds': tagIds,
        if (fmsIp != null) 'fmsIp': fmsIp,
        if (robotBrand != null) 'robotBrand': robotBrand,
        if (robotModel != null) 'robotModel': robotModel,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (robotListApiUrl != null) 'robotListApiUrl': robotListApiUrl,
      };

  factory TagGroup.fromJson(Map<String, dynamic> j) => TagGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        type: TagGroupType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => TagGroupType.human,
        ),
        tagIds: (j['tagIds'] as List<dynamic>?)?.cast<String>() ?? [],
        fmsIp: j['fmsIp'] as String?,
        robotBrand: j['robotBrand'] as String?,
        robotModel: j['robotModel'] as String?,
        baseUrl: j['baseUrl'] as String?,
        robotListApiUrl: j['robotListApiUrl'] as String?,
      );
}
