import '../models/map_config.dart';
import '../models/safety_zone.dart';

/// Map 이미지와 Safety Zone을 in-memory로 관리하는 서비스
class MapZoneService {
  static final instance = MapZoneService._();
  MapZoneService._();

  MapConfig? mapConfig;
  final List<SafetyZone> zones = [];

  void addZone(SafetyZone zone) => zones.add(zone);

  void updateZone(SafetyZone zone) {
    final idx = zones.indexWhere((z) => z.id == zone.id);
    if (idx >= 0) zones[idx] = zone;
  }

  void removeZone(String zoneId) => zones.removeWhere((z) => z.id == zoneId);

  SafetyZone? getZoneById(String id) {
    for (final z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }
}
