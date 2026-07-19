import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/auth/app_roles.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

/// Mobile clone of mkgtaxconsultants.com `/dashboard` (consumer + professional editions).
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
      if (AppConfig.usesLaravelAuth) {
        await _loadLaravelFastPath();
        return;
      }
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
        _error = ApiErrorMapper.map(e);
        _loading = false;
      });
    }
  }

  /// Sanctum builds: portal `/api/tax-returns` is not on the Laravel host.
  /// Paint from the warm tax-year workspace first; soft-fetch portal data only
  /// when it succeeds (cookie bridge), without blocking the hub.
  Future<void> _loadLaravelFastPath() async {
    final tax = ref.read(taxYearProvider);
    final yearHint = tax.selectedYear ?? tax.currentFilingYear ?? DateTime.now().year - 1;
    if (tax.workspace?.workspaceId == null || tax.workspace?.taxYear != yearHint) {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
    }
    if (!mounted) return;
    final ws = ref.read(taxYearProvider).workspace;
    final synthetic = <Map<String, dynamic>>[
      if (ws != null)
        {
          'id': ws.taxReturnId ?? ws.workspaceId,
          'year': ws.taxYear,
          'taxYear': ws.taxYear,
          'status': ws.federalReturnStatus,
          'organizerStatus': ws.organizerStatus,
          'organizerCompletionPercentage': ws.organizerCompletionPercentage,
          'source': 'laravel-workspace',
        },
    ];
    // Show the hub immediately from workspace — don't wait on portal 404s.
    setState(() {
      _returns = synthetic;
      _verification = null;
      _loading = false;
      _error = null;
    });

    // Soft portal enrichment (no-op when routes 404 on app host).
    try {
      final portal = ref.read(portalRepositoryProvider);
      List<Map<String, dynamic>> rows = const [];
      Map<String, dynamic>? verification;
      try {
        rows = await portal.listTaxReturns();
      } catch (_) {}
      try {
        verification = await portal.verificationStatus();
      } catch (_) {}
      if (!mounted) return;
      if (rows.isEmpty && verification == null) return;
      setState(() {
        if (rows.isNotEmpty) _returns = rows;
        if (verification != null) _verification = verification;
      });
    } catch (_) {
      // Keep workspace-backed UI.
    }
  }

  Future<void> _createReturn() async {
    setState(() => _creating = true);
    try {
      if (AppConfig.usesLaravelAuth) {
        await ref.read(taxYearProvider.notifier).refreshWorkspace(force: true);
        if (mounted) context.go('/organizer');
        return;
      }
      await ref.read(portalRepositoryProvider).createTaxReturn();
      await _load();
      if (mounted) context.go('/organizer');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Map<String, dynamic>? get _current => _returns.isNotEmpty ? _returns.first : null;

  List<_DashAction> _actionsFor(RoleCapabilities caps) {
    if (caps.isProfessional) {
      return const [
        _DashAction('My Clients', Icons.groups_outlined, '/my-clients', MkgColors.primary),
        _DashAction('All Tax Returns', Icons.description_outlined, '/all-returns', MkgColors.primary),
        _DashAction('Tax Organizer', Icons.assignment_outlined, '/organizer', MkgColors.green),
        _DashAction('Documents', Icons.folder_outlined, '/documents', MkgColors.green),
        _DashAction('IRS iERO', Icons.travel_explore_outlined, '/iero', MkgColors.orange),
        _DashAction('Payments', Icons.receipt_long_outlined, '/billing', MkgColors.accent),
        _DashAction('Tessa AI', Icons.smart_toy_outlined, '/tessa', MkgColors.green),
        _DashAction('Tax Tools', Icons.calculate_outlined, '/tools', MkgColors.primary),
        _DashAction('Support', Icons.support_agent_outlined, '/support', MkgColors.accent),
        _DashAction('Profile', Icons.person_outline, '/profile', MkgColors.orange),
      ];
    }
    return const [
      _DashAction('Tax Organizer', Icons.assignment_outlined, '/organizer', MkgColors.primary),
      _DashAction('My Tax Returns', Icons.description_outlined, '/all-returns', MkgColors.primary),
      _DashAction('Documents', Icons.folder_outlined, '/documents', MkgColors.green),
      _DashAction('Financials', Icons.payments_outlined, '/financial', MkgColors.orange),
      _DashAction('Payments', Icons.receipt_long_outlined, '/billing', MkgColors.accent),
      _DashAction('Tessa AI', Icons.smart_toy_outlined, '/tessa', MkgColors.green),
      _DashAction('Profile / KYC', Icons.verified_user_outlined, '/profile', MkgColors.orange),
      _DashAction('Refund Tracker', Icons.track_changes_outlined, '/refund-tracker', MkgColors.primary),
      _DashAction('Tax Tools', Icons.calculate_outlined, '/tools', MkgColors.green),
      _DashAction('Support', Icons.support_agent_outlined, '/support', MkgColors.accent),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final caps = capabilitiesFor(user?.role);
    final current = _current;
    final taxYear = (current?['year'] ?? current?['taxYear'] ?? DateTime.now().year).toString();
    final status = (current?['status'] ?? 'none').toString();
    final verified = _verification?['verified'] == true;
    final actions = _actionsFor(caps);

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
                Text(
                  caps.isProfessional ? 'Professional workspace' : 'Welcome back',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayName ?? (caps.isProfessional ? 'Tax Pro' : 'Client'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(label: caps.edition.label, color: MkgColors.accent),
                    StatusChip(label: caps.role, color: Colors.white),
                    StatusChip(label: Uri.parse(AppConfig.portalRoot).host, color: Colors.white),
                    StatusChip(
                      label: verified
                          ? 'Identity verified'
                          : (_verification == null && AppConfig.usesLaravelAuth)
                              ? 'Identity on file'
                              : 'Verify identity',
                      color: verified ? MkgColors.accent : Colors.white70,
                    ),
                    if (user?.kycStatus != null)
                      StatusChip(label: 'KYC: ${user!.kycStatus}', color: MkgColors.accent),
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
            SectionHeader(caps.isProfessional ? 'Practice overview' : 'Your tax returns'),
            if (_returns.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caps.isProfessional ? 'No personal returns loaded' : 'No tax return yet',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        caps.isProfessional
                            ? 'Open My Clients or All Tax Returns to manage the firm queue.'
                            : 'Start a return to open the Tax Organizer and upload documents.',
                      ),
                      const SizedBox(height: 12),
                      if (caps.isProfessional)
                        FilledButton.icon(
                          onPressed: () => context.go('/my-clients'),
                          icon: const Icon(Icons.groups_outlined),
                          label: const Text('Open My Clients'),
                        )
                      else
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
          SectionHeader(caps.isProfessional ? 'Professional tools' : 'Quick actions'),
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
