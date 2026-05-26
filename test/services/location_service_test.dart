import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/services/location_service.dart';

void main() {
  test('haversineDistance returns 0 for same coordinates', () {
    final dist = LocationService.haversineDistance(
      37.5665, 126.9780, 37.5665, 126.9780,
    );
    expect(dist, closeTo(0.0, 0.001));
  });

  test('haversineDistance Seoul to Busan is roughly 325km', () {
    // 서울: 37.5665, 126.9780 / 부산: 35.1796, 129.0756
    final dist = LocationService.haversineDistance(
      37.5665, 126.9780, 35.1796, 129.0756,
    );
    expect(dist, greaterThan(320000));
    expect(dist, lessThan(330000));
  });

  test('formatDistance shows meters under 1km', () {
    expect(LocationService.formatDistance(450), '450m');
  });

  test('formatDistance shows km over 1000m', () {
    expect(LocationService.formatDistance(1500), '1.5km');
  });

  test('estimateWalkMinutes for 1km is about 12 minutes', () {
    expect(LocationService.estimateWalkMinutes(1000), 12);
  });

  test('estimateDriveMinutes for 10km is about 12 minutes', () {
    expect(LocationService.estimateDriveMinutes(10000), 12);
  });
}
