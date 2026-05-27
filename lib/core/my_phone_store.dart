import 'package:shared_preferences/shared_preferences.dart';

class MyPhoneStore {
  static const _key = 'my_phone_number';

  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> set(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _normalize(phone));
  }

  /// 전화번호 정규화: 공백/하이픈 제거, 010으로 시작하도록
  static String _normalize(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-]'), '');
  }
}
