import '../models/robot_data.dart';

abstract class RobotService {
  /// 로봇 목록 실시간 스트림
  Stream<List<RobotData>> get stream;

  /// 특정 로봇에 정지 명령 전송
  void sendStop(String robotId);

  void dispose();
}
