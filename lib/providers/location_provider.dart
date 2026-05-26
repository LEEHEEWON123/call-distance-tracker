import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

final currentPositionProvider = FutureProvider.autoDispose<Position>((ref) {
  return LocationService.getCurrentPosition();
});
