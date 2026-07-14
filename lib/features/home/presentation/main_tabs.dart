import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

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
      final quote = await ref.read(portalRepositoryProvider).calculateLoan(value);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _calculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _calculating = false;
      });
    }
  }

  Future<void> _apply() async {
    final value = num.tryParse(_amount.text.replaceAll(',', '').trim());
    if (value == null) return;
    setState(() => _applying = true);
    try {
      await ref.read(portalRepositoryProvider).applyLoan({
        'amount': value,
        ...?_quote,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan application submitted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
      ('Secure Messages', 'Open Messages', MkgColors.primary),
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
                            if (a.$1.contains('Messages')) {
                              context.go('/messages');
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

class BankingScreen extends StatelessWidget {
  const BankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Banking'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined, color: MkgColors.primary),
            title: const Text('Link bank (Plaid)'),
            subtitle: const Text('Complete on web portal for Plaid Link'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => context.go('/support'),
          ),
        ),
        const Card(
          child: ListTile(
            title: Text('Direct deposit'),
            subtitle: Text('Routing & account collected during organizer / profile'),
          ),
        ),
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
