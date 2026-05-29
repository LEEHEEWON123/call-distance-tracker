import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/device_id.dart';
import '../core/my_phone_store.dart';
import '../core/supabase_client.dart';
import '../providers/incoming_request_provider.dart';
import '../services/fcm_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. 익명 세션 생성
    final session = supabase.auth.currentSession;
    if (session == null) {
      await supabase.auth.signInAnonymously();
    }

    // 2. 디바이스 ID 초기화
    await DeviceId.getOrCreate();

    // 3. 권한 요청
    await Permission.phone.request();
    await Permission.contacts.request();
    await Permission.location.request();

    if (!mounted) return;

    // 4. 내 전화번호 확인 — 없으면 입력 요청
    final savedPhone = await MyPhoneStore.get();
    if (savedPhone != null && savedPhone.isNotEmpty) {
      ref.read(myPhoneProvider.notifier).state = savedPhone;
      await FcmService.init(savedPhone);
      _goHome();
    } else {
      _showPhoneInput();
    }
  }

  void _goHome() {
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  void _showPhoneInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 앱 아이콘
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 16),

              // 안내 문구
              Text(
                '상대방과 정확한 위치 계산을 위해\n전화번호를 등록해주세요.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jua(
                  fontSize: 15,
                  color: const Color(0xFF5a6475),
                ),
              ),
              const SizedBox(height: 20),

              // 전화번호 입력
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                inputFormatters: [_PhoneNumberFormatter()],
                style: GoogleFonts.jua(
                  fontSize: 16,
                  color: const Color(0xFF3a4455),
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: '010-0000-0000',
                  hintStyle: GoogleFonts.jua(
                    color: const Color(0xFFc0cad8),
                    letterSpacing: 1,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _PhoneIcon(),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFf8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFe8ecf2), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFe8ecf2), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF89cfe8), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFe07830).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final phone = controller.text.trim();
                      if (phone.isEmpty) return;
                      await MyPhoneStore.set(phone);
                      final normalized = phone.replaceAll(RegExp(r'[\s\-]'), '');
                      ref.read(myPhoneProvider.notifier).state = normalized;
                      await FcmService.init(normalized);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _goHome();
                    },
                    child: Text(
                      '확인',
                      style: GoogleFonts.jua(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Text(
                '번호는 기기에만 저장되며 외부로 공유되지 않아요.',
                style: GoogleFonts.jua(
                  fontSize: 11,
                  color: const Color(0xFFb0bac8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf4f7fb),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _CharactersRow(),
            const SizedBox(height: 28),
            // NearMates 타이틀
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Near',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6ab8d4),
                      letterSpacing: -1,
                    ),
                  ),
                  TextSpan(
                    text: 'Mates',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFe07830),
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '가까운 사람과 위치를 공유하세요',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF96a3b4),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const _LoadingDots(),
          ],
        ),
      ),
    );
  }
}

// ── 캐릭터 두 개 + 점선 ─────────────────────────────────────
class _CharactersRow extends StatelessWidget {
  const _CharactersRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _CharacterBall(color: Color(0xFF89cfe8), eyeColor: Color(0xFF2a6a90)),
        const SizedBox(width: 6),
        const _ConnectDots(),
        const SizedBox(width: 6),
        const _CharacterBall(color: Color(0xFFf5a878), eyeColor: Color(0xFF904020)),
      ],
    );
  }
}

class _CharacterBall extends StatelessWidget {
  final Color color;
  final Color eyeColor;

  const _CharacterBall({required this.color, required this.eyeColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: CustomPaint(painter: _BallPainter(color: color, eyeColor: eyeColor)),
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

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height - 6), width: r * 1.2, height: 10),
      Paint()..color = color.withValues(alpha: 0.3),
    );

    // 몸통
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);

    // 하이라이트
    final hlPaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.28), width: r * 0.55, height: r * 0.35),
      hlPaint,
    );

    // 볼터치
    final blushPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.52, cy + r * 0.18), width: 18, height: 11), blushPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.52, cy + r * 0.18), width: 18, height: 11), blushPaint);

    // 눈 흰자
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.30, cy - r * 0.08), 9, whitePaint);
    canvas.drawCircle(Offset(cx + r * 0.30, cy - r * 0.08), 9, whitePaint);

    // 눈 동자
    final pupilPaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(cx - r * 0.27, cy - r * 0.05), 5, pupilPaint);
    canvas.drawCircle(Offset(cx + r * 0.33, cy - r * 0.05), 5, pupilPaint);

    // 눈 반짝이
    final sparklePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.22, cy - r * 0.10), 2, sparklePaint);
    canvas.drawCircle(Offset(cx + r * 0.38, cy - r * 0.10), 2, sparklePaint);

    // 입 (스마일)
    final mouthPaint = Paint()
      ..color = eyeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(cx - r * 0.30, cy + r * 0.22);
    path.quadraticBezierTo(cx, cy + r * 0.42, cx + r * 0.30, cy + r * 0.22);
    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(_BallPainter old) => false;
}

// ── 연결 점선 (애니메이션) ────────────────────────────────────
class _ConnectDots extends StatefulWidget {
  const _ConnectDots();

  @override
  State<_ConnectDots> createState() => _ConnectDotsState();
}

class _ConnectDotsState extends State<_ConnectDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
          final scale = 0.6 + 0.6 * sin(t * pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFf5c060),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── 하단 로딩 점 3개 ──────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF6ab8d4), Color(0xFFf5c060), Color(0xFFe07830)];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - i * 0.18).clamp(0.0, 1.0);
          final scale = 0.5 + 0.7 * sin(t * pi);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── 전화번호 자동 포맷 (010-XXXX-XXXX) ───────────────────────
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    String formatted;
    if (limited.length <= 3) {
      formatted = limited;
    } else if (limited.length <= 7) {
      formatted = '${limited.substring(0, 3)}-${limited.substring(3)}';
    } else {
      formatted = '${limited.substring(0, 3)}-${limited.substring(3, 7)}-${limited.substring(7)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── 귀여운 폰 SVG 아이콘 ──────────────────────────────────────
class _PhoneIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(22, 22), painter: _PhoneIconPainter());
  }
}

class _PhoneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 0, size.width - 6, size.height),
      const Radius.circular(5),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF89cfe8));
    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 2.5, size.width - 10, size.height - 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(screen, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(
      Offset(size.width / 2, size.height - 2),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_PhoneIconPainter old) => false;
}
