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

  String _providerLabel() {
    final labeled = _status?['provider_label']?.toString();
    if (labeled != null && labeled.isNotEmpty && labeled != 'unset' && labeled != 'null') {
      return labeled;
    }
    final connection = _status?['connection'];
    if (connection is Map) {
      final cl = connection['provider_label']?.toString();
      if (cl != null && cl.isNotEmpty && cl != 'unset') return cl;
    }
    final raw = (_status?['provider'] ?? '').toString();
    if (raw.isEmpty || raw == 'unset' || raw == 'null' || raw == 'none') {
      return 'No banking partner';
    }
    return raw == 'plaid' ? 'Plaid' : raw;
  }

  bool get _kycAvailable =>
      _status?['kyc_available'] == true || _status?['available'] == true;

  List<Map<String, dynamic>> get _accounts {
    final raw = _status?['accounts'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String? get _webManageUrl {
    final url = _status?['web_manage_url']?.toString();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return null;
    return url;
  }

  Future<void> _openWebManage() async {
    final url = _webManageUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
              'A regulated banking partner is not configured yet. Tax prep continues without bank linking.')
          .toString();
      final manageUrl = result?['web_manage_url']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      if (manageUrl != null && manageUrl.isNotEmpty) {
        final uri = Uri.tryParse(manageUrl);
        if (uri != null && (uri.isScheme('https') || uri.isScheme('http'))) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
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
            'MKG Tax Consultants / Finance Advisors are not a bank. No money movement is enabled.')
        .toString();
    final headline = (_status?['headline'] ?? 'Business banking is not connected yet').toString();
    final message = (_status?['message'] ??
            'Business bank linking requires an approved regulated partner. MKG is not a bank.')
        .toString();
    final nextStep = _status?['next_step']?.toString();
    final accounts = _accounts;

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
                'Partner: ${_providerLabel()} · Status: ${_statusLabel()}\n\n$message'
                '${nextStep != null && nextStep.isNotEmpty ? '\n\n$nextStep' : ''}',
              ),
              isThreeLine: true,
            ),
          ),
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
          if (_webManageUrl != null)
            FilledButton.icon(
              onPressed: _openWebManage,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Manage bank accounts on web'),
            )
          else if (_kycAvailable)
            FilledButton(
              onPressed: _checking ? null : _checkAvailability,
              child: Text(_checking ? 'Starting…' : 'Begin partner verification'),
            )
          else
            OutlinedButton(
              onPressed: _checking ? null : _checkAvailability,
              child: Text(_checking ? 'Checking…' : 'Check partner availability'),
            ),
          if (_webManageUrl != null && _kycAvailable) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _checking ? null : _checkAvailability,
              child: Text(_checking ? 'Starting…' : 'Start verification'),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'No bank credentials are collected in-app. Live ACH/card movement is not enabled.',
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
