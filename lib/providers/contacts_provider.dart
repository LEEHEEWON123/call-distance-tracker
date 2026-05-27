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
