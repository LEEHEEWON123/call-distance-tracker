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
    final requestingPhone = ref.watch(requestingPhoneProvider);

    return Container(
      color: const Color(0xFFf2f2f2),
      child: Column(
        children: [
          _SearchBar(query: query, ref: ref),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(child: Text('연락처가 없습니다.'));
                }

                // 요청 중인 연락처 분리
                final requesting = requestingPhone != null
                    ? contacts.where((c) => c.phones.any(
                        (p) => _normalise(p.number) == _normalise(requestingPhone))).toList()
                    : <Contact>[];
                final others = contacts.where((c) => !requesting.contains(c)).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    // ── 요청 중 섹션 ──
                    if (requesting.isNotEmpty) ...[
                      const _SectionLabel(label: '요청 중'),
                      ...requesting.map((c) => _ContactCard(
                        contact: c,
                        index: contacts.indexOf(c),
                        isRequesting: true,
                        onCancel: () {
                          ref.read(requestingPhoneProvider.notifier).state = null;
                          ref.read(activeTokenProvider.notifier).state = null;
                        },
                      )),
                      const _SectionLabel(label: '연락처'),
                    ],
                    // ── 전체 연락처 ──
                    ...others.asMap().entries.map((e) => _ContactCard(
                      contact: e.value,
                      index: e.key,
                      isRequesting: false,
                    )),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF5aaa85)),
              ),
              error: (e, _) => Center(
                child: Text('연락처를 불러올 수 없습니다.\n$e',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _normalise(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');
}

// ── 섹션 헤더 ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF96a3b4),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── 검색바 ───────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final String query;
  final WidgetRef ref;

  const _SearchBar({required this.query, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFf2f2f2),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
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
          fillColor: const Color(0xFFf2f2f2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFf2f2f2), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFf2f2f2), width: 1.5),
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

// ── 연락처 카드 ──────────────────────────────────────────
class _ContactCard extends ConsumerWidget {
  final Contact contact;
  final int index;
  final bool isRequesting;
  final VoidCallback? onCancel;

  const _ContactCard({
    required this.contact,
    required this.index,
    required this.isRequesting,
    this.onCancel,
  });

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
        color: isRequesting ? const Color(0xFFFFFAF6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isRequesting
            ? Border.all(color: const Color(0xFFf5a060).withValues(alpha: 0.35), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 좌측 주황 라인 (요청 중)
          if (isRequesting)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
          Padding(
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
                // 이름 + 번호 / 요청 중 배지
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
                      const SizedBox(height: 3),
                      if (isRequesting)
                        _RequestingBadge()
                      else if (phone != null)
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8e8e93),
                          ),
                        ),
                    ],
                  ),
                ),
                // 우측 버튼
                if (isRequesting)
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFf0f0f0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFFb0bac8)),
                    ),
                  )
                else if (phone != null)
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
                          colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFe07830).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on,
                          size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmDialog(
      BuildContext context, WidgetRef ref, String phoneNumber) async {
    final colors = _avatarGradients[index % _avatarGradients.length];
    final initial = contact.displayName.isNotEmpty
        ? contact.displayName[0].toUpperCase()
        : '?';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFe0e0e0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 아바타
            Container(
              width: 56, height: 56,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 이름
            Text(
              contact.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1c1c1e),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '위치 공유 요청을\n보낼까요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF96a3b4),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            // 버튼 행
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf2f2f2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF96a3b4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFf5a060), Color(0xFFe07830)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFe07830).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            '요청 보내기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        responderPhone: phoneNumber.replaceAll(RegExp(r'[\s\-]'), ''),
      );

      ref.read(activeTokenProvider.notifier).state = token;
      ref.read(requestingPhoneProvider.notifier).state = phoneNumber;

      final shareText = LocationRequestService.buildShareMessage(token);
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

// ── 요청 중 배지 (깜빡이는 점) ──────────────────────────
class _RequestingBadge extends StatefulWidget {
  @override
  State<_RequestingBadge> createState() => _RequestingBadgeState();
}

class _RequestingBadgeState extends State<_RequestingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFe07830).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: Color(0xFFe07830),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Text(
            '위치 요청 중',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFd07030),
            ),
          ),
        ],
      ),
    );
  }
}
