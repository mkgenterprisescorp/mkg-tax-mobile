import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Tax Center hub — filings, organizer, documents, consulting entry points.
class TaxCenterScreen extends ConsumerWidget {
  const TaxCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tax = ref.watch(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear ?? (DateTime.now().year - 1);
    final ws = tax.workspace;

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
                'Filings, organizers, documents, and tax consulting for TY $year.',
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
                Text('Organizer: ${ws?.organizerStatus ?? 'Not Started'} · ${ws?.organizerCompletionPercentage ?? 0}%'),
                Text('Documents: ${ws?.documentsCount ?? 0} on file'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final item in const [
          _TaxLink('Tax Returns', 'Federal & state filing workspace', Icons.description_outlined, '/returns'),
          _TaxLink('Tax Organizer', 'Complete questionnaires by tax year', Icons.assignment_outlined, '/organizer'),
          _TaxLink('Documents', 'Upload, scan, and vault tax files', Icons.folder_outlined, '/documents'),
          _TaxLink('Refund Tracker', 'IRS / FTB status links', Icons.track_changes_outlined, '/refund-tracker'),
          _TaxLink('Tax Tools', 'Calculators and references', Icons.calculate_outlined, '/tools'),
          _TaxLink('Tax consulting', 'Ask TESSA or contact your preparer', Icons.support_agent_outlined, '/chat'),
        ])
          ListTile(
            leading: Icon(item.icon, color: MkgColors.primary),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            minVerticalPadding: 14,
            onTap: () => context.go(item.path),
          ),
      ],
    );
  }
}

class _TaxLink {
  const _TaxLink(this.title, this.subtitle, this.icon, this.path);
  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
}
