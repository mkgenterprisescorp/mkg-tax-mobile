import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../organizer/data/organizer_defaults.dart';

/// Clean home dashboard with dual-brand service pillars.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Defer Organizer defaults until after first frame — Home does not need
      // the ~35KB JSON for first paint; Organizer loads it on open (cached).
      unawaited(Future<void>.delayed(Duration.zero, OrganizerDefaults.load));
      ref.read(taxYearProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    // Fine-grained watches — avoid rebuilding the whole dashboard on every
    // taxYear field churn (e.g. organizerSnapshot updates).
    final loading = ref.watch(taxYearProvider.select((s) => s.loading));
    final selectedYear = ref.watch(taxYearProvider.select((s) => s.selectedYear));
    final currentFilingYear =
        ref.watch(taxYearProvider.select((s) => s.currentFilingYear));
    final workspace = ref.watch(taxYearProvider.select((s) => s.workspace));
    final tasks = ref.watch(taxYearProvider.select((s) => s.tasks));
    final caps = capabilitiesFor(auth.user?.role);
    final name = auth.user?.firstName.isNotEmpty == true ? auth.user!.firstName : 'there';
    final year = selectedYear ?? currentFilingYear ?? (DateTime.now().year - 1);
    final ws = workspace;

    return RefreshIndicator(
      onRefresh: () => ref.read(taxYearProvider.notifier).bootstrap(forceCatalog: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const TaxYearSelectorBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caps.isProfessional ? 'Good day, $name' : 'Hi $name,',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text(
                  'MKG Tax Consultants',
                  style: TextStyle(fontWeight: FontWeight.w700, color: MkgColors.primary),
                ),
                Text(
                  'Finance Advisors',
                  style: TextStyle(fontWeight: FontWeight.w600, color: MkgColors.accent.withValues(alpha: 0.95)),
                ),
                const SizedBox(height: 6),
                Text(
                  caps.isProfessional
                      ? 'Practice overview for tax year $year.'
                      : 'Your $year filing season workspace.',
                  style: const TextStyle(color: MkgColors.textGrey),
                ),
              ],
            ),
          ),
          if (loading && ws == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: MkgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: MkgColors.primary),
                        const SizedBox(width: 8),
                        Text('Filing progress · TY $year', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: ((ws?.organizerCompletionPercentage ?? 0) / 100).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: MkgColors.primary,
                      backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('Federal', ws?.federalReturnStatus ?? 'Not Started'),
                        _chip('Organizer', ws?.organizerStatus ?? 'Not Started'),
                        _chip('Docs', '${ws?.documentsCount ?? 0} on file'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Quick walkthrough', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickIcon(
                      icon: Icons.assignment_outlined,
                      label: 'Organizer',
                      onTap: () => context.go('/organizer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickIcon(
                      icon: Icons.folder_outlined,
                      label: 'Documents',
                      onTap: () => context.go('/documents'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickIcon(
                      icon: Icons.calculate_outlined,
                      label: 'Tools',
                      onTap: () => context.go('/tools'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickIcon(
                      icon: Icons.payments_outlined,
                      label: 'Advance',
                      onTap: () => context.go('/refund-advance'),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text('Services', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ServicePillar(
                    title: 'Tax Center',
                    subtitle: 'Filings, documents, and tax consulting',
                    icon: Icons.account_balance_wallet_outlined,
                    color: MkgColors.primary,
                    onTap: () => context.go('/tax-center'),
                  ),
                  const SizedBox(height: 10),
                  _ServicePillar(
                    title: 'Financial Tools',
                    subtitle: 'W-4 · refund estimate · loans · payments',
                    icon: Icons.calculate_outlined,
                    color: MkgColors.green,
                    onTap: () => context.go('/tools'),
                  ),
                  const SizedBox(height: 10),
                  _ServicePillar(
                    title: 'Financial Planning',
                    subtitle: 'Finance Advisors · lending · bookkeeping',
                    icon: Icons.trending_up_outlined,
                    color: MkgColors.accent,
                    onTap: () => context.go('/advisory'),
                  ),
                  const SizedBox(height: 10),
                  _ServicePillar(
                    title: 'Advisor Chat',
                    subtitle: 'TESSA AI, scheduling, and contact us',
                    icon: Icons.forum_outlined,
                    color: MkgColors.green,
                    onTap: () => context.go('/chat'),
                  ),
                ],
              ),
            ),
            if (tasks.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text('Outstanding tasks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              ...tasks.take(3).map((t) {
                final href = (t['href'] ?? 'tax-center').toString();
                final path = switch (href) {
                  'organizer' => '/organizer',
                  'documents' => '/documents',
                  'tessa' || 'chat' => '/chat',
                  'returns' => '/returns',
                  _ => '/tax-center',
                };
                return ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: MkgColors.accent),
                  title: Text((t['title'] ?? 'Task').toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(path),
                );
              }),
            ],
            if (caps.isProfessional)
              ListTile(
                leading: const Icon(Icons.groups_outlined, color: MkgColors.primary),
                title: const Text('My Clients'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/my-clients'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MkgColors.primary.withValues(alpha: 0.15)),
        ),
        child: Text('$label: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _ServicePillar extends StatelessWidget {
  const _ServicePillar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MkgColors.surfaceGrey,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MkgColors.primary.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: MkgColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
