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

// 아바타 색상 팔레트 (HTML과 동일)
const _avatarGradients = [
  [Color(0xFF93b5e1), Color(0xFF7098c8)],
  [Color(0xFFf5a878), Color(0xFFe88855)],
  [Color(0xFFa8d8b9), Color(0xFF7bbf96)],
  [Color(0xFFf5c2c2), Color(0xFFe89090)],
  [Color(0xFFc5b4e3), Color(0xFFa58cd4)],
  [Color(0xFFffd97d), Color(0xFFf0be45)],
];

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(filteredContactsProvider);
    final query = ref.watch(contactSearchQueryProvider);

    return Container(
      color: const Color(0xFFf0f8f5),
      child: Column(
        children: [
          _SearchBar(query: query, ref: ref),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) => contacts.isEmpty
                  ? const Center(child: Text('연락처가 없습니다.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: contacts.length,
                      itemBuilder: (context, i) =>
                          _ContactCard(contact: contacts[i], index: i),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF5aaa85)),
              ),
              error: (e, _) => Center(
                child: Text(
                  '연락처를 불러올 수 없습니다.\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String query;
  final WidgetRef ref;

  const _SearchBar({required this.query, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: TextField(
        decoration: InputDecoration(
          hintText: '이름 또는 전화번호 검색',
          hintStyle: const TextStyle(color: Color(0xFFaaaaaa)),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search, color: Color(0xFFaaaaaa), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          filled: true,
          fillColor: const Color(0xFFf0f8f5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFd4ede6), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFd4ede6), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF5aaa85), width: 1.5),
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

class _ContactCard extends ConsumerWidget {
  final Contact contact;
  final int index;
  const _ContactCard({required this.contact, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone =
        contact.phones.isNotEmpty ? contact.phones.first.number : null;
    final colors = _avatarGradients[index % _avatarGradients.length];
    final initial = contact.displayName.isNotEmpty
        ? contact.displayName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 아바타
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 이름 + 번호
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1c1c1e),
                    ),
                  ),
                  if (phone != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8e8e93),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 위치 요청 버튼
            if (phone != null)
              GestureDetector(
                onTap: () => _showConfirmDialog(context, ref, phone),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7bbf9e), Color(0xFF5aaa85)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5aaa85).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: _PinIcon(),
                  ),
                ),
              ),
          ],
        ),
      ),
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
                color: Color(0xFF5aaa85),
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

class _PinIcon extends StatelessWidget {
  const _PinIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 20),
      painter: _PinPainter(),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    final cx = size.width / 2;

    path.moveTo(cx, 0);
    path.cubicTo(0, 0, 0, size.height * 0.55, cx, size.height * 0.55);
    path.cubicTo(
        size.width, size.height * 0.55, size.width, 0, cx, 0);
    path.lineTo(cx, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final holePaint = Paint()..color = const Color(0xFF5aaa85);
    canvas.drawCircle(
      Offset(cx, size.height * 0.28),
      size.width * 0.22,
      holePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
