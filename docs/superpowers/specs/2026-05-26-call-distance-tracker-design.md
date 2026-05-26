# Call Distance Tracker — Design Spec
**Date:** 2026-05-26  
**Status:** Approved

---

## 1. 프로젝트 개요

전화 통화 중 발신자가 수신자에게 위치 공유 링크를 SMS로 발송하면, 수신자가 브라우저에서 동의 후 위치를 공유하고, 발신자 앱에서 두 사람의 거리와 지도를 실시간으로 확인하는 Android 앱.

**핵심 컨셉:** 미아 방지 / 약속 장소 확인 / 긴급 위치 파악 등에 활용 가능한 1회성 위치 공유 서비스.

---

## 2. 기술 스택

| 레이어 | 기술 |
|---|---|
| 모바일 앱 | Flutter (Android) |
| 상태 관리 | Riverpod |
| 지도 | flutter_map + OpenStreetMap (또는 Google Maps Flutter) |
| 통화 감지 | phone_state 패키지 (READ_PHONE_STATE 권한) |
| SMS 발송 | url_launcher (네이티브 SMS 앱 열기) |
| 백엔드 | Supabase (Postgres + Edge Functions + Realtime) |
| 동의 웹페이지 | Supabase Edge Function (HTML/JS 서빙) |
| 인증 | Supabase 익명 세션 (전화번호 기반) |
| 거리/경로 계산 | Haversine 공식 (직선거리) + 선택적으로 OSRM API |

---

## 3. 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Android)                  │
│                                                           │
│  [통화 상태 감지]  →  [위치 요청 버튼 활성화]            │
│       ↓                        ↓                         │
│  PhoneStatePlugin         위치 요청 생성                  │
│                           (Supabase에 토큰 저장)          │
│                                ↓                         │
│                         SMS 앱 오픈                       │
│                         (url_launcher)                    │
│                                ↓                         │
│                    Supabase Realtime 구독                 │
│                         (응답 대기)                       │
│                                ↓                         │
│                    지도 + 거리 + 이동시간 표시             │
└─────────────────────────────────────────────────────────┘
                              ↕ Supabase Realtime
┌─────────────────────────────────────────────────────────┐
│                    Supabase Backend                       │
│                                                           │
│  Postgres                                                 │
│  └── location_requests (토큰, 상태, 좌표, 만료시간)       │
│                                                           │
│  Edge Functions                                           │
│  ├── GET  /consent/:token  → 동의 웹페이지 HTML 서빙      │
│  └── POST /location/:token → 수신자 위치 저장             │
│                                                           │
│  Realtime                                                 │
│  └── location_requests 테이블 변경 감지 → 앱에 푸시       │
└─────────────────────────────────────────────────────────┘
                              ↕ 브라우저
┌─────────────────────────────────────────────────────────┐
│                 수신자 브라우저 (앱 불필요)                │
│                                                           │
│  SMS 링크 탭                                              │
│       ↓                                                   │
│  동의 페이지 로드 (Edge Function 서빙)                    │
│       ↓                                                   │
│  "위치 공유 허용" 버튼 탭                                  │
│       ↓                                                   │
│  브라우저 위치 권한 요청 (Geolocation API)                │
│       ↓                                                   │
│  좌표 → Supabase Edge Function POST                       │
│       ↓                                                   │
│  "공유 완료" 페이지 표시                                   │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 데이터 모델

### `location_requests` 테이블

```sql
CREATE TABLE location_requests (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token        TEXT UNIQUE NOT NULL,       -- SMS 링크에 포함되는 고유 토큰
  requester_id TEXT NOT NULL,              -- 발신자 익명 세션 ID
  requester_lat DOUBLE PRECISION,          -- 발신자 위도
  requester_lng DOUBLE PRECISION,          -- 발신자 경도
  responder_lat DOUBLE PRECISION,          -- 수신자 위도 (응답 후 채워짐)
  responder_lng DOUBLE PRECISION,          -- 수신자 경도
  status       TEXT DEFAULT 'pending',     -- pending | completed | expired
  created_at   TIMESTAMPTZ DEFAULT now(),
  expires_at   TIMESTAMPTZ DEFAULT now() + INTERVAL '10 minutes'
);
```

---

## 5. 전체 워크플로우

### 발신자 흐름
```
1. 앱 최초 실행
   └── 익명 세션 생성 (Supabase anon key + 디바이스 ID)

2. 메인 화면 대기
   └── PhoneState 권한 요청 (READ_PHONE_STATE)

3. 통화 중 상태 감지
   └── "위치 요청 보내기" 버튼 활성화 (평소엔 비활성)

4. 버튼 탭
   ├── 발신자 현재 위치 수집 (GPS)
   ├── Supabase에 location_request 레코드 생성
   │   └── 고유 토큰 발급, 발신자 좌표 저장
   ├── SMS 앱 오픈 (url_launcher)
   │   └── 미리 채워진 문자: "위치 공유 요청: https://<edge-fn-url>/consent/<token>"
   └── Supabase Realtime 구독 시작 (token 기준)

5. 응답 대기 화면
   └── "상대방의 응답을 기다리는 중..." 로딩 UI
   └── 10분 타임아웃 처리

6. 위치 수신
   ├── 지도 화면으로 전환
   ├── 내 위치(파란 핀) + 상대방 위치(빨간 핀) 표시
   ├── 직선 거리 표시 (Haversine)
   └── 도보 / 차량 예상 시간 표시
```

### 수신자 흐름
```
1. SMS 수신 → 링크 탭
2. 브라우저에서 동의 페이지 로드
   └── Edge Function이 HTML 렌더링
3. "위치 공유 허용" 버튼 탭
   └── Geolocation API로 좌표 수집
4. POST /location/:token 호출
   └── Supabase DB에 수신자 좌표 저장
   └── status: 'pending' → 'completed'
5. "위치가 공유되었습니다" 완료 화면
```

---

## 6. Edge Functions

### `GET /consent/:token`
- 토큰 유효성 검증 (존재 여부, 만료 여부)
- 동의 페이지 HTML 반환 (인라인 JS 포함)
- 만료 또는 없는 토큰 → 오류 페이지 반환

### `POST /location/:token`
- Body: `{ lat: number, lng: number }`
- 토큰 유효성 검증
- `responder_lat`, `responder_lng` 업데이트
- `status` → `'completed'` 업데이트
- Realtime이 자동으로 구독 앱에 변경 사항 푸시

---

## 7. Flutter 앱 화면 구성

| 화면 | 설명 |
|---|---|
| SplashScreen | 익명 세션 초기화 |
| HomeScreen | 메인 대기 화면, 통화 중일 때 버튼 활성화 |
| WaitingScreen | 위치 요청 발송 후 응답 대기 |
| MapScreen | 두 위치 + 거리 + 이동 시간 표시 |

---

## 8. 권한 (Android)

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
```

---

## 9. 보안 & 제약사항

- 토큰은 UUID v4 기반, 1회 사용 후 만료
- 링크 만료 시간: 생성 후 **10분**
- 동일 토큰으로 중복 위치 제출 불가 (status 체크)
- Supabase RLS(Row Level Security)로 타 세션 데이터 접근 차단
- 수신자 위치 데이터는 완료 후 **24시간** 뒤 자동 삭제 (Supabase cron)

---

## 10. 향후 확장 가능 항목 (현재 스코프 제외)

- 위치 공유 히스토리 저장
- 실시간 연속 추적 모드
- iOS 지원
- 푸시 알림 (FCM)
