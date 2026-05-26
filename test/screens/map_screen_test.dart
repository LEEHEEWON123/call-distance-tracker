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
