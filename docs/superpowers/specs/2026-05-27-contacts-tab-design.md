# 연락처 기반 위치 요청 설계

## Goal
하단 탭 구조로 앱을 재편하여, 통화 중일 때뿐 아니라 평소에도 연락처에서 친구를 선택해 위치 요청을 보낼 수 있게 한다.

## Architecture

하단 탭 2개를 가진 `MainScreen`으로 기존 `HomeScreen`을 감싼다.

```
MainScreen (BottomNavigationBar)
├── Tab 0: 통화 중 (기존 HomeScreen 그대로)
└── Tab 1: 연락처 (ContactsScreen — 신규)
```

## 워크플로우

### 통화 중 탭
기존과 동일. 통화 감지 → 버튼 활성화 → SMS 발송 → 대기 → 지도.

### 연락처 탭
1. 앱 최초 실행 시 (SplashScreen) 연락처 권한 요청
2. ContactsScreen: 연락처 목록 표시 + 검색바
3. 연락처 선택 → SMS 요청 발송 (기존 `LocationRequestService.buildSmsMessage` 재사용)
4. 대기 화면 → 지도 화면 (기존 흐름 그대로)

## 변경 파일

| 파일 | 변경 |
|---|---|
| `lib/screens/main_screen.dart` | 신규 — BottomNavigationBar 래퍼 |
| `lib/screens/contacts_screen.dart` | 신규 — 연락처 목록 + 검색 |
| `lib/providers/contacts_provider.dart` | 신규 — 연락처 로드/필터 |
| `lib/screens/splash_screen.dart` | 수정 — 연락처 권한 추가 |
| `lib/app.dart` | 수정 — 초기 경로를 MainScreen으로 변경 |
| `pubspec.yaml` | 수정 — `flutter_contacts` 패키지 추가 |
| `android/app/src/main/AndroidManifest.xml` | 수정 — `READ_CONTACTS` 권한 추가 |

## 기존 코드 영향 없음
- Supabase 백엔드, Edge Functions
- SMS 발송 로직 (`LocationRequestService`)
- 대기 화면 (`WaitingScreen`)
- 지도 화면 (`MapScreen`)

## 기술 스택
- `flutter_contacts: ^1.1.7` — 연락처 접근
- `permission_handler` — 이미 사용 중, `Permission.contacts` 추가
