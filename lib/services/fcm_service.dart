import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/my_phone_store.dart';
import '../core/supabase_client.dart';

/// FCM 백그라운드 핸들러 — top-level 함수여야 함
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}');
}

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;

  /// main.dart에서 주입
  static GlobalKey<NavigatorState>? navigatorKey;

  /// 앱 시작 시 호출: 권한 요청 → 토큰 저장 → 핸들러 등록
  static Future<void> init(String phone) async {
    // 1. 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 2. FCM 토큰 취득 및 Supabase 저장
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(phone, token);
    }

    // 3. 토큰 갱신 시 재저장
    _messaging.onTokenRefresh.listen((newToken) async {
      final currentPhone = await MyPhoneStore.get();
      if (currentPhone != null && currentPhone.isNotEmpty) {
        await _saveToken(currentPhone, newToken);
      }
    });

    // 4. 포그라운드 메시지 — Realtime으로 다이얼로그가 이미 처리됨
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}');
    });

    // 5. 백그라운드 상태에서 알림 탭 → 앱 포그라운드로 전환
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToConsent(message);
    });

    // 6. 앱 완전 종료 상태에서 알림 탭 → 앱 시작
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // 앱이 완전히 뜬 후 이동해야 하므로 짧은 딜레이
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToConsent(initial);
      });
    }
  }

  /// 알림 데이터에서 token 추출 후 consent 화면으로 이동
  static void _navigateToConsent(RemoteMessage message) {
    final requestToken = message.data['request_token'] as String?;
    if (requestToken != null && requestToken.isNotEmpty) {
      debugPrint('[FCM] Navigate to consent: $requestToken');
      navigatorKey?.currentState?.pushNamed('/consent', arguments: requestToken);
    }
  }

  /// phone + fcm_token을 device_tokens에 upsert
  static Future<void> _saveToken(String phone, String token) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-]'), '');
    try {
      await supabase.from('device_tokens').upsert(
        {
          'phone': normalized,
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'phone',
      );
      debugPrint('[FCM] Token saved for $normalized');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// 위치 요청 시 상대방에게 푸시 알림 전송 (request_token 포함)
  static Future<void> sendLocationRequestPush({
    required String responderPhone,
    required String requesterName,
    required String requestToken,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(AppConstants.sendPushUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        },
        body: jsonEncode({
          'responder_phone': responderPhone,
          'title': '위치 요청',
          'body': '$requesterName님이 위치를 요청했습니다.',
          'data': {
            'type': 'location_request',
            'request_token': requestToken,
          },
        }),
      );
      debugPrint('[FCM] Push sent: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('[FCM] Push failed: $e');
    }
  }
}
