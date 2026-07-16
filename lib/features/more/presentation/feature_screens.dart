import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/main_tabs.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../payments/data/invoices_repository.dart';
import '../../messages/data/messages_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _policy;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppConfig.usesLaravelAuth) {
      setState(() => _loading = false);
      return;
    }
    final result = await ref.read(notificationsRepositoryProvider).list();
    if (!mounted) return;
    setState(() {
      _items = result.items;
      _policy = result.policy;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.usesLaravelAuth) {
      return const AccountOverviewScreen();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Notifications'),
        if (_policy != null)
          Card(
            child: ListTile(
              title: const Text('Privacy policy'),
              subtitle: Text((_policy!['note'] ?? 'Push previews omit PII.').toString()),
            ),
          ),
        if (_items.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No notifications'),
              subtitle: Text('Staff updates will appear here without PII in push previews.'),
            ),
          )
        else
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text((item['title'] ?? 'Update').toString()),
                subtitle: Text((item['body'] ?? '').toString()),
              ),
            ),
      ],
    );
  }
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (AppConfig.usesLaravelAuth) {
        // Prefer Laravel advisor threads when on Sanctum builds.
        final threads = await ref.read(messagesRepositoryProvider).threads();
        if (!mounted) return;
        if (threads.isEmpty) {
          await ref.read(messagesRepositoryProvider).createThread(
                subject: 'Advisor help',
                body: 'Hello — I need assistance with my tax year workspace.',
              );
        }
        if (mounted) context.go('/chat');
        return;
      }
      if (mounted) context.go('/tessa');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class TessaScreen extends ConsumerStatefulWidget {
  const TessaScreen({super.key});

  @override
  ConsumerState<TessaScreen> createState() => _TessaScreenState();
}

class _TessaScreenState extends ConsumerState<TessaScreen> {
  final _controller = TextEditingController();
  final _messages = <(bool isUser, String text)>[];
  dynamic _conversationId;
  bool _ready = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final portal = ref.read(portalRepositoryProvider);
      final existing = await portal.listConversations();
      Map<String, dynamic> convo;
      if (existing.isNotEmpty) {
        convo = existing.first;
      } else {
        convo = await portal.createConversation(title: 'Mobile TaxPro Assist');
      }
      final id = convo['id'];
      if (id != null) {
        final full = await portal.getConversation(id);
        final history = (full?['messages'] as List?) ?? const [];
        for (final m in history) {
          if (m is! Map) continue;
          final role = (m['role'] ?? '').toString();
          final content = (m['content'] ?? '').toString();
          if (content.isEmpty) continue;
          _messages.add((role == 'user', content));
        }
      }
      if (_messages.isEmpty) {
        _messages.add((
          false,
          'Hi — I am Tessa AI, your MKG Tax assistant. Ask about organizers, documents, deductions, or refunds.',
        ));
      }
      if (mounted) {
        setState(() {
          _conversationId = id;
          _ready = true;
        });
      }
    } catch (e) {
      _messages.add((false, 'Could not connect to AI assistant: ${ApiErrorMapper.map(e)}'));
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation not ready yet.')),
      );
      return;
    }
    setState(() {
      _messages.add((true, text));
      _controller.clear();
      _sending = true;
    });
    try {
      final reply = await ref.read(portalRepositoryProvider).sendAiMessage(_conversationId, text);
      if (mounted) setState(() => _messages.add((false, reply)));
    } catch (e) {
      if (mounted) setState(() => _messages.add((false, 'Error: ${ApiErrorMapper.map(e)}')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final msg = _messages[i];
              final align = msg.$1 ? Alignment.centerRight : Alignment.centerLeft;
              final color = msg.$1 ? MkgColors.primary : MkgColors.surfaceGrey;
              final textColor = msg.$1 ? Colors.white : MkgColors.dark;
              return Align(
                alignment: align,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                  child: Text(msg.$2, style: TextStyle(color: textColor)),
                ),
              );
            },
          ),
        ),
        if (_sending) const LinearProgressIndicator(minHeight: 2),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask Tessa AI...'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  List<Map<String, dynamic>> _invoices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Map<String, dynamic>> invoices;
      if (AppConfig.usesLaravelAuth) {
        invoices = await ref.read(invoicesRepositoryProvider).list();
      } else {
        invoices = await ref.read(portalRepositoryProvider).listInvoices();
      }
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _loading = false;
      });
    }
  }

  Future<void> _checkout(Map<String, dynamic> inv) async {
    final id = inv['id']?.toString();
    if (id == null || !AppConfig.usesLaravelAuth) {
      await launchUrl(
        Uri.parse('${AppConfig.webRoot}/payments'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    final session = await ref.read(invoicesRepositoryProvider).checkout(
          id,
          idempotencyKey: 'mobile-$id-${DateTime.now().millisecondsSinceEpoch}',
        );
    if (!mounted) return;
    final url = session?['hosted_checkout_url']?.toString() ??
        session?['checkout_url']?.toString() ??
        session?['url']?.toString();
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (session?['status'] ?? session?['message'] ?? 'Hosted checkout required — open web payments.').toString(),
        ),
      ),
    );
    await launchUrl(
      Uri.parse('${AppConfig.webRoot}/payments'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Invoices & payments'),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('${AppConfig.webRoot}/payments'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open hosted payments on web'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (_invoices.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No invoices yet'),
                subtitle: Text('Technology fees and prep invoices will show here.'),
              ),
            )
          else
            for (final inv in _invoices)
              Card(
                child: ListTile(
                  title: Text(
                    (inv['description'] ?? inv['title'] ?? 'Invoice #${inv['id'] ?? ''}').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Status: ${(inv['status'] ?? 'unknown')} · '
                    'Amount: ${inv['amount_cents'] != null ? '\$${((inv['amount_cents'] as num) / 100).toStringAsFixed(2)}' : (inv['amount'] ?? inv['total'] ?? '—')}',
                  ),
                  trailing: StatusChip(
                    label: (inv['status'] ?? 'open').toString(),
                    color: (inv['status']?.toString().toLowerCase() == 'paid')
                        ? MkgColors.green
                        : MkgColors.orange,
                  ),
                  onTap: () => _checkout(inv),
                ),
              ),
        ],
      ),
    );
  }
}

class BookkeepingScreen extends StatelessWidget {
  const BookkeepingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Bookkeeping'),
        Card(child: ListTile(title: Text('Monthly close'), subtitle: Text('Complete intake on web for full workflow'), trailing: Icon(Icons.chevron_right))),
        Card(child: ListTile(title: Text('Transactions to categorize'), subtitle: Text('Synced from portal when available'), trailing: Icon(Icons.chevron_right))),
      ],
    );
  }
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Tax tools'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calculate_outlined, color: MkgColors.primary),
            title: const Text('Paycheck & W-4 estimates'),
            subtitle: const Text('Server tax tables via /api/v1 (estimate only)'),
            onTap: () => context.go('/payroll-tools'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined, color: MkgColors.primary),
            title: const Text('Refund advance calculator'),
            subtitle: const Text('Uses /api/loans/calculate'),
            onTap: () => context.go('/financial'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.track_changes_outlined, color: MkgColors.primary),
            title: const Text('Refund tracker'),
            onTap: () => context.go('/refund-tracker'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.open_in_browser, color: MkgColors.primary),
            title: const Text('More calculators on web'),
            subtitle: const Text('Budget, paycheck, overtime, withholding'),
            onTap: () => launchUrl(
              Uri.parse('${AppConfig.webRoot}/dashboard'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
      ],
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Support'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.smart_toy_outlined, color: MkgColors.primary),
            title: const Text('Tessa AI'),
            subtitle: const Text('Replaces legacy chat'),
            onTap: () => context.go('/tessa'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language, color: MkgColors.primary),
            title: const Text('Open web portal'),
            onTap: () => launchUrl(
              Uri.parse('https://financemkgtax.com'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.phone, color: MkgColors.primary),
            title: Text('Call office'),
            subtitle: Text('Use contact info from your engagement letter'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: MkgColors.primary),
            title: const Text('Connection info'),
            subtitle: Text(AppConfig.authModeLabel),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _ssn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _phone = TextEditingController(text: user?.phone ?? '');
    _address = TextEditingController(text: user?.address ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _state = TextEditingController(text: user?.state ?? '');
    _zip = TextEditingController(text: user?.zipCode ?? '');
    _ssn = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _ssn.dispose();
    super.dispose();
  }

  Future<void> _submitKyc() async {
    setState(() => _saving = true);
    try {
      final portal = ref.read(portalRepositoryProvider);
      final updated = await portal.submitKyc({
        'role': 'client',
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim().toUpperCase(),
        'zipCode': _zip.text.trim(),
      });
      final digits = _ssn.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 9) {
        await portal.saveSsn(digits);
      }
      final user = PortalUser.fromJson(updated);
      await ref.read(authProvider.notifier).setUser(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile submitted for review.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: MkgColors.lightPrimary,
            child: Icon(Icons.person, size: 48, color: MkgColors.primary),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(user?.displayName ?? 'Client', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        Center(child: Text(user?.email ?? '', style: const TextStyle(color: MkgColors.textGrey))),
        const SizedBox(height: 8),
        Center(child: StatusChip(label: 'KYC: ${user?.kycStatus ?? 'unknown'}', color: MkgColors.orange)),
        if (user?.approvalStatus != null) ...[
          const SizedBox(height: 6),
          Center(child: StatusChip(label: 'Approval: ${user!.approvalStatus}', color: MkgColors.primary)),
        ],
        if (user?.kycStatus == 'submitted' && user?.approvalStatus == 'pending') ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFFFF8E1),
            child: const ListTile(
              leading: Icon(Icons.hourglass_top, color: MkgColors.orange),
              title: Text('Profile under review'),
              subtitle: Text('You will be notified once approved.'),
            ),
          ),
        ],
        const SectionHeader('KYC / profile details'),
        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: 10),
        TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _state, decoration: const InputDecoration(labelText: 'State'), textCapitalization: TextCapitalization.characters)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _zip, decoration: const InputDecoration(labelText: 'ZIP'), keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ssn,
          decoration: InputDecoration(
            labelText: user?.last4ssn != null ? 'SSN (saved ••••${user!.last4ssn})' : 'Full SSN (optional)',
          ),
          keyboardType: TextInputType.number,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submitKyc,
          child: Text(_saving ? 'Submitting…' : 'Submit profile for review'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class EngagementsScreen extends StatelessWidget {
  const EngagementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Engagements'),
        Card(
          child: ListTile(
            title: const Text('Active tax engagement'),
            subtitle: const Text('Managed with your assigned preparer'),
            trailing: const StatusChip(label: 'Active', color: MkgColors.green),
          ),
        ),
      ],
    );
  }
}

class RefundTrackerScreen extends StatelessWidget {
  const RefundTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Refund tracker'),
        const Text('Check official IRS and state status (same links as the web portal).'),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance, color: MkgColors.primary),
            title: const Text('IRS Where\'s My Refund'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://www.irs.gov/refunds'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.map_outlined, color: MkgColors.primary),
            title: const Text('California FTB refund status'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://www.ftb.ca.gov/about-ftb/newsroom/news-articles/wheres-my-refund.html'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined, color: MkgColors.primary),
            title: const Text('Refund advance calculator'),
            onTap: () => context.go('/financial'),
          ),
        ),
      ],
    );
  }
}
