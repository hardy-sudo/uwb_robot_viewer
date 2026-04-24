enum TagObjectType { worker, cart, forklift, towingCar }

extension TagObjectTypeLabel on TagObjectType {
  String get label {
    switch (this) {
      case TagObjectType.worker:
        return '작업자';
      case TagObjectType.cart:
        return '카트';
      case TagObjectType.forklift:
        return '지게차';
      case TagObjectType.towingCar:
        return '토잉카';
    }
  }
}

class MoveLensTagMapping {
  String tagId;       // UWB 태그 ID (e.g. TAG_W1)
  String anonymousId; // 익명 식별자 (e.g. 작업자 1)
  TagObjectType type;

  MoveLensTagMapping({
    required this.tagId,
    required this.anonymousId,
    this.type = TagObjectType.worker,
  });

  Map<String, dynamic> toJson() => {
        'tagId': tagId,
        'anonymousId': anonymousId,
        'type': type.name,
      };

  factory MoveLensTagMapping.fromJson(Map<String, dynamic> j) =>
      MoveLensTagMapping(
        tagId: j['tagId'] as String,
        anonymousId: j['anonymousId'] as String? ?? '',
        type: TagObjectType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => TagObjectType.worker,
        ),
      );
}
