# Contacts Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하단 탭 2개(통화 중 / 연락처)를 추가해 평소에도 전화번호부에서 친구를 선택해 위치 요청을 보낼 수 있게 한다.

**Architecture:** `MainScreen`이 `BottomNavigationBar`로 기존 `HomeScreen`(통화 중 탭)과 새 `ContactsScreen`(연락처 탭)을 감싼다. 연락처는 `flutter_contacts` 패키지로 로드하고 Riverpod `StateNotifierProvider`로 검색 필터링을 관리한다. SMS 발송 및 대기/지도 화면은 기존 코드를 그대로 재사용한다.

**Tech Stack:** Flutter, Riverpod 2.x, flutter_contacts ^1.1.7, permission_handler (기존)

---

## File Map

| 파일 | 역할 |
|---|---|
| `pubspec.yaml` | flutter_contacts 추가 |
| `android/app/src/main/AndroidManifest.xml` | READ_CONTACTS 권한 추가 |
| `lib/screens/splash_screen.dart` | 연락처 권한 요청 추가 |
| `lib/providers/contacts_provider.dart` | 신규 — 연락처 로드 + 검색 필터 |
| `lib/screens/contacts_screen.dart` | 신규 — 연락처 목록 + 검색바 |
| `lib/screens/main_screen.dart` | 신규 — BottomNavigationBar 래퍼 |
| `lib/app.dart` | `/home` 라우트를 `MainScreen`으로 변경 |

---

### Task 1: flutter_contacts 패키지 추가 + 권한 설정

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: pubspec.yaml에 flutter_contacts 추가**

`dependencies:` 블록에 추가:
```yaml
  flutter_contacts: ^1.1.7
```

- [ ] **Step 2: flutter pub get 실행**

```bash
flutter pub get
```
Expected: `Got dependencies!`

- [ ] **Step 3: AndroidManifest.xml에 READ_CONTACTS 추가**

`<uses-permission android:name="android.permission.READ_PHONE_STATE"/>` 바로 아래에 추가:
```xml
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
```

- [ ] **Step 4: 커밋**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: add flutter_contacts dependency and READ_CONTACTS permission"
```

---

### Task 2: SplashScreen에 연락처 권한 요청 추가

**Files:**
- Modify: `lib/screens/splash_screen.dart`

- [ ] **Step 1: _init() 메서드에 연락처 권한 추가**

현재 `_init()`:
```dart
Future<void> _init() async {
  final session = supabase.auth.currentSession;
  if (session == null) {
    await supabase.auth.signInAnonymously();
  }
  await DeviceId.getOrCreate();
  await Permission.phone.request();
  if (mounted) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
```

변경 후:
```dart
Future<void> _init() async {
  final session = supabase.auth.currentSession;
  if (session == null) {
    await supabase.auth.signInAnonymously();
  }
  await DeviceId.getOrCreate();
  await Permission.phone.request();
  await Permission.contacts.request();
  if (mounted) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
```

- [ ] **Step 2: 앱 실행해서 권한 다이얼로그 확인**

```bash
flutter run
```
Expected: 스플래시 화면에서 전화 권한 + 연락처 권한 다이얼로그 순서대로 표시됨

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/splash_screen.dart
git commit -m "feat: request contacts permission on splash"
```

---

### Task 3: ContactsProvider 구현

**Files:**
- Create: `lib/providers/contacts_provider.dart`

- [ ] **Step 1: contacts_provider.dart 생성**

```dart
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 연락처 전체 목록 로드
final contactsProvider = FutureProvider<List<Contact>>((ref) async {
  return await FlutterContacts.getContacts(
    withProperties: true,
    withPhoto: false,
  );
});

// 검색어 상태
final contactSearchQueryProvider = StateProvider<String>((ref) => '');

// 필터링된 연락처 목록
final filteredContactsProvider = Provider<AsyncValue<List<Contact>>>((ref) {
  final contactsAsync = ref.watch(contactsProvider);
  final query = ref.watch(contactSearchQueryProvider).toLowerCase().trim();

  return contactsAsync.whenData((contacts) {
    if (query.isEmpty) return contacts;
    return contacts.where((c) {
      final nameMatch = c.displayName.toLowerCase().contains(query);
      final phoneMatch = c.phones.any(
        (p) => p.number.replaceAll(RegExp(r'\D'), '').contains(query),
      );
      return nameMatch || phoneMatch;
    }).toList();
  });
});
```

- [ ] **Step 2: 테스트 작성**

`test/providers/contacts_provider_test.dart` 생성:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_distance_tracker/providers/contacts_provider.dart';

void main() {
  test('빈 검색어면 전체 반환', () {
    final container = ProviderContainer(
      overrides: [
        contactsProvider.overrideWith((_) async => [
          Contact()..displayName = '홍길동',
          Contact()..displayName = '김철수',
        ]),
        contactSearchQueryProvider.overrideWith((ref) => ref.state = ''),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(filteredContactsProvider);
    result.whenData((list) => expect(list.length, 2));
  });

  test('이름 검색 필터링', () {
    final container = ProviderContainer(
      overrides: [
        contactsProvider.overrideWith((_) async => [
          Contact()..displayName = '홍길동',
          Contact()..displayName = '김철수',
        ]),
        contactSearchQueryProvider.overrideWith((ref) => ref.state = '홍'),
      ],
    );
    addTearDown(container.dispose);

    final result = container.read(filteredContactsProvider);
    result.whenData((list) {
      expect(list.length, 1);
      expect(list.first.displayName, '홍길동');
    });
  });
}
```

- [ ] **Step 3: 테스트 실행 (실패 확인)**

```bash
flutter test test/providers/contacts_provider_test.dart
```
Expected: 파일이 존재하고 provider가 없어서 FAIL

- [ ] **Step 4: 테스트 재실행 (통과 확인)**

```bash
flutter test test/providers/contacts_provider_test.dart
```
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add lib/providers/contacts_provider.dart test/providers/contacts_provider_test.dart
git commit -m "feat: add contacts provider with search filter"
```

---

### Task 4: ContactsScreen 구현

**Files:**
- Create: `lib/screens/contacts_screen.dart`

- [ ] **Step 1: contacts_screen.dart 생성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/device_id.dart';
import '../providers/contacts_provider.dart';
import '../providers/location_request_provider.dart';
import '../services/location_service.dart';
import '../services/location_request_service.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(filteredContactsProvider);
    final query = ref.watch(contactSearchQueryProvider);

    return Column(
      children: [
        _SearchBar(query: query, ref: ref),
        Expanded(
          child: contactsAsync.when(
            data: (contacts) => contacts.isEmpty
                ? const Center(child: Text('연락처가 없습니다.'))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (context, i) =>
                        _ContactTile(contact: contacts[i]),
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('연락처를 불러올 수 없습니다.\n$e',
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final WidgetRef ref;

  const _SearchBar({required this.query, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: '이름 또는 전화번호 검색',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFF2F2F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) =>
            ref.read(contactSearchQueryProvider.notifier).state = v,
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  final Contact contact;
  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF007AFF),
        child: Text(
          contact.displayName.isNotEmpty
              ? contact.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        contact.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: phone != null
          ? Text(phone, style: const TextStyle(color: Colors.grey))
          : null,
      trailing: phone != null
          ? IconButton(
              icon: const Icon(Icons.location_on, color: Color(0xFF007AFF)),
              onPressed: () => _requestLocation(context, ref, phone),
            )
          : null,
    );
  }

  Future<void> _requestLocation(
      BuildContext context, WidgetRef ref, String phoneNumber) async {
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
      final uri = Uri.parse(
          'sms:${Uri.encodeComponent(phoneNumber)}?body=${Uri.encodeComponent(smsBody)}');

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

- [ ] **Step 2: 커밋**

```bash
git add lib/screens/contacts_screen.dart
git commit -m "feat: add contacts screen with search and location request"
```

---

### Task 5: MainScreen (하단 탭) 구현

**Files:**
- Create: `lib/screens/main_screen.dart`

- [ ] **Step 1: main_screen.dart 생성**

```dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    ContactsScreen(),
  ];

  static const _titles = ['통화 중', '연락처'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_in_talk),
            label: '통화 중',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: '연락처',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 커밋**

```bash
git add lib/screens/main_screen.dart
git commit -m "feat: add main screen with bottom navigation tabs"
```

---

### Task 6: app.dart 라우트 업데이트

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: MainScreen import 추가 및 /home 라우트 변경**

현재 `lib/app.dart`:
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

변경 후:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
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
            return MaterialPageRoute(builder: (_) => const MainScreen());
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
            return MaterialPageRoute(builder: (_) => const MainScreen());
        }
      },
    );
  }
}
```

- [ ] **Step 2: HomeScreen의 AppBar 제거 (MainScreen이 대신 표시)**

`lib/screens/home_screen.dart`의 `Scaffold`에서 `appBar` 제거:

현재:
```dart
return Scaffold(
  appBar: AppBar(
    title: const Text('Call Distance Tracker'),
    backgroundColor: const Color(0xFF007AFF),
    foregroundColor: Colors.white,
  ),
  body: Center(
```

변경 후:
```dart
return Scaffold(
  body: Center(
```

- [ ] **Step 3: flutter analyze 실행**

```bash
flutter analyze
```
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
git add lib/app.dart lib/screens/home_screen.dart
git commit -m "feat: wire MainScreen into router, remove HomeScreen appbar"
```

---

### Task 7: 전체 통합 테스트

- [ ] **Step 1: 전체 테스트 실행**

```bash
flutter test
```
Expected: All tests pass

- [ ] **Step 2: 앱 실행 및 동작 확인**

```bash
flutter run
```

확인 항목:
- 스플래시에서 연락처 권한 다이얼로그 뜨는지
- 하단 탭 2개 표시되는지 (통화 중 / 연락처)
- 연락처 탭 탭 시 목록 표시되는지
- 검색바에서 이름/번호 필터링되는지
- 연락처 옆 위치 버튼 탭 시 SMS 앱 열리는지
- SMS 발송 후 대기 화면 이동하는지

- [ ] **Step 3: 최종 커밋 + 푸시**

```bash
git add .
git commit -m "feat: contacts tab — location request from address book"
git push origin main
```
