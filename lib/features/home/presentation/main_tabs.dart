import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../banking/data/banking_connections_repository.dart';
import '../../entities/data/entities_repository.dart';
import '../../refund_advance/data/refund_advance_repository.dart';

class FinancialScreen extends ConsumerStatefulWidget {
  const FinancialScreen({super.key});

  @override
  ConsumerState<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends ConsumerState<FinancialScreen> {
  final _amount = TextEditingController(text: '3000');
  Map<String, dynamic>? _quote;
  bool _calculating = false;
  bool _applying = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final value = num.tryParse(_amount.text.replaceAll(',', '').trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid refund advance amount');
      return;
    }
    setState(() {
      _calculating = true;
      _error = null;
    });
    try {
      final quote = await ref.read(refundAdvanceRepositoryProvider).calculateLoan(value);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _calculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _calculating = false;
      });
    }
  }

  Future<void> _apply() async {
    final value = num.tryParse(_amount.text.replaceAll(',', '').trim());
    if (value == null) return;
    setState(() => _applying = true);
    try {
      await ref.read(refundAdvanceRepositoryProvider).apply({
        'amount': value,
        'tilaSignedName': 'Mobile applicant',
        'tierLabel': 'custom',
        'expectedRefund': value,
        ...?_quote,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan application submitted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = const [
      ('Mortgage', Icons.home_work_outlined),
      ('Auto', Icons.directions_car_outlined),
      ('IRA / 401k', Icons.savings_outlined),
      ('Small Business', Icons.storefront_outlined),
      ('Self Directed IRA', Icons.account_balance_wallet_outlined),
      ('Credit Strong', Icons.credit_score_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF003F7A), MkgColors.primary],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial services', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 8),
              Text(
                'Refund advances & wealth tools',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SectionHeader('Refund advance calculator'),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Desired advance amount',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _calculating ? null : _calculate,
          icon: _calculating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.calculate_outlined),
          label: Text(_calculating ? 'Calculating…' : 'Calculate'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: MkgColors.red)),
        ],
        if (_quote != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quote', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final entry in _quote!.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _applying ? null : _apply,
                    child: Text(_applying ? 'Submitting…' : 'Apply for advance'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SectionHeader('Products'),
        ...products.map(
          (p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: MkgColors.lightPrimary,
                child: Icon(p.$2, color: MkgColors.primary),
              ),
              title: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Ask your advisor or open web Financials'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/support'),
            ),
          ),
        ),
      ],
    );
  }
}

class AccountOverviewScreen extends StatelessWidget {
  const AccountOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = const [
      ('IRS Funding Update', 'Check refund tracker', MkgColors.green),
      ('E-File Status', 'See tax return on dashboard', MkgColors.primary),
      ('Secure Messages', 'Open Tessa AI', MkgColors.primary),
      ('Profile / KYC', 'Keep verification current', MkgColors.orange),
    ];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Alerts'), Tab(text: 'Activity')]),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final a in alerts)
                      Card(
                        child: ListTile(
                          title: Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(a.$2),
                          trailing: StatusChip(label: 'Live', color: a.$3),
                          onTap: () {
                            if (a.$1.contains('Messages') || a.$1.contains('Secure')) {
                              context.go('/tessa');
                            } else if (a.$1.contains('Profile')) {
                              context.go('/profile');
                            } else if (a.$1.contains('IRS') || a.$1.contains('E-File')) {
                              context.go('/refund-tracker');
                            } else {
                              context.go('/forms');
                            }
                          },
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Card(child: ListTile(title: Text('Portal sync'), subtitle: Text('Pull to refresh on Dashboard for latest returns'))),
                    Card(child: ListTile(title: Text('Documents'), subtitle: Text('Upload W-2 / 1099 from Documents tab'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BankingScreen extends ConsumerStatefulWidget {
  const BankingScreen({super.key});

  @override
  ConsumerState<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends ConsumerState<BankingScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _checking = false;
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
      final entity = await ref.read(entitiesRepositoryProvider).ensurePrimaryEntity();
      final entityId = entity?['id']?.toString();
      if (entityId == null) {
        setState(() {
          _loading = false;
          _error = 'Sign in to view banking connection status.';
        });
        return;
      }
      final status = await ref.read(bankingConnectionsRepositoryProvider).connections(entityId);
      if (!mounted) return;
      setState(() {
        _status = status;
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

  String _statusLabel() {
    final connection = _status?['connection'];
    if (connection is Map && connection['status_label'] != null) {
      return connection['status_label'].toString();
    }
    final raw = connection is Map ? '${connection['status'] ?? ''}' : '';
    return switch (raw) {
      'not_connected' => 'Not connected',
      'pending_kyc' => 'Verification in progress',
      'active' => 'Connected',
      'revoked' => 'Disconnected',
      _ => 'Not connected',
    };
  }

  static const _relayApplyFallback = 'https://app.relayfi.com/register?referralcode=mkgtax';

  String _providerLabel() {
    final labeled = _status?['provider_label']?.toString();
    if (labeled != null &&
        labeled.isNotEmpty &&
        labeled != 'unset' &&
        labeled != 'null' &&
        labeled != 'No banking partner') {
      return labeled;
    }
    return 'PNC · Relay Financial';
  }

  List<Map<String, dynamic>> get _accounts {
    final raw = _status?['accounts'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get _partners {
    final raw = _status?['partners'];
    if (raw is! List) {
      return const [
        {'id': 'pnc', 'name': 'PNC', 'account_scope': 'personal', 'role': 'Personal banking accounts'},
        {
          'id': 'relay',
          'name': 'Relay Financial',
          'account_scope': 'business',
          'role': 'Business banking accounts',
          'apply_url': _relayApplyFallback,
        },
      ];
    }
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic>? get _creditCard {
    final raw = _status?['credit_card'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {
      'partner_name': 'Relay Financial',
      'title': 'Deposit & balance–based business credit cards',
      'summary':
          'Approvals and limits are driven primarily by business cash flow and deposits — not traditional personal credit scoring.',
      'minimum_starting_credit_limit_usd': 10000,
      'minimum_avg_monthly_deposits_usd': 20000,
      'apply_url': _relayApplyFallback,
      'apply_label': 'Apply with Relay Financial',
      'highlights': const [
        'Minimum starting credit limit: \$10,000 (for approved applicants)',
        'Average monthly business deposits of \$20,000+ help qualify',
        'Includes deposits into MKG brokerage/agent accounts',
        'External bank account balances are considered',
      ],
      'disclaimer':
          'Credit decisions are made by Relay Financial. Approval and limits are not guaranteed. MKG is not a bank.',
    };
  }

  String? _safeHttps(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return null;
    return url;
  }

  String get _relayApplyUrl =>
      _safeHttps(_status?['business_apply_url']?.toString()) ??
      _safeHttps(_creditCard?['apply_url']?.toString()) ??
      _relayApplyFallback;

  String? get _webManageUrl =>
      _safeHttps(_status?['web_manage_url']?.toString()) ?? _relayApplyUrl;

  Future<void> _openUrl(String url) async {
    final safe = _safeHttps(url);
    if (safe == null) return;
    await launchUrl(Uri.parse(safe), mode: LaunchMode.externalApplication);
  }

  Future<void> _checkAvailability() async {
    final entity = await ref.read(entitiesRepositoryProvider).ensurePrimaryEntity();
    final entityId = entity?['id']?.toString();
    if (entityId == null) return;
    setState(() => _checking = true);
    try {
      final result = await ref.read(bankingConnectionsRepositoryProvider).beginKyc(entityId);
      if (!mounted) return;
      final message = (result?['message'] ??
              'Continue with Relay Financial for business banking. Approval is not guaranteed.')
          .toString();
      final manageUrl = result?['web_manage_url']?.toString() ?? _relayApplyUrl;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _openUrl(manageUrl);
      await _load();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _accountSubtitle(Map<String, dynamic> account) {
    final rawType = (account['account_type'] ?? 'account').toString().trim();
    final type = rawType.isEmpty
        ? 'Account'
        : '${rawType[0].toUpperCase()}${rawType.substring(1)}';
    final last4 = (account['account_last4'] ?? '••••').toString();
    final verification = (account['verification_status'] ?? '').toString();
    final verified = account['is_verified'] == true || verification == 'verified';
    final status = verified ? 'Verified' : (verification.isEmpty ? 'Pending' : verification.replaceAll('_', ' '));
    return '$type ·····$last4 · $status';
  }

  @override
  Widget build(BuildContext context) {
    final disclaimer = (_status?['disclaimer'] ??
            'Banking products are provided by PNC (personal) and Relay Financial (business). MKG Tax Consultants is not a bank.')
        .toString();
    final headline = (_status?['headline'] ?? 'Business banking with Relay Financial').toString();
    final message = (_status?['message'] ??
            'Business accounts are with Relay Financial; personal accounts are with PNC.')
        .toString();
    final nextStep = _status?['next_step']?.toString();
    final accounts = _accounts;
    final partners = _partners;
    final creditCard = _creditCard;
    final highlights = creditCard?['highlights'];
    final highlightLines = highlights is List
        ? highlights.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Banking'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: MkgColors.primary),
            title: const Text('Not a bank'),
            subtitle: Text(disclaimer),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Card(
            child: ListTile(
              title: Text(_error!),
              trailing: TextButton(onPressed: _load, child: const Text('Retry')),
            ),
          )
        else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_outlined, color: MkgColors.primary),
              title: Text(headline),
              subtitle: Text(
                'Partners: ${_providerLabel()} · Status: ${_statusLabel()}\n\n$message'
                '${nextStep != null && nextStep.isNotEmpty ? '\n\n$nextStep' : ''}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Configured partners', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...partners.map((partner) {
            final scope = (partner['account_scope'] ?? '').toString();
            final role = (partner['role'] ?? '').toString();
            final name = (partner['name'] ?? 'Partner').toString();
            return Card(
              child: ListTile(
                leading: Icon(
                  scope == 'personal' ? Icons.person_outline : Icons.business_outlined,
                  color: MkgColors.primary,
                ),
                title: Text(name),
                subtitle: Text(
                  [
                    if (scope.isNotEmpty) scope[0].toUpperCase() + scope.substring(1),
                    if (role.isNotEmpty) role,
                  ].join(' · '),
                ),
              ),
            );
          }),
          if (creditCard != null) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (creditCard['title'] ?? 'Business credit cards').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (creditCard['summary'] ??
                              'Deposit-based business credit cards through Relay Financial.')
                          .toString(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Min. starting limit: \$${(creditCard['minimum_starting_credit_limit_usd'] ?? 10000)} · '
                      'Target deposits: \$${(creditCard['minimum_avg_monthly_deposits_usd'] ?? 20000)}+/mo',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    if (highlightLines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...highlightLines.take(4).map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $line'),
                            ),
                          ),
                    ],
                    if (creditCard['disclaimer'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        creditCard['disclaimer'].toString(),
                        style: const TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Linked accounts', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...accounts.map(
              (account) => Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance, color: MkgColors.primary),
                  title: Text((account['institution_name'] ?? 'Bank account').toString()),
                  subtitle: Text(_accountSubtitle(account)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openUrl(_relayApplyUrl),
            icon: const Icon(Icons.open_in_new),
            label: Text((creditCard?['apply_label'] ?? 'Apply with Relay Financial').toString()),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _checking ? null : _checkAvailability,
            child: Text(_checking ? 'Starting…' : 'Start Relay business onboarding'),
          ),
          if (_webManageUrl != null && _webManageUrl != _relayApplyUrl) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openUrl(_webManageUrl!),
              child: const Text('Open banking intake on web'),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'No bank credentials are collected in-app. Live ACH/card money movement is not enabled here. Approval is not guaranteed.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

class BlogsScreen extends StatelessWidget {
  const BlogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionHeader('Learn'),
        Card(child: ListTile(title: Text('Tax filing tips'), subtitle: Text('See video tutorials on the web portal'))),
        Card(child: ListTile(title: Text('Document checklist'), subtitle: Text('W-2, 1099, ID, prior year return'))),
      ],
    );
  }
}
