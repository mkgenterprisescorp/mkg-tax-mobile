import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

/// Mobile clone of financemkgtaxpro `/dashboard`.
class FormsListScreen extends ConsumerStatefulWidget {
  const FormsListScreen({super.key});

  @override
  ConsumerState<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends ConsumerState<FormsListScreen> {
  List<Map<String, dynamic>> _returns = const [];
  Map<String, dynamic>? _verification;
  bool _loading = true;
  String? _error;
  bool _creating = false;

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
      final portal = ref.read(portalRepositoryProvider);
      final results = await Future.wait([
        portal.listTaxReturns(),
        portal.verificationStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _returns = results[0] as List<Map<String, dynamic>>;
        _verification = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createReturn() async {
    setState(() => _creating = true);
    try {
      await ref.read(portalRepositoryProvider).createTaxReturn();
      await _load();
      if (mounted) context.go('/organizer');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Map<String, dynamic>? get _current => _returns.isNotEmpty ? _returns.first : null;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final current = _current;
    final taxYear = (current?['year'] ?? current?['taxYear'] ?? DateTime.now().year).toString();
    final status = (current?['status'] ?? 'none').toString();
    final verified = _verification?['verified'] == true;

    final actions = <_DashAction>[
      _DashAction('Tax Organizer', Icons.assignment_outlined, '/organizer', MkgColors.primary),
      _DashAction('Documents', Icons.folder_outlined, '/documents', MkgColors.green),
      _DashAction('Financials', Icons.payments_outlined, '/financial', MkgColors.orange),
      _DashAction('Payments', Icons.receipt_long_outlined, '/billing', MkgColors.accent),
      _DashAction('Messages', Icons.chat_bubble_outline, '/messages', MkgColors.primary),
      _DashAction('TaxPro Assist', Icons.smart_toy_outlined, '/tessa', MkgColors.green),
      _DashAction('Profile / KYC', Icons.verified_user_outlined, '/profile', MkgColors.orange),
      _DashAction('Refund Tracker', Icons.track_changes_outlined, '/refund-tracker', MkgColors.primary),
      _DashAction('Tax Tools', Icons.calculate_outlined, '/tools', MkgColors.green),
      _DashAction('Support', Icons.support_agent_outlined, '/support', MkgColors.accent),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [MkgColors.primary, MkgColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  user?.displayName ?? 'Client',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(label: 'financemkgtax.com', color: Colors.white),
                    StatusChip(
                      label: verified ? 'Identity verified' : 'Verify identity',
                      color: verified ? MkgColors.accent : Colors.white70,
                    ),
                    if (user?.kycStatus != null)
                      StatusChip(label: 'KYC: ${user!.kycStatus}', color: MkgColors.accent),
                    if (user?.approvalStatus != null)
                      StatusChip(label: 'Approval: ${user!.approvalStatus}', color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ] else if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: MkgColors.red),
                title: const Text('Could not load portal data'),
                subtitle: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            ),
          ] else ...[
            const SectionHeader('Your tax returns'),
            if (_returns.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No tax return yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Start a return to open the Tax Organizer and upload documents.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _creating ? null : _createReturn,
                        icon: _creating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: Text(_creating ? 'Creating…' : 'Start $taxYear return'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._returns.take(5).map((r) {
                final y = (r['year'] ?? r['taxYear'] ?? '—').toString();
                final s = (r['status'] ?? 'draft').toString();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: MkgColors.lightPrimary,
                      child: Icon(Icons.description_outlined, color: MkgColors.primary),
                    ),
                    title: Text('Tax Year $y', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Status: $s'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/organizer'),
                  ),
                );
              }),
            if (current != null) ...[
              const SizedBox(height: 8),
              Text(
                'Active return · $taxYear · $status',
                style: const TextStyle(color: MkgColors.textGrey, fontWeight: FontWeight.w600),
              ),
            ],
          ],
          const SectionHeader('Quick actions'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(action.route),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: MkgColors.lightPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(action.icon, color: action.color),
                        ),
                        const Spacer(),
                        Text(
                          action.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashAction {
  const _DashAction(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}
