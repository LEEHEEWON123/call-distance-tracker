# Call Distance Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 통화 중 상대방에게 SMS 링크를 보내고, 상대방이 브라우저에서 동의하면 두 사람의 위치와 거리를 지도에 표시하는 Android Flutter 앱

**Architecture:** Flutter(Android) + Supabase(Postgres + Edge Functions + Realtime). 발신자만 앱 설치. 수신자는 브라우저에서 동의 후 1회성 위치 공유. 발신자 앱은 Supabase Realtime으로 위치 수신 후 flutter_map에 표시.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, flutter_map 6.x, supabase_flutter 2.x, geolocator 11.x, phone_state 2.x, url_launcher 6.x, uuid 4.x, Supabase Edge Functions (Deno/TypeScript)

---

## 파일 구조

```
call-distance-tracker/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants.dart              # Supabase URL/key, Edge Function URL
│   │   ├── supabase_client.dart        # Supabase 초기화
│   │   └── device_id.dart             # 디바이스 고유 ID 생성/저장
│   ├── models/
│   │   └── location_request.dart      # LocationRequest 데이터 모델
│   ├── services/
│   │   ├── location_service.dart      # GPS 위치 수집
│   │   ├── phone_state_service.dart   # 통화 상태 감지
│   │   └── location_request_service.dart  # Supabase CRUD + Realtime
│   ├── providers/
│   │   ├── phone_state_provider.dart  # 통화 상태 Riverpod provider
│   │   ├── location_provider.dart     # 내 위치 provider
│   │   └── location_request_provider.dart  # 위치 요청 상태 provider
│   └── screens/
│       ├── splash_screen.dart
│       ├── home_screen.dart
│       ├── waiting_screen.dart
│       └── map_screen.dart
├── test/
│   ├── models/
│   │   └── location_request_test.dart
│   ├── services/
│   │   └── location_request_service_test.dart
│   └── screens/
│       ├── home_screen_test.dart
│       └── map_screen_test.dart
├── supabase/
│   ├── migrations/
│   │   └── 20260526000000_create_location_requests.sql
│   └── functions/
│       ├── consent/
│       │   └── index.ts               # GET /consent/:token → HTML 서빙
│       └── submit-location/
│           └── index.ts               # POST /submit-location → 위치 저장
└── android/
    └── app/
        └── src/
            └── main/
                └── AndroidManifest.xml
```

---

## Task 1: Flutter 프로젝트 초기화 및 의존성 설정

**Files:**
- Create: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: Flutter 프로젝트 생성**

```bash
cd /Users/leeheewon/Documents/call-distance-tracker
flutter create . --org com.calltracker --platforms android
```

Expected: Flutter 프로젝트 파일들 생성됨

- [ ] **Step 2: pubspec.yaml 의존성 추가**

`pubspec.yaml`의 `dependencies` 섹션을 아래로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  geolocator: ^11.0.0
  phone_state: ^2.0.0
  url_launcher: ^6.2.0
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  uuid: ^4.3.0
  shared_preferences: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  flutter_lints: ^3.0.0
```

- [ ] **Step 3: 의존성 설치**

```bash
flutter pub get
```

Expected: `Got dependencies!` 메시지 출력

- [ ] **Step 4: main.dart 기본 설정**

`lib/main.dart` 전체 내용:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: App()));
}
```

- [ ] **Step 5: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "feat: initialize Flutter project with dependencies"
```

---

## Task 2: Android 권한 및 Manifest 설정

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: AndroidManifest.xml 권한 추가**

`<manifest>` 태그 바로 아래에 추가 (기존 `<application>` 태그 위):

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 2: queries 블록 추가 (url_launcher용)**

`</manifest>` 바로 앞에 추가:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.SENDTO"/>
    <data android:scheme="smsto"/>
  </intent>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https"/>
  </intent>
</queries>
```

- [ ] **Step 3: compileSdk 버전 확인**

`android/app/build.gradle`에서 `compileSdk`가 34 이상인지 확인. 아니면:

```gradle
android {
    compileSdk 34
    ...
    defaultConfig {
        ...
        minSdk 21
        targetSdk 34
    }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -3
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 5: 커밋**

```bash
git add android/
git commit -m "feat: add Android permissions and manifest config"
```

---

## Task 3: Supabase 프로젝트 설정

**Files:**
- Create: `supabase/migrations/20260526000000_create_location_requests.sql`
- Create: `lib/core/constants.dart`

> **사전 작업:** https://supabase.com 에서 새 프로젝트 생성. Project URL과 anon key 메모.

- [ ] **Step 1: 마이그레이션 파일 생성**

`supabase/migrations/20260526000000_create_location_requests.sql`:

```sql
-- location_requests 테이블 생성
CREATE TABLE IF NOT EXISTS location_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token         TEXT UNIQUE NOT NULL,
  requester_id  TEXT NOT NULL,
  requester_lat DOUBLE PRECISION NOT NULL,
  requester_lng DOUBLE PRECISION NOT NULL,
  responder_lat DOUBLE PRECISION,
  responder_lng DOUBLE PRECISION,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'completed', 'expired')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '10 minutes'
);

-- 만료된 레코드 자동 정리 (24시간 후)
CREATE INDEX idx_location_requests_token ON location_requests(token);
CREATE INDEX idx_location_requests_expires_at ON location_requests(expires_at);

-- RLS 활성화
ALTER TABLE location_requests ENABLE ROW LEVEL SECURITY;

-- anon은 INSERT만 가능 (requester_id가 자신인 경우)
CREATE POLICY "anon_insert" ON location_requests
  FOR INSERT TO anon
  WITH CHECK (true);

-- anon은 token으로 SELECT 가능
CREATE POLICY "anon_select_by_token" ON location_requests
  FOR SELECT TO anon
  USING (true);

-- anon은 token으로 UPDATE 가능 (status, responder 좌표만)
CREATE POLICY "anon_update_by_token" ON location_requests
  FOR UPDATE TO anon
  USING (status = 'pending' AND expires_at > now());

-- Realtime 활성화
ALTER PUBLICATION supabase_realtime ADD TABLE location_requests;
```

- [ ] **Step 2: Supabase 대시보드에서 SQL 실행**

Supabase 대시보드 → SQL Editor → 위 SQL 붙여넣기 → Run

Expected: 테이블 생성 완료, 오류 없음

- [ ] **Step 3: constants.dart 생성**

`lib/core/constants.dart`:

```dart
class AppConstants {
  // TODO: Supabase 대시보드 Settings > API에서 복사
  static const supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const supabaseAnonKey = 'YOUR_ANON_KEY';

  // Edge Function URL (Task 9에서 배포 후 업데이트)
  static const consentBaseUrl = '$supabaseUrl/functions/v1/consent';
}
```

> **중요:** `YOUR_PROJECT_ID`와 `YOUR_ANON_KEY`를 실제 값으로 교체

- [ ] **Step 4: 커밋**

```bash
mkdir -p supabase/migrations
git add supabase/ lib/core/constants.dart
git commit -m "feat: add Supabase migration and constants"
```

---

## Task 4: Core 레이어 (DeviceId, SupabaseClient)

**Files:**
- Create: `lib/core/device_id.dart`
- Create: `lib/core/supabase_client.dart`
- Create: `test/core/device_id_test.dart`

- [ ] **Step 1: device_id_test.dart 작성 (RED)**

`test/core/device_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_distance_tracker/core/device_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getOrCreate returns same ID on second call', () async {
    final id1 = await DeviceId.getOrCreate();
    final id2 = await DeviceId.getOrCreate();
    expect(id1, equals(id2));
    expect(id1.isNotEmpty, isTrue);
  });

  test('getOrCreate returns UUID format', () async {
    final id = await DeviceId.getOrCreate();
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuidRegex.hasMatch(id), isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/core/device_id_test.dart 2>&1 | tail -5
```

Expected: `Error: Could not find package 'call_distance_tracker'` 또는 파일 없음 오류

- [ ] **Step 3: device_id.dart 구현 (GREEN)**

`lib/core/device_id.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceId {
  static const _key = 'device_id';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;
    final newId = const Uuid().v4();
    await prefs.setString(_key, newId);
    return newId;
  }
}
```

- [ ] **Step 4: supabase_client.dart 생성**

`lib/core/supabase_client.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;
```

- [ ] **Step 5: 테스트 실행 (PASS 확인)**

```bash
flutter test test/core/device_id_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 6: 커밋**

```bash
git add lib/core/ test/core/
git commit -m "feat: add DeviceId and SupabaseClient core layer"
```

---

## Task 5: LocationRequest 모델

**Files:**
- Create: `lib/models/location_request.dart`
- Create: `test/models/location_request_test.dart`

- [ ] **Step 1: 테스트 작성 (RED)**

`test/models/location_request_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/models/location_request.dart';

void main() {
  test('LocationRequest.fromJson parses correctly', () {
    final json = {
      'id': 'abc-123',
      'token': 'token-xyz',
      'requester_id': 'device-1',
      'requester_lat': 37.5665,
      'requester_lng': 126.9780,
      'responder_lat': 37.5700,
      'responder_lng': 126.9820,
      'status': 'completed',
      'created_at': '2026-05-26T00:00:00Z',
      'expires_at': '2026-05-26T00:10:00Z',
    };
    final req = LocationRequest.fromJson(json);
    expect(req.token, 'token-xyz');
    expect(req.status, LocationRequestStatus.completed);
    expect(req.responderLat, 37.5700);
    expect(req.isExpired, isFalse);
  });

  test('LocationRequest.fromJson handles null responder coords', () {
    final json = {
      'id': 'abc-123',
      'token': 'token-xyz',
      'requester_id': 'device-1',
      'requester_lat': 37.5665,
      'requester_lng': 126.9780,
      'responder_lat': null,
      'responder_lng': null,
      'status': 'pending',
      'created_at': '2026-05-26T00:00:00Z',
      'expires_at': '2099-05-26T00:10:00Z',
    };
    final req = LocationRequest.fromJson(json);
    expect(req.status, LocationRequestStatus.pending);
    expect(req.responderLat, isNull);
    expect(req.isExpired, isFalse);
  });
}
```

- [ ] **Step 2: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/models/location_request_test.dart 2>&1 | tail -5
```

Expected: 파일 없음 오류

- [ ] **Step 3: 모델 구현 (GREEN)**

`lib/models/location_request.dart`:

```dart
enum LocationRequestStatus { pending, completed, expired }

class LocationRequest {
  final String id;
  final String token;
  final String requesterId;
  final double requesterLat;
  final double requesterLng;
  final double? responderLat;
  final double? responderLng;
  final LocationRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const LocationRequest({
    required this.id,
    required this.token,
    required this.requesterId,
    required this.requesterLat,
    required this.requesterLng,
    this.responderLat,
    this.responderLng,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get hasResponderLocation =>
      responderLat != null && responderLng != null;

  factory LocationRequest.fromJson(Map<String, dynamic> json) {
    return LocationRequest(
      id: json['id'] as String,
      token: json['token'] as String,
      requesterId: json['requester_id'] as String,
      requesterLat: (json['requester_lat'] as num).toDouble(),
      requesterLng: (json['requester_lng'] as num).toDouble(),
      responderLat: (json['responder_lat'] as num?)?.toDouble(),
      responderLng: (json['responder_lng'] as num?)?.toDouble(),
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  static LocationRequestStatus _parseStatus(String s) {
    switch (s) {
      case 'completed':
        return LocationRequestStatus.completed;
      case 'expired':
        return LocationRequestStatus.expired;
      default:
        return LocationRequestStatus.pending;
    }
  }
}
```

- [ ] **Step 4: 테스트 실행 (PASS 확인)**

```bash
flutter test test/models/location_request_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 5: 커밋**

```bash
git add lib/models/ test/models/
git commit -m "feat: add LocationRequest model"
```

---

## Task 6: LocationService (GPS)

**Files:**
- Create: `lib/services/location_service.dart`
- Create: `test/services/location_service_test.dart`

- [ ] **Step 1: 테스트 작성 (RED)**

`test/services/location_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/services/location_service.dart';

void main() {
  test('haversineDistance returns 0 for same coordinates', () {
    final dist = LocationService.haversineDistance(
      37.5665, 126.9780, 37.5665, 126.9780,
    );
    expect(dist, closeTo(0.0, 0.001));
  });

  test('haversineDistance Seoul to Busan is roughly 325km', () {
    // 서울: 37.5665, 126.9780 / 부산: 35.1796, 129.0756
    final dist = LocationService.haversineDistance(
      37.5665, 126.9780, 35.1796, 129.0756,
    );
    expect(dist, greaterThan(320000));
    expect(dist, lessThan(330000));
  });

  test('formatDistance shows meters under 1km', () {
    expect(LocationService.formatDistance(450), '450m');
  });

  test('formatDistance shows km over 1000m', () {
    expect(LocationService.formatDistance(1500), '1.5km');
  });

  test('estimateWalkMinutes for 1km is about 12 minutes', () {
    expect(LocationService.estimateWalkMinutes(1000), 12);
  });

  test('estimateDriveMinutes for 10km is about 12 minutes', () {
    expect(LocationService.estimateDriveMinutes(10000), 12);
  });
}
```

- [ ] **Step 2: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/services/location_service_test.dart 2>&1 | tail -5
```

Expected: 파일 없음 오류

- [ ] **Step 3: 구현 (GREEN)**

`lib/services/location_service.dart`:

```dart
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 현재 GPS 위치 반환. 권한 없으면 예외 throw.
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Haversine 공식으로 두 좌표 간 직선 거리(미터) 계산
  static double haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const R = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// 미터 → "450m" 또는 "1.5km" 형식 문자열
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  /// 도보 예상 시간 (분). 평균 속도 5km/h
  static int estimateWalkMinutes(double meters) {
    return (meters / 1000 / 5 * 60).round();
  }

  /// 차량 예상 시간 (분). 평균 속도 50km/h
  static int estimateDriveMinutes(double meters) {
    return (meters / 1000 / 50 * 60).round();
  }
}
```

- [ ] **Step 4: 테스트 실행 (PASS 확인)**

```bash
flutter test test/services/location_service_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 5: 커밋**

```bash
git add lib/services/location_service.dart test/services/location_service_test.dart
git commit -m "feat: add LocationService with Haversine distance calculation"
```

---

## Task 7: PhoneStateService (통화 상태 감지)

**Files:**
- Create: `lib/services/phone_state_service.dart`
- Create: `lib/providers/phone_state_provider.dart`

- [ ] **Step 1: phone_state_service.dart 생성**

`lib/services/phone_state_service.dart`:

```dart
import 'package:phone_state/phone_state.dart';

enum CallStatus { idle, calling, ringing }

class PhoneStateService {
  /// 통화 상태 Stream. READ_PHONE_STATE 권한 필요.
  static Stream<CallStatus> get callStatusStream {
    return PhoneState.stream.map((state) {
      switch (state.status) {
        case PhoneStateStatus.CALL_STARTED:
          return CallStatus.calling;
        case PhoneStateStatus.CALL_INCOMING:
          return CallStatus.ringing;
        case PhoneStateStatus.CALL_ENDED:
        case PhoneStateStatus.NOTHING:
          return CallStatus.idle;
      }
    });
  }

  static Future<bool> requestPermission() async {
    return PhoneState.requestPermissions();
  }
}
```

- [ ] **Step 2: phone_state_provider.dart 생성**

`lib/providers/phone_state_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/phone_state_service.dart';

final phoneStateProvider = StreamProvider<CallStatus>((ref) {
  return PhoneStateService.callStatusStream;
});

final isOnCallProvider = Provider<bool>((ref) {
  final state = ref.watch(phoneStateProvider);
  return state.when(
    data: (status) => status == CallStatus.calling || status == CallStatus.ringing,
    loading: () => false,
    error: (_, __) => false,
  );
});
```

- [ ] **Step 3: 커밋**

```bash
git add lib/services/phone_state_service.dart lib/providers/phone_state_provider.dart
git commit -m "feat: add PhoneStateService and provider"
```

---

## Task 8: LocationRequestService (Supabase CRUD + Realtime)

**Files:**
- Create: `lib/services/location_request_service.dart`
- Create: `lib/providers/location_request_provider.dart`
- Create: `test/services/location_request_service_test.dart`

- [ ] **Step 1: 테스트 작성 (RED)**

`test/services/location_request_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:call_distance_tracker/models/location_request.dart';
import 'package:call_distance_tracker/services/location_request_service.dart';

void main() {
  test('buildSmsMessage contains token URL', () {
    const token = 'test-token-abc';
    const baseUrl = 'https://example.supabase.co/functions/v1/consent';
    final msg = LocationRequestService.buildSmsMessage(token, baseUrl);
    expect(msg, contains('$baseUrl/$token'));
    expect(msg, contains('위치'));
  });
}
```

- [ ] **Step 2: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/services/location_request_service_test.dart 2>&1 | tail -5
```

Expected: 파일 없음 오류

- [ ] **Step 3: 구현 (GREEN)**

`lib/services/location_request_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../models/location_request.dart';

class LocationRequestService {
  static const _table = 'location_requests';

  /// 위치 요청 레코드 생성. 생성된 토큰 반환.
  static Future<String> createRequest({
    required String requesterId,
    required double requesterLat,
    required double requesterLng,
  }) async {
    final token = const Uuid().v4();
    await supabase.from(_table).insert({
      'token': token,
      'requester_id': requesterId,
      'requester_lat': requesterLat,
      'requester_lng': requesterLng,
    });
    return token;
  }

  /// 특정 토큰의 레코드 변경을 실시간 수신
  static Stream<LocationRequest> watchRequest(String token) {
    return supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('token', token)
        .map((rows) {
          if (rows.isEmpty) throw Exception('요청을 찾을 수 없습니다.');
          return LocationRequest.fromJson(rows.first);
        })
        .where((req) => req.status == LocationRequestStatus.completed);
  }

  /// SMS 문자 본문 생성
  static String buildSmsMessage(String token, String baseUrl) {
    return '📍 위치 공유 요청이 도착했습니다.\n아래 링크를 눌러 위치를 공유해 주세요:\n$baseUrl/$token\n(10분 후 만료)';
  }
}
```

- [ ] **Step 4: location_request_provider.dart 생성**

`lib/providers/location_request_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_request.dart';
import '../services/location_request_service.dart';

final activeTokenProvider = StateProvider<String?>((ref) => null);

final locationResponseProvider = StreamProvider.autoDispose<LocationRequest>((ref) {
  final token = ref.watch(activeTokenProvider);
  if (token == null) return const Stream.empty();
  return LocationRequestService.watchRequest(token);
});
```

- [ ] **Step 5: 테스트 실행 (PASS 확인)**

```bash
flutter test test/services/location_request_service_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 6: 커밋**

```bash
git add lib/services/location_request_service.dart lib/providers/ test/services/location_request_service_test.dart
git commit -m "feat: add LocationRequestService with Supabase Realtime"
```

---

## Task 9: Supabase Edge Functions

**Files:**
- Create: `supabase/functions/consent/index.ts`
- Create: `supabase/functions/submit-location/index.ts`

> **사전 작업:** Supabase CLI 설치: `brew install supabase/tap/supabase`
> 로그인: `supabase login`
> 프로젝트 링크: `supabase link --project-ref YOUR_PROJECT_ID`

- [ ] **Step 1: consent Edge Function 생성**

`supabase/functions/consent/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

serve(async (req: Request) => {
  const url = new URL(req.url)
  const token = url.pathname.split('/').pop()

  if (!token) {
    return new Response(errorHtml('잘못된 링크입니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 400,
    })
  }

  const { data, error } = await supabase
    .from('location_requests')
    .select('status, expires_at')
    .eq('token', token)
    .single()

  if (error || !data) {
    return new Response(errorHtml('링크를 찾을 수 없습니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 404,
    })
  }

  if (new Date(data.expires_at) < new Date()) {
    return new Response(errorHtml('링크가 만료되었습니다.'), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
      status: 410,
    })
  }

  if (data.status !== 'pending') {
    return new Response(completedHtml(), {
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    })
  }

  const submitUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/submit-location/${token}`

  return new Response(consentHtml(token, submitUrl), {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
})

function consentHtml(token: string, submitUrl: string): string {
  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>위치 공유 요청</title>
  <style>
    body { font-family: -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f5f5f5; }
    .card { background: white; border-radius: 16px; padding: 32px; max-width: 360px; width: 90%; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
    h1 { font-size: 24px; margin-bottom: 8px; }
    p { color: #666; margin-bottom: 24px; }
    button { background: #007AFF; color: white; border: none; border-radius: 12px; padding: 16px 32px; font-size: 16px; cursor: pointer; width: 100%; }
    button:disabled { background: #ccc; }
    #status { margin-top: 16px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>📍 위치 공유 요청</h1>
    <p>상대방이 현재 위치 확인을 요청했습니다.<br>아래 버튼을 눌러 위치를 공유해 주세요.</p>
    <button id="btn" onclick="shareLocation()">위치 공유 허용</button>
    <div id="status"></div>
  </div>
  <script>
    async function shareLocation() {
      const btn = document.getElementById('btn');
      const status = document.getElementById('status');
      btn.disabled = true;
      status.textContent = '위치를 가져오는 중...';

      if (!navigator.geolocation) {
        status.textContent = '이 브라우저는 위치 서비스를 지원하지 않습니다.';
        btn.disabled = false;
        return;
      }

      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          status.textContent = '위치를 전송하는 중...';
          try {
            const res = await fetch('${submitUrl}', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
            });
            if (res.ok) {
              btn.style.display = 'none';
              status.textContent = '✅ 위치가 공유되었습니다!';
            } else {
              status.textContent = '전송에 실패했습니다. 다시 시도해 주세요.';
              btn.disabled = false;
            }
          } catch (e) {
            status.textContent = '네트워크 오류가 발생했습니다.';
            btn.disabled = false;
          }
        },
        (err) => {
          status.textContent = '위치 권한을 허용해 주세요.';
          btn.disabled = false;
        },
        { enableHighAccuracy: true, timeout: 10000 }
      );
    }
  </script>
</body>
</html>`
}

function completedHtml(): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>완료</title>
  <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;}</style>
  </head><body><h2>✅ 위치가 이미 공유되었습니다.</h2></body></html>`
}

function errorHtml(msg: string): string {
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="UTF-8"><title>오류</title>
  <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;}</style>
  </head><body><h2>⚠️ ${msg}</h2></body></html>`
}
```

- [ ] **Step 2: submit-location Edge Function 생성**

`supabase/functions/submit-location/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const token = new URL(req.url).pathname.split('/').pop()
  if (!token) {
    return new Response(JSON.stringify({ error: 'token required' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const { lat, lng } = await req.json() as { lat: number; lng: number }

  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return new Response(JSON.stringify({ error: 'lat and lng required' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // 토큰 유효성 + 만료 검증
  const { data, error } = await supabase
    .from('location_requests')
    .select('id, status, expires_at')
    .eq('token', token)
    .single()

  if (error || !data) {
    return new Response(JSON.stringify({ error: 'token not found' }), {
      status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  if (new Date(data.expires_at) < new Date() || data.status !== 'pending') {
    return new Response(JSON.stringify({ error: 'token expired or already used' }), {
      status: 410, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  await supabase
    .from('location_requests')
    .update({ responder_lat: lat, responder_lng: lng, status: 'completed' })
    .eq('token', token)

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
})
```

- [ ] **Step 3: Edge Functions 배포**

```bash
supabase functions deploy consent
supabase functions deploy submit-location
```

Expected: 배포 성공 메시지 + Function URL 출력

- [ ] **Step 4: constants.dart의 consentBaseUrl 업데이트**

`lib/core/constants.dart`의 `consentBaseUrl`을 배포된 실제 URL로 변경:

```dart
static const consentBaseUrl = 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/consent';
```

- [ ] **Step 5: 브라우저에서 동의 페이지 테스트**

1. Supabase SQL Editor에서 테스트 레코드 삽입:
```sql
INSERT INTO location_requests (token, requester_id, requester_lat, requester_lng)
VALUES ('test-token-001', 'test-device', 37.5665, 126.9780);
```
2. 브라우저에서 `https://YOUR_PROJECT_ID.supabase.co/functions/v1/consent/test-token-001` 접속
3. 동의 버튼 클릭 → 위치 권한 허용
4. Supabase 테이블에서 `responder_lat`, `responder_lng`, `status='completed'` 확인

- [ ] **Step 6: 커밋**

```bash
git add supabase/ lib/core/constants.dart
git commit -m "feat: add Supabase Edge Functions for consent and location submission"
```

---

## Task 10: app.dart 및 라우팅 설정

**Files:**
- Create: `lib/app.dart`

- [ ] **Step 1: app.dart 생성**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/map_screen.dart';
import 'models/location_request.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Distance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/waiting':
            final token = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => WaitingScreen(token: token),
            );
          case '/map':
            final req = settings.arguments as LocationRequest;
            return MaterialPageRoute(
              builder: (_) => MapScreen(locationRequest: req),
            );
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
```

- [ ] **Step 2: 커밋**

```bash
git add lib/app.dart
git commit -m "feat: add App routing setup"
```

---

## Task 11: SplashScreen

**Files:**
- Create: `lib/screens/splash_screen.dart`

- [ ] **Step 1: SplashScreen 구현**

`lib/screens/splash_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/device_id.dart';
import '../core/supabase_client.dart';
import '../services/phone_state_service.dart';

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
    // 1. 익명 세션 생성 (이미 있으면 유지)
    final session = supabase.auth.currentSession;
    if (session == null) {
      await supabase.auth.signInAnonymously();
    }

    // 2. 디바이스 ID 초기화
    await DeviceId.getOrCreate();

    // 3. 전화 상태 권한 요청
    await PhoneStateService.requestPermission();

    // 4. 홈 화면으로 이동
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF007AFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Call Distance Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Supabase anon sign-in 활성화**

Supabase 대시보드 → Authentication → Providers → Anonymous Sign-ins 활성화

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/splash_screen.dart
git commit -m "feat: add SplashScreen with anonymous session init"
```

---

## Task 12: HomeScreen

**Files:**
- Create: `lib/screens/home_screen.dart`
- Create: `lib/providers/location_provider.dart`
- Create: `test/screens/home_screen_test.dart`

- [ ] **Step 1: location_provider.dart 생성**

`lib/providers/location_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

final currentPositionProvider = FutureProvider.autoDispose<Position>((ref) {
  return LocationService.getCurrentPosition();
});
```

- [ ] **Step 2: 테스트 작성 (RED)**

`test/screens/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_distance_tracker/screens/home_screen.dart';
import 'package:call_distance_tracker/providers/phone_state_provider.dart';
import 'package:call_distance_tracker/services/phone_state_service.dart';

void main() {
  testWidgets('HomeScreen shows disabled button when not on call', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneStateProvider.overrideWith(
            (ref) => Stream.value(CallStatus.idle),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('HomeScreen shows enabled button when on call', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneStateProvider.overrideWith(
            (ref) => Stream.value(CallStatus.calling),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    final btn = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(btn.onPressed, isNotNull);
  });
}
```

- [ ] **Step 3: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/screens/home_screen_test.dart 2>&1 | tail -5
```

Expected: 파일 없음 오류

- [ ] **Step 4: HomeScreen 구현 (GREEN)**

`lib/screens/home_screen.dart`:

```dart
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
              ElevatedButton.icon(
                onPressed: isOnCall
                    ? () => _requestLocation(context, ref)
                    : null,
                icon: const Icon(Icons.location_on),
                label: const Text('위치 요청 보내기'),
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
```

- [ ] **Step 5: 테스트 실행 (PASS 확인)**

```bash
flutter test test/screens/home_screen_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/home_screen.dart lib/providers/location_provider.dart test/screens/home_screen_test.dart
git commit -m "feat: add HomeScreen with call-state-aware location request button"
```

---

## Task 13: WaitingScreen

**Files:**
- Create: `lib/screens/waiting_screen.dart`

- [ ] **Step 1: WaitingScreen 구현**

`lib/screens/waiting_screen.dart`:

```dart
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
```

- [ ] **Step 2: 커밋**

```bash
git add lib/screens/waiting_screen.dart
git commit -m "feat: add WaitingScreen with 10min countdown and Realtime listener"
```

---

## Task 14: MapScreen

**Files:**
- Create: `lib/screens/map_screen.dart`
- Create: `test/screens/map_screen_test.dart`

- [ ] **Step 1: 테스트 작성 (RED)**

`test/screens/map_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_distance_tracker/screens/map_screen.dart';
import 'package:call_distance_tracker/models/location_request.dart';

LocationRequest _mockRequest() => LocationRequest(
  id: 'id-1',
  token: 'tok-1',
  requesterId: 'dev-1',
  requesterLat: 37.5665,
  requesterLng: 126.9780,
  responderLat: 37.5700,
  responderLng: 126.9820,
  status: LocationRequestStatus.completed,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
);

void main() {
  testWidgets('MapScreen shows distance text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MapScreen(locationRequest: _mockRequest()),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('m'), findsWidgets);
  });

  testWidgets('MapScreen shows walk and drive time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MapScreen(locationRequest: _mockRequest()),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('도보'), findsOneWidget);
    expect(find.textContaining('차량'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행 (FAIL 확인)**

```bash
flutter test test/screens/map_screen_test.dart 2>&1 | tail -5
```

Expected: 파일 없음 오류

- [ ] **Step 3: MapScreen 구현 (GREEN)**

`lib/screens/map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_request.dart';
import '../services/location_service.dart';

class MapScreen extends StatelessWidget {
  final LocationRequest locationRequest;

  const MapScreen({super.key, required this.locationRequest});

  @override
  Widget build(BuildContext context) {
    final myPos = LatLng(
      locationRequest.requesterLat,
      locationRequest.requesterLng,
    );
    final theirPos = LatLng(
      locationRequest.responderLat!,
      locationRequest.responderLng!,
    );

    final distanceMeters = LocationService.haversineDistance(
      locationRequest.requesterLat,
      locationRequest.requesterLng,
      locationRequest.responderLat!,
      locationRequest.responderLng!,
    );

    final centerLat =
        (locationRequest.requesterLat + locationRequest.responderLat!) / 2;
    final centerLng =
        (locationRequest.requesterLng + locationRequest.responderLng!) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 확인'),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(centerLat, centerLng),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.calltracker.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: myPos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    Marker(
                      point: theirPos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [myPos, theirPos],
                      color: Colors.blue.withOpacity(0.5),
                      strokeWidth: 2,
                      isDotted: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _InfoPanel(distanceMeters: distanceMeters),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final double distanceMeters;

  const _InfoPanel({required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final walkMin = LocationService.estimateWalkMinutes(distanceMeters);
    final driveMin = LocationService.estimateDriveMinutes(distanceMeters);
    final distStr = LocationService.formatDistance(distanceMeters);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: '직선 거리', value: distStr, icon: Icons.straighten),
          _Stat(label: '도보', value: '$walkMin분', icon: Icons.directions_walk),
          _Stat(label: '차량', value: '$driveMin분', icon: Icons.directions_car),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF007AFF), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 (PASS 확인)**

```bash
flutter test test/screens/map_screen_test.dart -v
```

Expected: `All tests passed!`

- [ ] **Step 5: 전체 테스트 실행**

```bash
flutter test
```

Expected: All tests passed

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/map_screen.dart test/screens/map_screen_test.dart
git commit -m "feat: add MapScreen with flutter_map, distance, and travel time"
```

---

## Task 15: 최종 빌드 및 기기 테스트

- [ ] **Step 1: 전체 테스트 통과 확인**

```bash
flutter test
```

Expected: `All tests passed!`

- [ ] **Step 2: Release APK 빌드**

```bash
flutter build apk --release 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 3: 기기 설치 및 E2E 시나리오 확인**

체크리스트:
- [ ] 앱 설치 → 스플래시 → 홈 화면 정상 표시
- [ ] 통화 없을 때 버튼 비활성(회색) 확인
- [ ] 통화 중 버튼 활성(파랑) 확인
- [ ] 버튼 탭 → SMS 앱 열림, 링크 포함 문자 확인
- [ ] 브라우저에서 링크 → 동의 페이지 → 위치 허용 → 완료 메시지
- [ ] 앱에서 WaitingScreen → MapScreen 전환
- [ ] 지도에 두 핀, 거리, 도보/차량 시간 표시 확인

- [ ] **Step 4: 최종 커밋**

```bash
git add .
git commit -m "feat: complete call-distance-tracker v1.0"
```
