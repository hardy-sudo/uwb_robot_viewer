import '../models/robot_data.dart';

abstract class RobotService {
  /// 로봇 목록 실시간 스트림
  Stream<List<RobotData>> get stream;

  /// 특정 로봇에 정지 명령 전송 (Safety: controlWay=0, stopType=1)
  void sendStop(String robotId);

  /// 특정 로봇에 재가동 명령 전송 (Safety: controlWay=1)
  void sendResume(String robotId);

  void dispose();
}
