import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_distance_tracker/providers/contacts_provider.dart';

void main() {
  test('빈 검색어면 전체 반환', () async {
    final hong = Contact()..displayName = '홍길동';
    final kim = Contact()..displayName = '김철수';

    final container = ProviderContainer(
      overrides: [
        contactsProvider.overrideWith((_) async => [hong, kim]),
      ],
    );
    addTearDown(container.dispose);

    // FutureProvider 완료 대기
    await container.read(contactsProvider.future);

    final result = container.read(filteredContactsProvider);
    result.whenData((list) => expect(list.length, 2));
  });

  test('이름 검색 필터링', () async {
    final hong = Contact()..displayName = '홍길동';
    final kim = Contact()..displayName = '김철수';

    final container = ProviderContainer(
      overrides: [
        contactsProvider.overrideWith((_) async => [hong, kim]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(contactsProvider.future);
    container.read(contactSearchQueryProvider.notifier).state = '홍';

    final result = container.read(filteredContactsProvider);
    result.whenData((list) {
      expect(list.length, 1);
      expect(list.first.displayName, '홍길동');
    });
  });
}
