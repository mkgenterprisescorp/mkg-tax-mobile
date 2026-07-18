import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Tax Center hub — icon walkthrough of sections to complete.
class TaxCenterScreen extends ConsumerWidget {
  const TaxCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tax = ref.watch(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear ?? (DateTime.now().year - 1);
    final ws = tax.workspace;
    final organizerPct = (ws?.organizerCompletionPercentage ?? 0).clamp(0, 100);

    final sections = <_TaxSection>[
      _TaxSection(
        title: 'Tax Organizer',
        cue: 'Walk through filing sections',
        icon: Icons.assignment_outlined,
        path: '/organizer',
        accent: MkgColors.primary,
        progressLabel: organizerPct > 0 ? '$organizerPct%' : 'Start',
        done: organizerPct >= 100,
      ),
      _TaxSection(
        title: 'Tax Returns',
        cue: 'Federal & state workspace',
        icon: Icons.description_outlined,
        path: '/returns',
        accent: MkgColors.primary,
        progressLabel: ws?.federalReturnStatus ?? 'Open',
        done: (ws?.federalReturnStatus ?? '').toLowerCase().contains('filed') ||
            (ws?.federalReturnStatus ?? '').toLowerCase().contains('accepted'),
      ),
      _TaxSection(
        title: 'Documents',
        cue: 'Upload W-2s, 1099s, ID',
        icon: Icons.folder_outlined,
        path: '/documents',
        accent: MkgColors.accent,
        progressLabel: '${ws?.documentsCount ?? 0} files',
        done: (ws?.documentsCount ?? 0) > 0,
      ),
      _TaxSection(
        title: 'Refund calculator',
        cue: 'Estimate · organizer prefill',
        icon: Icons.savings_outlined,
        path: '/refund-advance/estimate',
        accent: MkgColors.green,
        progressLabel: 'Estimate',
      ),
      _TaxSection(
        title: 'Refund Advance',
        cue: 'Loan Estimate · TILA · 36% APR',
        icon: Icons.payments_outlined,
        path: '/refund-advance',
        accent: MkgColors.accent,
        progressLabel: '0% / 36%',
      ),
      _TaxSection(
        title: 'Refund Tracker',
        cue: 'IRS & FTB status',
        icon: Icons.track_changes_outlined,
        path: '/refund-tracker',
        accent: MkgColors.green,
        progressLabel: 'Check',
      ),
      _TaxSection(
        title: 'Tax Consulting',
        cue: 'Chat with advisor / TESSA',
        icon: Icons.support_agent_outlined,
        path: '/chat',
        accent: MkgColors.green,
        progressLabel: 'Ask',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const TaxYearSelectorBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tax Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Tap a section to walk through and complete for TY $year.',
                style: const TextStyle(color: MkgColors.textGrey),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status · TY $year', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Federal: ${ws?.federalReturnStatus ?? 'Not Started'}'),
                Text('Organizer: ${ws?.organizerStatus ?? 'Not Started'} · $organizerPct%'),
                Text('Documents: ${ws?.documentsCount ?? 0} on file'),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: organizerPct / 100,
                    minHeight: 8,
                    backgroundColor: MkgColors.surfaceGrey,
                    color: MkgColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text('Sections to complete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (context, i) {
              final s = sections[i];
              return _TaxSectionTile(section: s, onTap: () => context.go(s.path));
            },
          ),
        ),
      ],
    );
  }
}

class _TaxSection {
  const _TaxSection({
    required this.title,
    required this.cue,
    required this.icon,
    required this.path,
    required this.accent,
    required this.progressLabel,
    this.done = false,
  });

  final String title;
  final String cue;
  final IconData icon;
  final String path;
  final Color accent;
  final String progressLabel;
  final bool done;
}

class _TaxSectionTile extends StatelessWidget {
  const _TaxSectionTile({required this.section, required this.onTap});

  final _TaxSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = section.done ? MkgColors.green : section.accent;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(section.icon, color: color),
                  ),
                  const Spacer(),
                  if (section.done)
                    const Icon(Icons.check_circle, color: MkgColors.green, size: 22)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        section.progressLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                section.cue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
