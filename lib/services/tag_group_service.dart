import '../models/tag_group.dart';
import '../models/tag_group_relation.dart';

class TagGroupService {
  static final instance = TagGroupService._();
  TagGroupService._();

  final List<TagGroup> _groups = [];
  final List<TagGroupRelation> _relations = [];

  List<TagGroup> get groups => List.unmodifiable(_groups);
  List<TagGroupRelation> get relations => List.unmodifiable(_relations);

  // ── 그룹 CRUD ──────────────────────────────────────────────────────────────

  void addGroup(TagGroup group) => _groups.add(group);

  void updateGroup(TagGroup group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) _groups[idx] = group;
  }

  void removeGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _relations.removeWhere(
        (r) => r.groupAId == groupId || r.groupBId == groupId);
  }

  TagGroup? getGroupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  TagGroup? getGroupByTagId(String tagId) {
    for (final g in _groups) {
      if (g.tagIds.contains(tagId)) return g;
    }
    return null;
  }

  // ── Relation CRUD ──────────────────────────────────────────────────────────

  void addRelation(TagGroupRelation relation) => _relations.add(relation);

  void updateRelation(TagGroupRelation relation) {
    final idx = _relations.indexWhere((r) => r.id == relation.id);
    if (idx >= 0) _relations[idx] = relation;
  }

  void removeRelation(String relationId) {
    _relations.removeWhere((r) => r.id == relationId);
  }

  /// 두 Tag ID 간 활성화된 Relation 반환 (없으면 null)
  /// UwbSafetyService가 호출
  TagGroupRelation? getActiveRelation(String tagIdA, String tagIdB) {
    final groupA = getGroupByTagId(tagIdA);
    final groupB = getGroupByTagId(tagIdB);
    if (groupA == null || groupB == null) return null;
    for (final r in _relations) {
      if (!r.isActive) continue;
      if ((r.groupAId == groupA.id && r.groupBId == groupB.id) ||
          (r.groupAId == groupB.id && r.groupBId == groupA.id)) {
        return r;
      }
    }
    return null;
  }
}
