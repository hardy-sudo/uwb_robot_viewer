import 'dart:async';
import '../models/uwb_distance_event.dart';

/// Web/unsupported platform stub — RealUwbService는 웹에서 동작하지 않습니다.
class RealUwbService {
  static const robotTagToIdMap = <String, String>{};
  static List<String> get availablePorts => [];

  final String portName;
  final int baudRate;
  final String humanTagId;

  RealUwbService({
    required this.portName,
    this.baudRate = 115200,
    this.humanTagId = 'TAG_W1',
    Map<String, String> robotTagToIdMap = const {},
  });

  Stream<UwbDistanceEvent> get stream => const Stream.empty();

  void dispose() {}
}
