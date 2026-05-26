import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_request.dart';
import '../services/location_service.dart';

class MapScreen extends StatelessWidget {
  final LocationRequest locationRequest;

  const MapScreen({super.key, required this.locationRequest});

  @override
  Widget build(BuildContext context) {
    final myPos = LatLng(
      locationRequest.requesterLat,
      locationRequest.requesterLng,
    );
    final theirPos = LatLng(
      locationRequest.responderLat!,
      locationRequest.responderLng!,
    );

    final distanceMeters = LocationService.haversineDistance(
      locationRequest.requesterLat,
      locationRequest.requesterLng,
      locationRequest.responderLat!,
      locationRequest.responderLng!,
    );

    final centerLat =
        (locationRequest.requesterLat + locationRequest.responderLat!) / 2;
    final centerLng =
        (locationRequest.requesterLng + locationRequest.responderLng!) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 확인'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLng),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.calltracker.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: myPos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    Marker(
                      point: theirPos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [myPos, theirPos],
                      color: Colors.blue,
                      strokeWidth: 2,
                      isDotted: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _InfoPanel(distanceMeters: distanceMeters),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final double distanceMeters;

  const _InfoPanel({required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final walkMin = LocationService.estimateWalkMinutes(distanceMeters);
    final driveMin = LocationService.estimateDriveMinutes(distanceMeters);
    final distStr = LocationService.formatDistance(distanceMeters);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: '직선 거리', value: distStr, icon: Icons.straighten),
          _Stat(label: '도보', value: '$walkMin분', icon: Icons.directions_walk),
          _Stat(label: '차량', value: '$driveMin분', icon: Icons.directions_car),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF007AFF), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
