import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _ConsentScreenState extends State<ConsentScreen>
    with SingleTickerProviderStateMixin {
  _PageState _state = _PageState.loading;
  String _errorMsg = '';
  Map<String, dynamic>? _requestData;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _loadRequest();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final data = await LocationRequestService.getRequestByToken(widget.token);
      if (!mounted) return;

      if (data == null) {
        setState(() { _state = _PageState.error; _errorMsg = '요청을 찾을 수 없습니다.'; });
        return;
      }
      if (data['status'] != 'pending') {
        setState(() { _state = _PageState.error; _errorMsg = '이미 완료된 요청입니다.'; });
        return;
      }
      final expires = DateTime.parse(data['expires_at'] as String);
      if (expires.isBefore(DateTime.now())) {
        setState(() { _state = _PageState.error; _errorMsg = '링크가 만료됐습니다.'; });
        return;
      }
      _requestData = data;
      setState(() => _state = _PageState.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() { _state = _PageState.error; _errorMsg = '오류: $e'; });
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
          MaterialPageRoute(builder: (_) => MapScreen(locationRequest: locationRequest)),
        );
      } else {
        setState(() { _state = _PageState.error; _errorMsg = '전송 실패. 다시 시도해 주세요.'; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _state = _PageState.error; _errorMsg = '오류: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf4f7fb),
      body: switch (_state) {
        _PageState.loading => const Center(
            child: CircularProgressIndicator(color: Color(0xFFe07830)),
          ),
        _PageState.ready || _PageState.submitting => _buildConsent(),
        _PageState.error => _buildError(),
      },
    );
  }

  Widget _buildConsent() {
    final loading = _state == _PageState.submitting;
    return Stack(
      children: [
        // 배경 블롭
        Positioned(
          top: 60, left: -80,
          child: _Blob(size: 300, color: const Color(0xFF89cfe8), opacity: 0.10),
        ),
        Positioned(
          bottom: 100, right: -60,
          child: _Blob(size: 250, color: const Color(0xFFf5a878), opacity: 0.08),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 떠다니는 캐릭터
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _CharBall(size: 110),
                      // 위치 핀 뱃지
                      Positioned(
                        top: -4, right: -4,
                        child: _PinBadge(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 요청자 카드
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF93b5e1), Color(0xFF7098c8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text('📍',
                            style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '위치 요청',
                            style: TextStyle(fontSize: 11, color: Color(0xFF96a3b4), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '누군가 위치를 요청했어요',
                            style: GoogleFonts.jua(
                              fontSize: 15,
                              color: const Color(0xFF1c1c1e),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 메인 텍스트
                Text(
                  '위치를 공유할까요?',
                  style: GoogleFonts.jua(
                    fontSize: 22,
                    color: const Color(0xFF1c2333),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '허용하면 현재 위치가 상대방에게\n한 번만 공유돼요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF96a3b4),
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 36),

                // 허용 버튼
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: loading ? null : _shareLocation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: loading ? null : const LinearGradient(
                          colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        color: loading ? const Color(0xFFdde3ed) : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: loading ? null : [
                          BoxShadow(
                            color: const Color(0xFFe07830).withValues(alpha: 0.38),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: loading
                          ? const Center(
                              child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '위치 공유 허용',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 거절 버튼
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text(
                    '나중에 할게요',
                    style: TextStyle(fontSize: 14, color: Color(0xFFb0bac8)),
                  ),
                ),
                const SizedBox(height: 32),

                // 만료 안내
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 13, color: Color(0xFFc0cad8)),
                    const SizedBox(width: 4),
                    Text(
                      '요청은 10분 후 만료돼요',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
              style: const TextStyle(fontSize: 16, color: Color(0xFF1c2333), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text('닫기', style: TextStyle(fontSize: 14, color: Color(0xFF96a3b4))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 배경 블롭 ─────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Blob({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

// ── 파란 캐릭터 공 ────────────────────────────────────────────
class _CharBall extends StatelessWidget {
  final double size;
  const _CharBall({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _BallPainter(
          color: const Color(0xFF89cfe8),
          eyeColor: const Color(0xFF2a6a90),
        ),
      ),
    );
  }
}

class _BallPainter extends CustomPainter {
  final Color color;
  final Color eyeColor;
  const _BallPainter({required this.color, required this.eyeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height - 6), width: r * 1.2, height: 10),
      Paint()..color = color.withValues(alpha: 0.2),
    );
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.28), width: r * 0.55, height: r * 0.35),
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.52, cy + r * 0.18), width: 18, height: 11),
        Paint()..color = Colors.white.withValues(alpha: 0.2));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.52, cy + r * 0.18), width: 18, height: 11),
        Paint()..color = Colors.white.withValues(alpha: 0.2));
    canvas.drawCircle(Offset(cx - r * 0.30, cy - r * 0.08), 9, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + r * 0.30, cy - r * 0.08), 9, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx - r * 0.27, cy - r * 0.05), 5, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx + r * 0.33, cy - r * 0.05), 5, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx - r * 0.22, cy - r * 0.10), 2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + r * 0.38, cy - r * 0.10), 2, Paint()..color = Colors.white);
    final path = Path()
      ..moveTo(cx - r * 0.30, cy + r * 0.22)
      ..quadraticBezierTo(cx, cy + r * 0.42, cx + r * 0.30, cy + r * 0.22);
    canvas.drawPath(
      path,
      Paint()..color = eyeColor..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_BallPainter old) => false;
}

// ── 위치 핀 뱃지 ──────────────────────────────────────────────
class _PinBadge extends StatefulWidget {
  @override
  State<_PinBadge> createState() => _PinBadgeState();
}

class _PinBadgeState extends State<_PinBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFf5a060), Color(0xFFe07830)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFe07830).withValues(alpha: 0.4),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 16),
      ),
    );
  }
}
