import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tag_group.dart';
import '../models/tag_group_relation.dart';

class TagGroupService {
  static final instance = TagGroupService._();
  TagGroupService._();

  static const _keyGroups = 'hammer_tag_groups';
  static const _keyRelations = 'hammer_tag_relations';

  final List<TagGroup> _groups = [];
  final List<TagGroupRelation> _relations = [];

  List<TagGroup> get groups => List.unmodifiable(_groups);
  List<TagGroupRelation> get relations => List.unmodifiable(_relations);

  // ── 그룹 CRUD ──────────────────────────────────────────────────────────────

  void addGroup(TagGroup group) {
    _groups.add(group);
    save().ignore();
  }

  void updateGroup(TagGroup group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx >= 0) _groups[idx] = group;
    save().ignore();
  }

  void removeGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _relations.removeWhere(
        (r) => r.groupAId == groupId || r.groupBId == groupId);
    save().ignore();
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

  void addRelation(TagGroupRelation relation) {
    _relations.add(relation);
    save().ignore();
  }

  void updateRelation(TagGroupRelation relation) {
    final idx = _relations.indexWhere((r) => r.id == relation.id);
    if (idx >= 0) _relations[idx] = relation;
    save().ignore();
  }

  void removeRelation(String relationId) {
    _relations.removeWhere((r) => r.id == relationId);
    save().ignore();
  }

  // ── 퍼시스턴스 ────────────────────────────────────────────────────────────

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyGroups, jsonEncode(_groups.map((g) => g.toJson()).toList()));
    await prefs.setString(
        _keyRelations, jsonEncode(_relations.map((r) => r.toJson()).toList()));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final groupsStr = prefs.getString(_keyGroups);
    if (groupsStr != null) {
      final list = jsonDecode(groupsStr) as List<dynamic>;
      _groups
        ..clear()
        ..addAll(list
            .map((e) => TagGroup.fromJson(e as Map<String, dynamic>)));
    }

    final relStr = prefs.getString(_keyRelations);
    if (relStr != null) {
      final list = jsonDecode(relStr) as List<dynamic>;
      _relations
        ..clear()
        ..addAll(list.map(
            (e) => TagGroupRelation.fromJson(e as Map<String, dynamic>)));
    }
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
