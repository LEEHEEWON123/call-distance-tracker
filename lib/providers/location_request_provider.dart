import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_request.dart';
import '../services/location_request_service.dart';

final activeTokenProvider = StateProvider<String?>((ref) => null);

/// 현재 위치 요청을 보낸 상대방 전화번호
final requestingPhoneProvider = StateProvider<String?>((ref) => null);

final locationResponseProvider = StreamProvider.autoDispose<LocationRequest>((ref) {
  final token = ref.watch(activeTokenProvider);
  if (token == null) return const Stream.empty();
  return LocationRequestService.watchRequest(token);
});
