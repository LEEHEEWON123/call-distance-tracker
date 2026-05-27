import 'package:flutter/material.dart';
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
