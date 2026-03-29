/// UWB 태그 간 거리 측정 이벤트.
/// UWB 플랫폼(또는 Mock)이 실시간으로 발행하는 단위 데이터.
class UwbDistanceEvent {
  const UwbDistanceEvent({
    required this.humanTagId,
    required this.robotTagId,
    required this.distanceM,
    required this.timestamp,
    this.anchorId,
  });

  /// 작업자 태그 ID (예: 'TAG_W1')
  final String humanTagId;

  /// 로봇 태그 ID (예: 'TAG_R1') → robotTagToIdMap 으로 robot_id 매핑
  final String robotTagId;

  /// 사람-로봇 간 거리 (단위: m)
  final double distanceM;

  final DateTime timestamp;

  /// 이 거리를 측정한 UWB Anchor ID (옵셔널). null이면 Anchor 정보 없음 (하위 호환).
  final String? anchorId;

  @override
  String toString() =>
      'UwbDistanceEvent($humanTagId↔$robotTagId '
      '${distanceM.toStringAsFixed(2)}m'
      '${anchorId != null ? ' via $anchorId' : ''}'
      ' @ $timestamp)';
}
