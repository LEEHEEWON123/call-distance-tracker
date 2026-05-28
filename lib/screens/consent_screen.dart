import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/location_request.dart';
import '../services/location_request_service.dart';
import '../services/location_service.dart';
import 'map_screen.dart';

enum _PageState { loading, ready, submitting, error }

class ConsentScreen extends StatefulWidget {
  final String token;
  const ConsentScreen({super.key, required this.token});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  _PageState _state = _PageState.loading;
  String _errorMsg = '';
  Map<String, dynamic>? _requestData;

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

      _requestData = data;
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

      final res = await http.post(
        Uri.parse('${AppConstants.submitLocationUrl}/${widget.token}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': pos.latitude, 'lng': pos.longitude}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // MapScreen에 전달할 LocationRequest 구성
        final data = _requestData!;
        final locationRequest = LocationRequest(
          id: data['id'] as String,
          token: data['token'] as String,
          requesterId: data['requester_id'] as String,
          requesterLat: (data['requester_lat'] as num).toDouble(),
          requesterLng: (data['requester_lng'] as num).toDouble(),
          responderLat: pos.latitude,
          responderLng: pos.longitude,
          responderPhone: data['responder_phone'] as String?,
          status: LocationRequestStatus.completed,
          createdAt: DateTime.parse(data['created_at'] as String),
          expiresAt: DateTime.parse(data['expires_at'] as String),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MapScreen(locationRequest: locationRequest),
          ),
        );
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

