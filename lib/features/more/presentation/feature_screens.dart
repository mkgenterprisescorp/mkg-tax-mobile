import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../home/presentation/main_tabs.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../payments/data/invoices_repository.dart';
import '../../messages/data/messages_repository.dart';
import '../../tessa/data/tessa_repository.dart';
import '../../address/presentation/address_autofill_fields.dart';

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
  List<Map<String, dynamic>> _nextActions = const [];
  dynamic _conversationId;
  String? _workspaceId;
  String _prepType = 'personal';
  List<String> _jurisdictions = const ['CA'];
  int _taxYear = 2025;
  bool _ready = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final tessa = ref.read(tessaRepositoryProvider);
      try {
        await ref.read(taxYearProvider.notifier).refreshWorkspace();
      } catch (_) {
        // Workspace optional when unauthenticated.
      }
      final tax = ref.read(taxYearProvider);
      _workspaceId = tax.workspace?.workspaceId;
      _taxYear = tax.selectedYear ?? tax.currentFilingYear ?? 2025;

      final existing = await tessa.listConversations();
      Map<String, dynamic> convo;
      if (existing.isNotEmpty) {
        convo = existing.first;
      } else {
        convo = await tessa.createConversation(title: 'Mobile TaxPro Assist');
      }
      final id = convo['id'];
      if (id != null) {
        final full = await tessa.getConversation(id);
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
          'Hi — I am Tessa AI, your MKG Tax assistant. Ask about federal 1040, CA 540 / business forms, or nationwide state intake. Tap a chip to run estimate/intake automation; you verify before anything becomes filing data.',
        ));
      }
      // Prefetch form-automation nextActions from live workspace when available.
      try {
        final analysis = await tessa.analyzeForms(
          prepType: _prepType,
          jurisdictions: _jurisdictions,
          taxYear: _taxYear,
          workspaceId: _workspaceId,
        );
        final actions = analysis?['next_actions'];
        final plan = analysis?['form_plan'];
        if (plan is Map && plan['jurisdictions'] is List) {
          _jurisdictions = (plan['jurisdictions'] as List)
              .map((e) => '$e'.toUpperCase())
              .where((e) => e.length == 2)
              .toList();
          if (_jurisdictions.isEmpty) _jurisdictions = const ['CA'];
        }
        if (actions is List && mounted) {
          _nextActions = actions
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Assist endpoint optional when offline / unauthenticated.
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
      final result = await ref.read(tessaRepositoryProvider).sendMessage(
            _conversationId,
            text,
            prepType: _prepType,
            jurisdictions: _jurisdictions,
            taxYear: _taxYear,
            workspaceId: _workspaceId,
          );
      if (!mounted) return;
      setState(() {
        _messages.add((false, result.reply));
        if (result.nextActions.isNotEmpty) {
          _nextActions = result.nextActions;
        }
        if (result.formPlan['jurisdictions'] is List) {
          final j = (result.formPlan['jurisdictions'] as List)
              .map((e) => '$e'.toUpperCase())
              .where((e) => e.length == 2)
              .toList();
          if (j.isNotEmpty) _jurisdictions = j;
        }
        if (result.nextActions.isNotEmpty) {
          final labels = result.nextActions
              .map((a) => '${a['type'] ?? 'action'}')
              .take(4)
              .join(' · ');
          _messages.add((false, 'Suggested automation: $labels — tap a chip to run it.'));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _messages.add((false, 'Error: ${ApiErrorMapper.map(e)}')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _messages.add((true, 'Run ${_actionLabel(action)}'));
    });
    try {
      final result = await ref.read(tessaRepositoryProvider).executeNextAction(
            action,
            workspaceId: _workspaceId,
            prepType: _prepType,
            jurisdictions: _jurisdictions,
            taxYear: _taxYear,
          );
      if (!mounted) return;
      setState(() {
        _messages.add((
          false,
          result.ok
              ? '✓ ${result.summary}'
              : '✗ ${result.summary}',
        ));
        if (result.payload['next_actions'] is List) {
          _nextActions = (result.payload['next_actions'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add((false, 'Automation error: ${ApiErrorMapper.map(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _actionLabel(Map<String, dynamic> action) {
    final type = '${action['type'] ?? 'action'}';
    final form = action['form_id'] ?? action['jurisdiction'] ?? action['primary_form_id'];
    if (form != null && '$form'.isNotEmpty) return '$type ($form)';
    return type;
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
        if (_nextActions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              scrollDirection: Axis.horizontal,
              itemCount: _nextActions.length.clamp(0, 8),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final action = _nextActions[i];
                return ActionChip(
                  label: Text(_actionLabel(action), style: const TextStyle(fontSize: 12)),
                  onPressed: _sending ? null : () => _runAction(action),
                );
              },
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask Tessa about 1040, CA forms, or state intake...',
                    ),
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
  List<Map<String, dynamic>> _feeSchedule = const [];
  final Set<String> _selectedFees = {};
  bool _loading = true;
  bool _checkingOut = false;
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
      List<Map<String, dynamic>> fees = const [];
      if (AppConfig.usesLaravelAuth) {
        final repo = ref.read(invoicesRepositoryProvider);
        invoices = await repo.list();
        fees = await repo.feeSchedule();
      } else {
        invoices = await ref.read(portalRepositoryProvider).listInvoices();
      }
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _feeSchedule = fees;
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

  Future<void> _openHostedUrl(String? url) async {
    final uri = (url != null && url.isNotEmpty)
        ? AppConfig.rewriteLegacyPortalUri(Uri.parse(url))
        : Uri.parse(AppConfig.paymentsWebUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _checkout(Map<String, dynamic> inv) async {
    final id = inv['id']?.toString();
    if (id == null || !AppConfig.usesLaravelAuth) {
      await _openHostedUrl(null);
      return;
    }
    setState(() => _checkingOut = true);
    try {
      final session = await ref.read(invoicesRepositoryProvider).checkout(
            id,
            idempotencyKey: 'mobile-$id-${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      final url = session?['hosted_checkout_url']?.toString() ??
          session?['checkout_url']?.toString() ??
          session?['url']?.toString();
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (session?['status'] ?? session?['message'] ?? 'Hosted Stripe Checkout required.').toString(),
            ),
          ),
        );
      }
      await _openHostedUrl(url);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _checkoutSelectedFees() async {
    if (!AppConfig.usesLaravelAuth || _selectedFees.isEmpty) return;
    setState(() => _checkingOut = true);
    try {
      final services = [
        for (final id in _selectedFees) {'service_id': id, 'form_count': 0},
      ];
      final session = await ref.read(invoicesRepositoryProvider).feeCheckout(
            services: services,
            taxYear: ref.read(taxYearProvider).selectedYear ??
                ref.read(taxYearProvider).currentFilingYear,
            idempotencyKey: 'mobile-fee-${DateTime.now().millisecondsSinceEpoch}',
          );
      if (!mounted) return;
      final url = session?['hosted_checkout_url']?.toString() ?? session?['url']?.toString();
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (session?['message'] ?? 'Unable to start hosted Stripe Checkout.').toString(),
            ),
          ),
        );
        return;
      }
      await _openHostedUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorMapper.map(e))),
      );
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Fee schedule'),
          const Text(
            'Pay technology and prep fees through hosted Stripe Checkout. Card details never enter this app.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else ...[
            if (_feeSchedule.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('Fee schedule unavailable'),
                  subtitle: Text('Pull to refresh, or open hosted payments on web.'),
                ),
              )
            else
              for (final fee in _feeSchedule)
                CheckboxListTile(
                  value: _selectedFees.contains(fee['id']?.toString()),
                  onChanged: _checkingOut
                      ? null
                      : (v) {
                          final id = fee['id']?.toString();
                          if (id == null) return;
                          setState(() {
                            if (v == true) {
                              _selectedFees.add(id);
                            } else {
                              _selectedFees.remove(id);
                            }
                          });
                        },
                  title: Text(
                    (fee['name'] ?? fee['id'] ?? 'Fee').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    (fee['priceFormatted'] ??
                            fee['price_formatted'] ??
                            (fee['price'] != null
                                ? '\$${((fee['price'] as num) / 100).toStringAsFixed(2)}'
                                : ''))
                        .toString(),
                  ),
                ),
            if (_selectedFees.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _checkingOut ? null : _checkoutSelectedFees,
                child: Text(_checkingOut ? 'Opening Stripe…' : 'Pay selected fees (Stripe Checkout)'),
              ),
            ],
            const SizedBox(height: 20),
            const SectionHeader('Invoices & payments'),
            OutlinedButton.icon(
              onPressed: () => _openHostedUrl(null),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open payments on mkgtaxconsultants.com'),
            ),
            const SizedBox(height: 12),
            if (_invoices.isEmpty)
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
                    onTap: _checkingOut ? null : () => _checkout(inv),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Financial Tools hub — paycheck/W-4, refund estimate, advances, payments, savings, checklist.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  static const _tiles = <(IconData, String, String, String)>[
    (Icons.calculate_outlined, 'Paycheck & W-4', 'Withholding estimates', '/payroll-tools'),
    (Icons.savings_outlined, 'Refund estimator', 'Federal estimate · organizer', '/refund-advance/estimate'),
    (Icons.payments_outlined, 'Refund advance loans', '0% & 36% APR · TILA', '/refund-advance'),
    (Icons.receipt_long_outlined, 'Payments', 'Fee schedule · invoices', '/billing'),
    (Icons.tips_and_updates_outlined, 'Tax savings', 'Credits & deductions checklist', '/tax-savings'),
    (Icons.checklist_outlined, 'Things to bring', 'Appointment document list', '/things-to-bring'),
    (Icons.description_outlined, 'Autofill Form 1040', 'From Tax Organizer', '/organizer/form-1040'),
    (Icons.edit_note, 'Form 1040-X', 'Amended federal return', '/organizer'),
    (Icons.map_outlined, 'CA Form 540 calculator', 'Tax & refund · FTB lines', '/ca-540'),
    (Icons.track_changes_outlined, 'Refund tracker', 'IRS & FTB status links', '/refund-tracker'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text('Financial Tools', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Calculators, advances, payments, and appointment prep — all in one place.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, i) {
            final t = _tiles[i];
            return Material(
              color: MkgColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go(t.$4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(t.$1, color: MkgColors.primary),
                      const Spacer(),
                      Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(t.$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.open_in_browser, color: MkgColors.primary),
            title: const Text('More calculators on web'),
            subtitle: const Text('Budget, overtime, full paycheck tools'),
            onTap: () => launchUrl(
              Uri.parse('${AppConfig.portalRoot}/dashboard'),
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
            subtitle: const Text('Chat with your tax assistant'),
            onTap: () => context.go('/tessa'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language, color: MkgColors.primary),
            title: const Text('Open web portal'),
            onTap: () => launchUrl(
              Uri.parse(AppConfig.portalRoot),
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
  late final TextEditingController _ssn;
  late Map<String, dynamic> _addressData;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _phone = TextEditingController(text: user?.phone ?? '');
    _ssn = TextEditingController();
    _addressData = {
      'address': user?.address ?? '',
      'city': user?.city ?? '',
      'state': user?.state ?? '',
      'zip': user?.zipCode ?? '',
      'apartment': '',
    };
  }

  @override
  void dispose() {
    _phone.dispose();
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
        'address': '${_addressData['address'] ?? ''}'.trim(),
        'city': '${_addressData['city'] ?? ''}'.trim(),
        'state': '${_addressData['state'] ?? ''}'.trim().toUpperCase(),
        'zipCode': '${_addressData['zip'] ?? ''}'.trim(),
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
        AddressAutofillFields(
          data: _addressData,
          onChanged: (key, value) => setState(() => _addressData[key] = value),
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
