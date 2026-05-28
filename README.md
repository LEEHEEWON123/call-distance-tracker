# NearMates

통화 중 상대방에게 위치 요청을 보내고, 상대방이 앱에서 동의하면 두 사람의 위치와 거리를 지도에 표시하는 Android 앱.

---

## 주요 기능

- 연락처에서 상대방 선택 → 위치 요청 전송
- FCM 푸시 알림으로 상대방 앱 깨우기 (백그라운드/종료 상태 대응)
- 앱 내 동의 다이얼로그 → 위치 공유 허용
- 지도에 내 위치(파란 핀) + 상대방 위치(빨간 말풍선 핀) 표시
- 직선 거리 / 도보 예상 시간 / 차량 예상 시간 표시
- 앱 포그라운드 시 Supabase Realtime으로 즉시 다이얼로그 표시

---

## 기술 스택

| 레이어 | 기술 |
|---|---|
| 모바일 앱 | Flutter (Android) |
| 상태 관리 | Riverpod 2.x |
| 지도 | flutter_map + CartoMap (Voyager) |
| 통화 감지 | phone_state |
| 연락처 | flutter_contacts |
| 딥링크 | app_links (`nearmates://consent/TOKEN`) |
| 백엔드 | Supabase (Postgres + Edge Functions + Realtime) |
| 인증 | Supabase 익명 세션 |
| 푸시 알림 | Firebase FCM v1 API (서비스 계정 JWT) |
| 로컬 저장 | SharedPreferences (내 전화번호) |

---

## 아키텍처

```
[요청자 앱]
  연락처 탭 → 상대방 선택
           → 내 GPS 위치 수집
           → Supabase location_requests 레코드 생성 (토큰 발급)
           → send-push Edge Function 호출 → FCM 푸시 발송
           → Supabase Realtime 구독 (응답 대기)
           → 응답 수신 시 MapScreen 표시

[수신자 앱 - 백그라운드/종료]
  FCM 푸시 수신 → 알림 탭
              → 앱 실행 + ConsentScreen(/consent/TOKEN)
              → 동의 버튼 탭 → GPS 수집 → submit-location 호출
              → MapScreen 표시

[수신자 앱 - 포그라운드]
  Supabase Realtime → location_requests 변경 감지
                   → IncomingRequestSheet (다이얼로그) 표시
                   → 동의 → submit-location 호출
                   → MapScreen 표시

[Supabase]
  Postgres       : location_requests, device_tokens 테이블
  Edge Function  : /submit-location/:token (위치 저장)
  Edge Function  : /send-push (FCM 푸시 발송)
  Realtime       : location_requests 변경 스트림

[Firebase]
  FCM v1 API     : 푸시 알림 발송 (서비스 계정 OAuth2 JWT)
```

---

## 프로젝트 구조

```
lib/
├── main.dart                          # Firebase/Supabase 초기화, 딥링크 처리
├── app.dart                           # 라우터 (navigatorKey, /consent 등록)
├── firebase_options.dart              # FlutterFire 자동 생성
├── core/
│   ├── constants.dart                 # Supabase URL/key, Edge Function URL
│   ├── supabase_client.dart
│   ├── device_id.dart
│   └── my_phone_store.dart            # SharedPreferences 내 번호 저장
├── models/
│   └── location_request.dart          # LocationRequest, LocationRequestStatus
├── services/
│   ├── location_service.dart          # GPS + Haversine + 거리 포맷
│   ├── phone_state_service.dart       # 통화 상태 감지
│   ├── location_request_service.dart  # Supabase CRUD + Realtime 스트림
│   └── fcm_service.dart               # FCM 토큰 관리 + 푸시 발송
├── providers/
│   ├── phone_state_provider.dart
│   ├── location_provider.dart
│   ├── location_request_provider.dart
│   ├── contacts_provider.dart
│   └── incoming_request_provider.dart # myPhoneProvider, incomingRequestProvider
└── screens/
    ├── splash_screen.dart             # 권한 요청, 번호 입력, FCM 초기화
    ├── main_screen.dart               # 탭바 + Realtime 다이얼로그
    ├── home_screen.dart
    ├── contacts_screen.dart           # 연락처 목록 + 위치 요청
    ├── waiting_screen.dart
    ├── consent_screen.dart            # 동의 화면 (알림 탭 진입점)
    └── map_screen.dart                # 두 핀 + 거리 바텀시트

supabase/
├── migrations/
│   ├── 20260526000000_create_location_requests.sql
│   ├── 20260527_add_responder_phone.sql
│   └── 20260528_create_device_tokens.sql
└── functions/
    ├── consent/index.ts               # 동의 페이지 리디렉트 (레거시)
    ├── submit-location/index.ts       # 응답자 위치 저장
    └── send-push/index.ts             # FCM v1 API 푸시 발송
```

---

## 실행 방법

### 1. Supabase 설정

1. [supabase.com](https://supabase.com)에서 프로젝트 생성
2. SQL Editor에서 마이그레이션 순서대로 실행:
   ```
   supabase/migrations/20260526000000_create_location_requests.sql
   supabase/migrations/20260527_add_responder_phone.sql
   supabase/migrations/20260528_create_device_tokens.sql
   ```
3. **Authentication → Providers → Anonymous Sign-ins** 활성화
4. `device_tokens` RLS 정책 추가:
   ```sql
   ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "Anyone can upsert device tokens"
   ON device_tokens FOR ALL USING (true) WITH CHECK (true);
   ```

### 2. Firebase 설정

1. [Firebase Console](https://console.firebase.google.com)에서 Android 앱 등록
2. `google-services.json` 다운로드 → `android/app/` 에 배치
3. `flutterfire configure` 로 `lib/firebase_options.dart` 생성
4. 서비스 계정 JSON 다운로드 → Supabase 시크릿 등록:
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT='<JSON 내용>'
   ```

### 3. Edge Functions 배포

```bash
supabase link --project-ref YOUR_PROJECT_ID
supabase functions deploy submit-location --no-verify-jwt
supabase functions deploy send-push --no-verify-jwt
```

### 4. 앱 실행

```bash
flutter pub get
flutter run
```

---

## 권한

| 권한 | 용도 |
|---|---|
| READ_PHONE_STATE | 통화 상태 감지 |
| READ_CONTACTS | 연락처 목록 조회 |
| ACCESS_FINE_LOCATION | GPS 위치 수집 |
| POST_NOTIFICATIONS | FCM 푸시 알림 표시 (Android 13+) |
| INTERNET | Supabase / FCM 통신 |

---

## 보안

- 위치 공유 링크는 생성 후 **10분** 후 만료
- 토큰 1회 사용 후 재사용 불가
- Supabase RLS로 타 세션 데이터 접근 차단
- 수신자 동의 없이 위치 수집 불가

---

## 비용

| 서비스 | 무료 한도 | 비고 |
|---|---|---|
| Supabase | 500MB DB / 500K Edge Function 호출/월 | 개인 프로젝트 충분 |
| Firebase FCM | 500만 건/월 무료 | 사실상 무료 |
| CartoMap | 무제한 | 오픈소스 |
| flutter_map | 무료 | 오픈소스 |
