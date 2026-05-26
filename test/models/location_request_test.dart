import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/models/location_request.dart';

void main() {
  test('LocationRequest.fromJson parses correctly', () {
    final json = {
      'id': 'abc-123',
      'token': 'token-xyz',
      'requester_id': 'device-1',
      'requester_lat': 37.5665,
      'requester_lng': 126.9780,
      'responder_lat': 37.5700,
      'responder_lng': 126.9820,
      'status': 'completed',
      'created_at': '2026-05-26T00:00:00Z',
      'expires_at': '2099-05-26T00:10:00Z',
    };
    final req = LocationRequest.fromJson(json);
    expect(req.token, 'token-xyz');
    expect(req.status, LocationRequestStatus.completed);
    expect(req.responderLat, 37.5700);
    expect(req.isExpired, isFalse);
  });

  test('LocationRequest.fromJson handles null responder coords', () {
    final json = {
      'id': 'abc-123',
      'token': 'token-xyz',
      'requester_id': 'device-1',
      'requester_lat': 37.5665,
      'requester_lng': 126.9780,
      'responder_lat': null,
      'responder_lng': null,
      'status': 'pending',
      'created_at': '2026-05-26T00:00:00Z',
      'expires_at': '2099-05-26T00:10:00Z',
    };
    final req = LocationRequest.fromJson(json);
    expect(req.status, LocationRequestStatus.pending);
    expect(req.responderLat, isNull);
    expect(req.isExpired, isFalse);
  });
}
