import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

/// Personalized tax-year Home dashboard.
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caps.isProfessional ? 'Good day, $name' : 'Hi $name,',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        _chip('States', '${ws?.stateReturns.length ?? 0} added'),
                      ],
                    ),
                    if (ws != null) ...[
                      Builder(builder: (context) {
                        final info = tax.years.where((y) => y.taxYear == ws.taxYear).toList();
                        if (info.isNotEmpty && info.first.paperFilingOnly) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Electronic filing is unavailable for this year — paper filing may be required.',
                              style: TextStyle(color: MkgColors.orange, fontSize: 12),
                            ),
                          );
                        }
                        if (info.isNotEmpty && !info.first.efileAvailable) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'E-file may be unavailable. Refund eligibility is not guaranteed by year visibility.',
                              style: TextStyle(color: MkgColors.orange, fontSize: 12),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('Quick Actions'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                children: [
                  for (final a in _quickActions(caps))
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width / 2 - 18,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.go(a.path),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: a.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: a.color.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(a.icon, color: a.color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Outstanding tasks'),
            if (tax.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('No open tasks for this tax year yet.', style: TextStyle(color: MkgColors.textGrey)),
              )
            else
              ...tax.tasks.map((t) {
                final href = (t['href'] ?? 'returns').toString();
                final path = switch (href) {
                  'organizer' => '/organizer',
                  'documents' => '/documents',
                  'tessa' => '/tessa',
                  _ => '/returns',
                };
                return ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: MkgColors.accent),
                  title: Text((t['title'] ?? 'Task').toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(path),
                );
              }),
            _sectionTitle('TESSA recommendations'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MkgCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.smart_toy_outlined, color: MkgColors.primary),
                  title: Text('Ask about your $year return'),
                  subtitle: const Text('Missing documents, state filings, organizer help.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/tessa'),
                ),
              ),
            ),
            _sectionTitle('Deadlines'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MkgCard(
                child: Column(
                  children: [
                    _deadlineRow('Federal filing', 'April 15, ${year + 1}'),
                    const Divider(height: 20),
                    _deadlineRow('Extension deadline', 'October 15, ${year + 1}'),
                  ],
                ),
              ),
            ),
            if (tax.source == 'local-fallback')
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tax-year catalog is using a local fallback. Point LARAVEL_API_BASE_URL at the Laravel API for server-authoritative years.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MkgColors.primary.withValues(alpha: 0.15)),
        ),
        child: Text('$label: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _deadlineRow(String label, String when) => Row(
        children: [
          const Icon(Icons.event_outlined, color: MkgColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(when, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
        ],
      );

  List<_QuickAction> _quickActions(RoleCapabilities caps) {
    final base = <_QuickAction>[
      const _QuickAction('Start Organizer', Icons.assignment_outlined, '/organizer', MkgColors.primary),
      const _QuickAction('Continue Return', Icons.description_outlined, '/returns', MkgColors.primary),
      const _QuickAction('Upload Document', Icons.upload_file_outlined, '/documents', MkgColors.green),
      const _QuickAction('Add State Return', Icons.map_outlined, '/returns', MkgColors.orange),
      const _QuickAction('File Prior Year', Icons.history_edu_outlined, '/returns', MkgColors.accent),
      const _QuickAction('Ask TESSA', Icons.smart_toy_outlined, '/tessa', MkgColors.green),
      const _QuickAction('Make a Payment', Icons.payments_outlined, '/billing', MkgColors.accent),
      const _QuickAction('Profile / KYC', Icons.verified_user_outlined, '/profile', MkgColors.orange),
    ];
    if (caps.isProfessional) {
      return [
        const _QuickAction('My Clients', Icons.groups_outlined, '/my-clients', MkgColors.primary),
        const _QuickAction('All Returns', Icons.library_books_outlined, '/all-returns', MkgColors.primary),
        ...base,
      ];
    }
    return base;
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.path, this.color);
  final String label;
  final IconData icon;
  final String path;
  final Color color;
}
