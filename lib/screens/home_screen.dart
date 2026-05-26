import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Distance Tracker'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnCall ? Icons.phone_in_talk : Icons.phone,
                size: 80,
                color: isOnCall ? const Color(0xFF007AFF) : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                isOnCall ? '통화 중' : '통화 대기 중',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isOnCall ? const Color(0xFF007AFF) : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOnCall
                    ? '아래 버튼을 눌러 상대방에게 위치 공유를 요청하세요.'
                    : '통화 중일 때 위치 요청 버튼이 활성화됩니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isOnCall
                    ? () => _requestLocation(context, ref)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on),
                    SizedBox(width: 8),
                    Text('위치 요청 보내기'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestLocation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final position = await LocationService.getCurrentPosition();
      final deviceId = await DeviceId.getOrCreate();

      final token = await LocationRequestService.createRequest(
        requesterId: deviceId,
        requesterLat: position.latitude,
        requesterLng: position.longitude,
      );

      ref.read(activeTokenProvider.notifier).state = token;

      final smsBody = LocationRequestService.buildSmsMessage(
        token,
        AppConstants.consentBaseUrl,
      );
      final uri = Uri(
        scheme: 'sms',
        path: '',
        queryParameters: {'body': smsBody},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }

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
