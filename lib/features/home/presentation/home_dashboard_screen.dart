import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

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
      ref.read(taxYearProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final tax = ref.watch(taxYearProvider);
    final caps = capabilitiesFor(auth.user?.role);
    final name = auth.user?.firstName.isNotEmpty == true ? auth.user!.firstName : 'there';
    final year = tax.selectedYear ?? tax.currentFilingYear ?? (DateTime.now().year - 1);
    final ws = tax.workspace;

    return RefreshIndicator(
      onRefresh: () => ref.read(taxYearProvider.notifier).bootstrap(),
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
          if (tax.loading)
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
            if (tax.tasks.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text('Outstanding tasks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              ...tax.tasks.take(3).map((t) {
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
