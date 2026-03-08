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
}
