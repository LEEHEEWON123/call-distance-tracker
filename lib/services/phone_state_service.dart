import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

enum CallStatus { idle, calling, ringing }

class PhoneStateService {
  /// 통화 상태 Stream. READ_PHONE_STATE 권한 필요.
  static Stream<CallStatus> get callStatusStream {
    return PhoneState.stream.map((state) {
      switch (state.status) {
        case PhoneStateStatus.CALL_STARTED:
          return CallStatus.calling;
        case PhoneStateStatus.CALL_INCOMING:
          return CallStatus.ringing;
        case PhoneStateStatus.CALL_ENDED:
        case PhoneStateStatus.NOTHING:
          return CallStatus.idle;
      }
    });
  }

  /// READ_PHONE_STATE 권한 요청.
  /// phone_state 2.x는 requestPermissions()를 제공하지 않으므로
  /// permission_handler를 통해 직접 요청한다.
  static Future<bool> requestPermission() async {
    final status = await Permission.phone.request();
    return status == PermissionStatus.granted ||
        status == PermissionStatus.provisional;
  }
}
