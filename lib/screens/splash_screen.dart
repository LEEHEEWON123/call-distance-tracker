import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/device_id.dart';
import '../core/my_phone_store.dart';
import '../core/supabase_client.dart';
import '../providers/incoming_request_provider.dart';

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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '내 전화번호',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '위치 요청을 수신하려면\n내 전화번호를 입력해주세요.',
              style: TextStyle(fontSize: 13, color: Color(0xFF96a3b4)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '010-0000-0000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isEmpty) return;
              await MyPhoneStore.set(phone);
              ref.read(myPhoneProvider.notifier).state =
                  phone.replaceAll(RegExp(r'[\s\-]'), '');
              if (ctx.mounted) Navigator.of(ctx).pop();
              _goHome();
            },
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFFe07830),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFf4f7fb),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📍', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'NearMates',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1c2333),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFe07830)),
          ],
        ),
      ),
    );
  }
}
