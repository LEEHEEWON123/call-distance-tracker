import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../core/device_id.dart';
import '../providers/phone_state_provider.dart';
import '../providers/location_request_provider.dart';
import '../services/location_service.dart';
import '../services/location_request_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnCall = ref.watch(isOnCallProvider);

    return Container(
      color: const Color(0xFFf4f7fb),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 상태 배지
                _StatusBadge(isOnCall: isOnCall),
                const SizedBox(height: 16),

                // 타이틀
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: isOnCall
                        ? const Color(0xFF1c2333)
                        : const Color(0xFFb0bac8),
                  ),
                  child: Text(isOnCall ? '통화 중' : '위치 요청 대기'),
                ),
                const SizedBox(height: 10),

                // 설명
                Text(
                  isOnCall
                      ? '상대방에게 위치 공유를\n요청할 수 있어요.'
                      : '통화 중일 때 위치 요청\n버튼이 활성화됩니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF96a3b4),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 28),

                // 웨이브 도트 (통화중만)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isOnCall
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: _WaveDots(),
                        )
                      : const SizedBox(height: 20),
                ),

                // 버튼
                _RequestButton(
                  isOnCall: isOnCall,
                  onTap: () => _requestLocation(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestLocation(BuildContext context, WidgetRef ref) async {
    try {
      final position = await LocationService.getCurrentPosition();
      final deviceId = await DeviceId.getOrCreate();

      final token = await LocationRequestService.createRequest(
        requesterId: deviceId,
        requesterLat: position.latitude,
        requesterLng: position.longitude,
      );

      ref.read(activeTokenProvider.notifier).state = token;

      final shareText = LocationRequestService.buildShareMessage(token);
      await Share.share(shareText);

      if (context.mounted) {
        Navigator.of(context).pushNamed('/waiting', arguments: token);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }
}

// ── 상태 배지 ──────────────────────────────────────────────
class _StatusBadge extends StatefulWidget {
  final bool isOnCall;
  const _StatusBadge({required this.isOnCall});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isOnCall
        ? const Color(0xFFf5a060).withValues(alpha: 0.14)
        : const Color(0xFFe8edf3);
    final textColor = widget.isOnCall
        ? const Color(0xFFd07030)
        : const Color(0xFF96a3b4);
    final label = widget.isOnCall ? '통화 중' : '대기 중';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 깜빡이는 점 (통화중만)
          if (widget.isOnCall)
            FadeTransition(
              opacity: _blink,
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: textColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 웨이브 도트 ────────────────────────────────────────────
class _WaveDots extends StatefulWidget {
  const _WaveDots();

  @override
  State<_WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _dot(double delay) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
        final offset = -5.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Color(0xFFe07830),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_dot(0), _dot(0.17), _dot(0.33)],
    );
  }
}

// ── 위치 요청 버튼 ─────────────────────────────────────────
class _RequestButton extends StatelessWidget {
  final bool isOnCall;
  final VoidCallback onTap;

  const _RequestButton({required this.isOnCall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!isOnCall) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFe8edf3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Color(0xFFb0bac8), size: 18),
            SizedBox(width: 9),
            Text(
              '위치 요청 보내기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFb0bac8),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFf5a060), Color(0xFFe07830)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFe07830).withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.white, size: 18),
            SizedBox(width: 9),
            Text(
              '위치 요청 보내기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
