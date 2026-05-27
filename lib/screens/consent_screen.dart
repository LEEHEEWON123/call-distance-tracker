import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../services/location_request_service.dart';
import '../services/location_service.dart';

enum _PageState { loading, ready, submitting, done, error }

class ConsentScreen extends StatefulWidget {
  final String token;
  const ConsentScreen({super.key, required this.token});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  _PageState _state = _PageState.loading;
  String _errorMsg = '';
  double? _requesterLat;
  double? _requesterLng;
  double? _myLat;
  double? _myLng;
  double _distanceMeters = 0;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      final data =
          await LocationRequestService.getRequestByToken(widget.token);
      if (!mounted) return;

      if (data == null) {
        setState(() {
          _state = _PageState.error;
          _errorMsg = '요청을 찾을 수 없습니다.';
        });
        return;
      }

      if (data['status'] != 'pending') {
        setState(() {
          _state = _PageState.error;
          _errorMsg = '이미 완료된 요청입니다.';
        });
        return;
      }

      final expires = DateTime.parse(data['expires_at'] as String);
      if (expires.isBefore(DateTime.now())) {
        setState(() {
          _state = _PageState.error;
          _errorMsg = '링크가 만료됐습니다.';
        });
        return;
      }

      _requesterLat = (data['requester_lat'] as num).toDouble();
      _requesterLng = (data['requester_lng'] as num).toDouble();
      setState(() => _state = _PageState.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PageState.error;
        _errorMsg = '오류: $e';
      });
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _state = _PageState.submitting);
    try {
      final pos = await LocationService.getCurrentPosition();
      _myLat = pos.latitude;
      _myLng = pos.longitude;

      final res = await http.post(
        Uri.parse(
            '${AppConstants.submitLocationUrl}/${widget.token}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': _myLat, 'lng': _myLng}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _distanceMeters = LocationService.haversineDistance(
          _requesterLat!, _requesterLng!, _myLat!, _myLng!,
        );
        setState(() => _state = _PageState.done);
      } else {
        setState(() {
          _state = _PageState.error;
          _errorMsg = '전송 실패. 다시 시도해 주세요.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PageState.error;
        _errorMsg = '오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf4f7fb),
      body: SafeArea(
        child: switch (_state) {
          _PageState.loading => _buildLoading(),
          _PageState.ready || _PageState.submitting => _buildConsent(),
          _PageState.done => _buildMap(),
          _PageState.error => _buildError(),
        },
      ),
    );
  }

  // ── 로딩 ──────────────────────────────────────────────────
  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFe07830)),
    );
  }

  // ── 동의 화면 ───────────────────────────────────────────────
  Widget _buildConsent() {
    final loading = _state == _PageState.submitting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            const Text(
              '위치 공유 요청',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1c2333),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '상대방이 현재 위치 확인을 요청했습니다.\n아래 버튼을 눌러 위치를 공유해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF96a3b4),
                height: 1.65,
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: loading ? null : _shareLocation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  gradient: loading
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: loading ? const Color(0xFFdde3ed) : null,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: loading
                      ? null
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFFe07830).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '위치 공유 허용',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 지도 화면 ───────────────────────────────────────────────
  Widget _buildMap() {
    final myPos = LatLng(_myLat!, _myLng!);
    final theirPos = LatLng(_requesterLat!, _requesterLng!);
    final center = LatLng(
      (_myLat! + _requesterLat!) / 2,
      (_myLng! + _requesterLng!) / 2,
    );
    final distStr = LocationService.formatDistance(_distanceMeters);

    return Column(
      children: [
        // 상단 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    size: 20, color: Color(0xFF1c2333)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  '두 분의 위치',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1c2333),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // 지도
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.calltracker.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [myPos, theirPos],
                    color: const Color(0x99e07830),
                    strokeWidth: 2,
                    isDotted: true,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // 내 위치 (초록)
                  Marker(
                    point: myPos,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF5aaa85),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x665aaa85),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 요청자 위치 (주황)
                  Marker(
                    point: theirPos,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFe07830),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66e07830),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 하단 거리 카드
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LegendDot(
                      color: Color(0xFF5aaa85), label: '나'),
                  _LegendDot(
                      color: Color(0xFFe07830), label: '요청자'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFf4f7fb),
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
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFe07830),
                          ),
                        ),
                        const Text(
                          '직선 거리',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF96a3b4)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.straighten,
                        size: 28, color: Color(0xFF96a3b4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 에러 화면 ───────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1c2333),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                '닫기',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF96a3b4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF96a3b4),
          ),
        ),
      ],
    );
  }
}
