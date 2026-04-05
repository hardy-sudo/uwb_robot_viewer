class TagGroupRelation {
  final String id;
  String groupAId; // 사람/지게차 그룹
  String groupBId; // 로봇 그룹
  double thresholdStopM;
  double thresholdResumeM;
  bool isActive;

  TagGroupRelation({
    required this.id,
    required this.groupAId,
    required this.groupBId,
    this.thresholdStopM = 3.0,
    this.thresholdResumeM = 3.1,
    this.isActive = true,
  }) : assert(thresholdStopM < thresholdResumeM,
            'thresholdStopM must be < thresholdResumeM');

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupAId': groupAId,
        'groupBId': groupBId,
        'thresholdStopM': thresholdStopM,
        'thresholdResumeM': thresholdResumeM,
        'isActive': isActive,
      };

  factory TagGroupRelation.fromJson(Map<String, dynamic> j) =>
      TagGroupRelation(
        id: j['id'] as String,
        groupAId: j['groupAId'] as String,
        groupBId: j['groupBId'] as String,
        thresholdStopM: (j['thresholdStopM'] as num?)?.toDouble() ?? 3.0,
        thresholdResumeM: (j['thresholdResumeM'] as num?)?.toDouble() ?? 3.1,
        isActive: j['isActive'] as bool? ?? true,
      );
}
