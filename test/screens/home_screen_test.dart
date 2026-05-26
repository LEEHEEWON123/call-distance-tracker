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
