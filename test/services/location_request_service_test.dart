import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/models/location_request.dart';
import 'package:call_distance_tracker/services/location_request_service.dart';

void main() {
  test('buildSmsMessage contains token URL', () {
    const token = 'test-token-abc';
    const baseUrl = 'https://example.supabase.co/functions/v1/consent';
    final msg = LocationRequestService.buildSmsMessage(token, baseUrl);
    expect(msg, contains('$baseUrl/$token'));
    expect(msg, contains('위치'));
  });
}
