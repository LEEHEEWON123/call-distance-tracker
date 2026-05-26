import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/phone_state_service.dart';

final phoneStateProvider = StreamProvider<CallStatus>((ref) {
  return PhoneStateService.callStatusStream;
});

final isOnCallProvider = Provider<bool>((ref) {
  final state = ref.watch(phoneStateProvider);
  return state.when(
    data: (status) =>
        status == CallStatus.calling || status == CallStatus.ringing,
    loading: () => false,
    error: (_, __) => false,
  );
});
