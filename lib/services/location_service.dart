import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 현재 GPS 위치 반환. 권한 없으면 예외 throw.
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Haversine 공식으로 두 좌표 간 직선 거리(미터) 계산
  static double haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// 미터 → "450m" 또는 "1.5km" 형식 문자열
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  /// 도보 예상 시간 (분). 평균 속도 5km/h
  static int estimateWalkMinutes(double meters) {
    return (meters / 1000 / 5 * 60).round();
  }

  /// 차량 예상 시간 (분). 평균 속도 50km/h
  static int estimateDriveMinutes(double meters) {
    return (meters / 1000 / 50 * 60).round();
  }
}
