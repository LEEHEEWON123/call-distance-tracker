import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/location_request.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final LocationRequest locationRequest;

  const MapScreen({super.key, required this.locationRequest});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  late final LatLng _myPos;
  late final LatLng _theirPos;
  late final LatLng _center;
  late final double _distanceMeters;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _myPos = LatLng(
      widget.locationRequest.requesterLat,
      widget.locationRequest.requesterLng,
    );
    _theirPos = LatLng(
      widget.locationRequest.responderLat!,
      widget.locationRequest.responderLng!,
    );
    _center = LatLng(
      (widget.locationRequest.requesterLat + widget.locationRequest.responderLat!) / 2,
      (widget.locationRequest.requesterLng + widget.locationRequest.responderLng!) / 2,
    );
    _distanceMeters = LocationService.haversineDistance(
      widget.locationRequest.requesterLat,
      widget.locationRequest.requesterLng,
      widget.locationRequest.responderLat!,
      widget.locationRequest.responderLng!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildMap(),
          _buildRecenterButton(),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomSheet(distanceMeters: _distanceMeters),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            border: const Border(
              bottom: BorderSide(color: Color(0x1F000000), width: 0.5),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF), size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              '위치 확인',
              style: TextStyle(
                color: Color(0xFF1C1C1E),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '통화 중',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 17,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.calltracker.app',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: _myPos,
              radius: 80,
              color: const Color(0x14007AFF),
              borderColor: const Color(0xFF007AFF),
              borderStrokeWidth: 1,
              useRadiusInMeter: true,
            ),
          ],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [_myPos, _theirPos],
              color: const Color(0x99007AFF),
              strokeWidth: 2,
              isDotted: true,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // 내 위치 — 파란 원형
            Marker(
              point: _myPos,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66007AFF),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            // 상대방 — 네이버 스타일 빨간 말풍선 + 핀
            Marker(
              point: _theirPos,
              width: 80,
              height: 52,
              alignment: const Alignment(0, 1),
              child: _TheirMarker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecenterButton() {
    return Positioned(
      right: 16,
      bottom: 220,
      child: GestureDetector(
        onTap: () => _mapController.move(_center, 17),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.my_location, color: Color(0xFF007AFF), size: 22),
        ),
      ),
    );
  }
}

class _TheirMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 말풍선
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59FF3B30),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            '상대방',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
        // 삼각형 꼬리
        CustomPaint(
          size: const Size(10, 5),
          painter: _CalloutArrowPainter(),
        ),
        const SizedBox(height: 1),
        // 핀 원형
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59FF3B30),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalloutArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF3B30);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CalloutArrowPainter oldDelegate) => false;
}

class _BottomSheet extends StatelessWidget {
  final double distanceMeters;

  const _BottomSheet({required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final walkMin = LocationService.estimateWalkMinutes(distanceMeters);
    final driveMin = LocationService.estimateDriveMinutes(distanceMeters);
    final distStr = LocationService.formatDistance(distanceMeters);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 상대방 정보
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '상',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상대방',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '방금 위치 공유됨',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 거리 강조
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distStr,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const Text(
                      '직선 거리',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.straighten, size: 28, color: Color(0xFF8E8E93)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 도보 / 차량
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.directions_walk, value: '$walkMin분', label: '도보')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.directions_car, value: '$driveMin분', label: '차량')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1C1C1E)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
