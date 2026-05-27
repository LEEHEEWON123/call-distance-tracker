import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'app.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  runApp(ProviderScope(child: App(navigatorKey: _navigatorKey)));
  _initDeepLinks();
}

void _initDeepLinks() {
  final appLinks = AppLinks();

  // 앱이 종료된 상태에서 딥링크로 실행된 경우
  appLinks.getInitialLink().then((uri) {
    if (uri != null) _handleDeepLink(uri);
  });

  // 앱이 백그라운드 또는 포그라운드에 있을 때 딥링크 수신
  appLinks.uriLinkStream.listen(_handleDeepLink);
}

void _handleDeepLink(Uri uri) {
  // nearmates://consent/TOKEN
  if (uri.scheme == AppConstants.deepLinkScheme &&
      uri.host == AppConstants.deepLinkHost) {
    final token = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (token != null && token.isNotEmpty) {
      _navigatorKey.currentState?.pushNamed('/consent', arguments: token);
    }
  }
}
