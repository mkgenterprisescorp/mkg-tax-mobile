import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Advisor Chat hub — TESSA AI + human advisor rooms (portal `/api/chat/rooms`).
class AdvisorChatScreen extends ConsumerStatefulWidget {
  const AdvisorChatScreen({super.key});

  @override
  ConsumerState<AdvisorChatScreen> createState() => _AdvisorChatScreenState();
}

class _AdvisorChatScreenState extends ConsumerState<AdvisorChatScreen> {
  List<Map<String, dynamic>> _rooms = const [];
  bool _loadingRooms = true;
  String? _roomsError;
  dynamic _activeRoomId;
  List<Map<String, dynamic>> _messages = const [];
  bool _loadingMessages = false;
  bool _sending = false;
  final _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRooms());
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loadingRooms = true;
      _roomsError = null;
    });
    try {
      final rooms = await ref.read(portalRepositoryProvider).listChatRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loadingRooms = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roomsError = '$e';
        _loadingRooms = false;
      });
    }
  }

  Future<void> _openRoom(dynamic roomId) async {
    setState(() {
      _activeRoomId = roomId;
      _loadingMessages = true;
      _messages = const [];
    });
    try {
      final msgs = await ref.read(portalRepositoryProvider).chatMessages(roomId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMessages = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _activeRoomId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(portalRepositoryProvider).sendChatMessage(_activeRoomId, text);
      _composer.clear();
      await _openRoom(_activeRoomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _roomTitle(Map<String, dynamic> room) {
    final name = (room['name'] ?? room['title'] ?? room['subject'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final id = room['id'];
    return 'Advisor room #${id ?? '—'}';
  }

  String _messageBody(Map<String, dynamic> m) {
    return (m['content'] ?? m['body'] ?? m['message'] ?? m['text'] ?? '').toString();
  }

  bool _isMine(Map<String, dynamic> m) {
    final role = (m['role'] ?? m['senderRole'] ?? m['from'] ?? '').toString().toLowerCase();
    if (role.contains('client') || role.contains('user') || role == 'me') return true;
    if (m['isMine'] == true || m['mine'] == true) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_activeRoomId != null) {
      return Column(
        children: [
          Material(
            color: Colors.white,
            child: ListTile(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _activeRoomId = null;
                  _messages = const [];
                }),
              ),
              title: const Text('Advisor messages', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Room #$_activeRoomId'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Say hello to your advisor.',
                          style: TextStyle(color: MkgColors.textGrey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = _isMine(m);
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                              decoration: BoxDecoration(
                                color: mine ? MkgColors.primary : MkgColors.surfaceGrey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _messageBody(m),
                                style: TextStyle(color: mine ? Colors.white : MkgColors.dark),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration: const InputDecoration(
                        hintText: 'Message your advisor…',
                        filled: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text('Advisor Chat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Message TESSA AI or your MKG Tax / Finance Advisors team.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 16),
          MkgCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: MkgColors.primary,
                child: Icon(Icons.smart_toy_outlined, color: Colors.white),
              ),
              title: const Text('Ask TESSA AI', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Tax-year aware answers for organizers, documents, and filings.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/tessa'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Human advisor rooms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (_loadingRooms)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_roomsError != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: MkgColors.red),
                title: Text(_roomsError!),
                trailing: TextButton(onPressed: _loadRooms, child: const Text('Retry')),
              ),
            )
          else if (_rooms.isEmpty)
            const MkgCard(
              child: Text(
                'No advisor rooms yet. Contact support or open the web portal to start a conversation with your preparer.',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4),
              ),
            )
          else
            for (final room in _rooms)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.forum_outlined, color: MkgColors.primary),
                  title: Text(_roomTitle(room), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    (room['lastMessage'] ?? room['updatedAt'] ?? room['status'] ?? 'Tap to open').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openRoom(room['id']),
                ),
              ),
          const SizedBox(height: 12),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.support_agent_outlined, color: MkgColors.primary),
                  title: const Text('Support & appointments'),
                  subtitle: const Text('Schedule a call or open a support ticket.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/support'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined, color: MkgColors.primary),
                  title: const Text('Open web portal'),
                  subtitle: const Text('financemkgtax.com messaging & scheduling'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(
                    Uri.parse('https://financemkgtax.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
