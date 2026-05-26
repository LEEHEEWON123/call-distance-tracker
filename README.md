# Call Distance Tracker

통화 중 상대방에게 SMS 링크를 보내고, 상대방이 브라우저에서 동의하면 두 사람의 위치와 거리를 지도에 표시하는 Android 앱.

---

## 주요 기능

- 통화 중 자동으로 "위치 요청 보내기" 버튼 활성화
- SMS로 동의 링크 발송 (상대방 앱 설치 불필요)
- 상대방이 브라우저에서 한 번 탭으로 위치 공유
- 지도에 내 위치(파란 핀) + 상대방 위치(빨간 핀) 표시
- 직선 거리 / 도보 예상 시간 / 차량 예상 시간 표시

---

## 기술 스택

| 레이어 | 기술 |
|---|---|
| 모바일 앱 | Flutter (Android) |
| 상태 관리 | Riverpod 2.x |
| 지도 | flutter_map + OpenStreetMap |
| 통화 감지 | phone_state |
| 백엔드 | Supabase (Postgres + Edge Functions + Realtime) |
| 인증 | Supabase 익명 세션 |

---

## 아키텍처

```
[Flutter 앱]
  통화 감지 → 위치 요청 버튼 활성화
  버튼 탭   → Supabase에 요청 생성 (토큰 발급)
           → SMS 앱으로 링크 전송
           → Supabase Realtime 구독 (응답 대기)
           → 위치 수신 시 지도 화면 표시

[수신자 브라우저]
  링크 탭 → 동의 페이지 로드 (Edge Function)
          → 위치 허용 → 좌표 전송 → 완료

[Supabase]
  Postgres      : location_requests 테이블
  Edge Function : /consent/:token (동의 페이지)
  Edge Function : /submit-location/:token (위치 저장)
  Realtime      : 앱에 위치 도착 푸시
```

---

## 프로젝트 구조

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants.dart              # Supabase URL/key
│   ├── supabase_client.dart
│   └── device_id.dart
├── models/
│   └── location_request.dart
├── services/
│   ├── location_service.dart       # GPS + Haversine
│   ├── phone_state_service.dart    # 통화 상태 감지
│   └── location_request_service.dart
├── providers/
│   ├── phone_state_provider.dart
│   ├── location_provider.dart
│   └── location_request_provider.dart
└── screens/
    ├── splash_screen.dart
    ├── home_screen.dart
    ├── waiting_screen.dart
    └── map_screen.dart
supabase/
├── migrations/
│   └── 20260526000000_create_location_requests.sql
└── functions/
    ├── consent/index.ts
    └── submit-location/index.ts
```

---

## 실행 방법

### 1. Supabase 설정

1. [supabase.com](https://supabase.com)에서 새 프로젝트 생성
2. **SQL Editor**에서 마이그레이션 실행:
   ```
   supabase/migrations/20260526000000_create_location_requests.sql
   ```
3. **Authentication → Providers → Anonymous Sign-ins** 활성화

### 2. 환경 설정

`lib/core/constants.dart` 수정:

```dart
static const supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
static const supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 3. Edge Functions 배포

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref YOUR_PROJECT_ID
supabase functions deploy consent
supabase functions deploy submit-location
```

### 4. 앱 실행

```bash
flutter pub get
flutter run
```

또는 APK 빌드:

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 권한

| 권한 | 용도 |
|---|---|
| READ_PHONE_STATE | 통화 상태 감지 |
| ACCESS_FINE_LOCATION | GPS 위치 수집 |
| INTERNET | Supabase 통신 |

---

## 보안

- 위치 공유 링크는 생성 후 **10분** 후 만료
- 토큰 1회 사용 후 재사용 불가
- Supabase RLS로 타 세션 데이터 접근 차단
- 수신자 동의 없이 위치 수집 불가 (브라우저 권한 요청)

---

## 비용

무료 티어로 소규모 운영 가능:

| 서비스 | 무료 한도 | 비고 |
|---|---|---|
| Supabase | 500MB DB / 500K Edge Function 호출/월 | 개인 프로젝트 충분 |
| OpenStreetMap | 무제한 | 오픈소스 |
| flutter_map | 무료 | 오픈소스 |
