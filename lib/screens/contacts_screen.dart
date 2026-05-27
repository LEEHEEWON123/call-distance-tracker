import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
              child: Text(
                '연락처를 불러올 수 없습니다.\n$e',
                textAlign: TextAlign.center,
              ),
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
    final phone =
        contact.phones.isNotEmpty ? contact.phones.first.number : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF007AFF),
        child: Text(
          contact.displayName.isNotEmpty
              ? contact.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
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
              onPressed: () => _showConfirmDialog(context, ref, phone),
            )
          : null,
    );
  }

  Future<void> _showConfirmDialog(
      BuildContext context, WidgetRef ref, String phoneNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('위치 요청'),
        content: Text(
          '${contact.displayName}에게\n위치 공유 요청을 보낼까요?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '확인',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _requestLocation(context, ref, phoneNumber);
    }
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

      final shareText = LocationRequestService.buildSmsMessage(
        token,
        AppConstants.consentBaseUrl,
      );
      await Share.share(shareText);

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
