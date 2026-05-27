import 'package:uuid/uuid.dart';
import '../core/supabase_client.dart';
import '../models/location_request.dart';

class LocationRequestService {
  static const _table = 'location_requests';

  /// 위치 요청 레코드 생성. 생성된 토큰 반환.
  static Future<String> createRequest({
    required String requesterId,
    required double requesterLat,
    required double requesterLng,
  }) async {
    final token = const Uuid().v4();
    await supabase.from(_table).insert({
      'token': token,
      'requester_id': requesterId,
      'requester_lat': requesterLat,
      'requester_lng': requesterLng,
    });
    return token;
  }

  /// 특정 토큰의 레코드 변경을 실시간 수신
  static Stream<LocationRequest> watchRequest(String token) {
    return supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('token', token)
        .map((rows) {
          if (rows.isEmpty) throw Exception('요청을 찾을 수 없습니다.');
          return LocationRequest.fromJson(rows.first);
        })
        .where((req) => req.status == LocationRequestStatus.completed);
  }

  /// SMS 문자 본문 생성
  static String buildSmsMessage(String token, String baseUrl) {
    final expiry = DateTime.now().add(const Duration(minutes: 10));
    final h = expiry.hour.toString().padLeft(2, '0');
    final m = expiry.minute.toString().padLeft(2, '0');
    return '📍 위치 공유 요청이 도착했습니다.\n아래 링크를 눌러 위치를 공유해 주세요:\n$baseUrl/$token\n($h:$m 까지)';
  }
}
