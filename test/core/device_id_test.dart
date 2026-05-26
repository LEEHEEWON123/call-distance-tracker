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
