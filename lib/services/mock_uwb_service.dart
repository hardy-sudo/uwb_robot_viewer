import 'dart:async';
import 'dart:math';
import '../models/uwb_distance_event.dart';

/// UWB 거리 센싱 시뮬레이터.
///
/// 시나리오:
///   R1 ↔ W1 : 10s 주기로 5.0m ↔ 2.5m 왕복
///              → threshold_stop(3.0m) 돌파 시 Safety PAUSE 트리거
///              → threshold_resume(3.1m) 복귀 시 Safety RESUME 트리거
///   R2 ↔ W2 : 항상 안전 거리 5.5m 유지 (제어 없음)
///   R3      : UWB 이벤트 없음 (안전 시스템 미관여)
///
/// 이벤트 발행 주기: 200ms (= 5 Hz)
class MockUwbService {
  static const _tickMs = 200;

  /// robotTagId → robot_id 매핑 (UwbSafetyService 에 전달)
  static const robotTagToIdMap = <String, String>{
    'TAG_R1': 'R1',
    'TAG_R2': 'R2',
  };

  final _controller = StreamController<UwbDistanceEvent>.broadcast();
  late final Timer _timer;
  double _t = 0.0; // 경과 시간 (초)

  MockUwbService() {
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _tick());
  }

  void _tick() {
    _t += _tickMs / 1000.0;

    // ── R1 ↔ W1: 코사인 파형, 10s 주기 ───────────────────────────────────
    // d(t) = 3.75 + 1.25 * cos(2π * t / 10)
    //   t=0  → 5.0m (안전)
    //   t≈3.8s → < 3.0m (위험, PAUSE 트리거)
    //   t≈6.5s → > 3.1m (안전, RESUME 트리거)
    //   t=10s → 5.0m (안전, 사이클 반복)
    final d1 = 3.75 + 1.25 * cos(2 * pi * _t / 10.0);
    _controller.add(UwbDistanceEvent(
      humanTagId: 'TAG_W1',
      robotTagId: 'TAG_R1',
      distanceM: d1,
      timestamp: DateTime.now(),
    ));

    // ── R2 ↔ W2: 항상 안전 거리 ──────────────────────────────────────────
    _controller.add(UwbDistanceEvent(
      humanTagId: 'TAG_W2',
      robotTagId: 'TAG_R2',
      distanceM: 5.5,
      timestamp: DateTime.now(),
    ));
  }

  Stream<UwbDistanceEvent> get stream => _controller.stream;

  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
