import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_request_provider.dart';
import '../models/location_request.dart';

class WaitingScreen extends ConsumerStatefulWidget {
  final String token;
  const WaitingScreen({super.key, required this.token});

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  Timer? _timeoutTimer;
  int _remainingSeconds = 600; // 10분

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _remainingSeconds--; });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요청이 만료되었습니다.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  String get _timeDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LocationRequest>>(
      locationResponseProvider,
      (_, next) {
        next.whenData((req) {
          if (req.status == LocationRequestStatus.completed) {
            Navigator.of(context).pushReplacementNamed('/map', arguments: req);
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 요청 중'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF007AFF),
                strokeWidth: 3,
              ),
              const SizedBox(height: 32),
              const Text(
                '상대방의 응답을 기다리는 중...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Text(
                '남은 시간: $_timeDisplay',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
