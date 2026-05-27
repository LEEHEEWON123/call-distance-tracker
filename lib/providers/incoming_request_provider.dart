import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_request.dart';
import '../services/location_request_service.dart';

/// 내 전화번호 (앱 전체에서 공유)
final myPhoneProvider = StateProvider<String?>((ref) => null);

/// 수신된 위치 요청 구독
final incomingRequestProvider =
    StreamProvider.autoDispose<LocationRequest?>((ref) {
  final myPhone = ref.watch(myPhoneProvider);
  if (myPhone == null || myPhone.isEmpty) return const Stream.empty();
  return LocationRequestService.watchIncomingRequests(myPhone);
});
