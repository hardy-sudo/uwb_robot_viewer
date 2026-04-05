import 'dart:convert';
import 'dart:ui' show Offset;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_config.dart';
import '../models/safety_zone.dart';
import '../utils/coordinate_converter.dart';

/// Map 이미지와 Safety Zone을 in-memory로 관리하는 서비스
class MapZoneService {
  static final instance = MapZoneService._();
  MapZoneService._();

  static const _keyMapConfig = 'hammer_map_config';
  static const _keyZones = 'hammer_safety_zones';

  MapConfig? mapConfig;
  final List<SafetyZone> zones = [];

  void setMapConfig(MapConfig config) {
    mapConfig = config;
    save().ignore();
  }

  void addZone(SafetyZone zone) {
    zones.add(zone);
    save().ignore();
  }

  void updateZone(SafetyZone zone) {
    final idx = zones.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) zones[idx] = zone;
    save().ignore();
  }

  void removeZone(String zoneId) {
    zones.removeWhere((z) => z.id == zoneId);
    save().ignore();
  }

  SafetyZone? getZoneById(String id) {
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  /// anchorId가 속한 Zone 반환. 여러 Zone에 동일 Anchor가 등록된 경우 첫 번째 반환.
  SafetyZone? getZoneByAnchorId(String anchorId) {
    for (final z in zones) {
      if (z.anchorIds.contains(anchorId)) return z;
    }
    return null;
  }

  /// normalizedPosition (0.0~1.0 맵 캔버스 비율)이 포함된 Zone 반환.
  /// safetyEnabled=false인 Zone은 건너뜀.
  SafetyZone? getZoneForPosition(Offset normalizedPosition) {
    for (final z in zones) {
      if (!z.safetyEnabled) continue;
      if (CoordinateConverter.isPointInPolygon(normalizedPosition, z.polygon)) {
        return z;
      }
    }
    return null;
  }

  // ── 퍼시스턴스 ────────────────────────────────────────────────────────────

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (mapConfig != null) {
      await prefs.setString(_keyMapConfig, jsonEncode(mapConfig!.toJson()));
    } else {
      await prefs.remove(_keyMapConfig);
    }
    await prefs.setString(
        _keyZones, jsonEncode(zones.map((z) => z.toJson()).toList()));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final mapStr = prefs.getString(_keyMapConfig);
    if (mapStr != null) {
      mapConfig =
          MapConfig.fromJson(jsonDecode(mapStr) as Map<String, dynamic>);
    }

    final zonesStr = prefs.getString(_keyZones);
    if (zonesStr != null) {
      final list = jsonDecode(zonesStr) as List<dynamic>;
      zones
        ..clear()
        ..addAll(list
            .map((e) => SafetyZone.fromJson(e as Map<String, dynamic>)));
    }
  }
}
