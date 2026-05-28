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
  // 백그라운드에서는 Firebase가 이미 초기화된 상태
  // 별도 처리가 필요하면 여기에 추가
  debugPrint('[FCM Background] ${message.notification?.title}');
}

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;

  /// 앱 시작 시 호출: 권한 요청 → 토큰 저장 → 핸들러 등록
  static Future<void> init(String phone) async {
    // 1. 알림 권한 요청 (Android 13+ / iOS)
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

    // 4. 포그라운드 메시지 수신 (알림 표시는 OS가 처리하지 않으므로 직접 처리)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}');
      // 포그라운드에서는 이미 앱이 열려있어 Realtime으로 다이얼로그가 표시됨
      // 별도 snackbar/overlay가 필요하면 여기에 추가
    });

    // 5. 알림 탭으로 앱이 열릴 때 (백그라운드 → 포그라운드)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Opened] ${message.data}');
      // 필요 시 특정 화면으로 이동 로직 추가
    });

    // 6. 앱이 완전히 종료된 상태에서 알림 탭으로 시작
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM Initial] ${initial.data}');
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

  /// 위치 요청 시 상대방에게 푸시 알림 전송
  static Future<void> sendLocationRequestPush({
    required String responderPhone,
    required String requesterName,
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
          'data': {'type': 'location_request'},
        }),
      );
      debugPrint('[FCM] Push sent: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('[FCM] Push failed: $e');
    }
  }
}
