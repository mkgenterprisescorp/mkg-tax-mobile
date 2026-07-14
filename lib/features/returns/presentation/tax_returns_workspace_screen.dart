import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Tax-year workspace: federal + state returns, statuses, prior-year filing.
class TaxReturnsWorkspaceScreen extends ConsumerStatefulWidget {
  const TaxReturnsWorkspaceScreen({super.key});

  @override
  ConsumerState<TaxReturnsWorkspaceScreen> createState() => _TaxReturnsWorkspaceScreenState();
}

class _TaxReturnsWorkspaceScreenState extends ConsumerState<TaxReturnsWorkspaceScreen> {
  final _stateCode = TextEditingController(text: 'CA');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tax = ref.read(taxYearProvider);
      if (tax.years.isEmpty) {
        ref.read(taxYearProvider.notifier).bootstrap();
      } else {
        ref.read(taxYearProvider.notifier).refreshWorkspace();
      }
    });
  }

  @override
  void dispose() {
    _stateCode.dispose();
    super.dispose();
  }

  Future<void> _addState() async {
    final year = ref.read(taxYearProvider).selectedYear;
    if (year == null) return;
    setState(() => _busy = true);
    try {
      final code = _stateCode.text.trim().toUpperCase();
      final created = await ref.read(taxYearRepositoryProvider).addState(year, code);
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to Laravel (Sanctum) to save state returns, or check LARAVEL_API_BASE_URL.')),
        );
      } else {
        await ref.read(taxYearProvider.notifier).refreshWorkspace();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _priorYear() async {
    final year = ref.read(taxYearProvider).selectedYear;
    if (year == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(taxYearRepositoryProvider).priorYearFiling(year);
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prior-year filing started for $year. Complete the organizer next.')),
      );
      context.go('/organizer');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tax = ref.watch(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear;
    final ws = tax.workspace;
    final yearInfo = tax.years.where((y) => y.taxYear == year).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const TaxYearSelectorBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Federal return · TY ${year ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                Text(ws?.federalReturnStatus ?? 'Not Started', style: const TextStyle(color: MkgColors.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Organizer: ${ws?.organizerStatus ?? 'Not Started'} · ${ws?.organizerCompletionPercentage ?? 0}%',
                  style: const TextStyle(color: MkgColors.textGrey),
                ),
                if (yearInfo.isNotEmpty && !yearInfo.first.efileAvailable) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Warning: e-file may be unavailable. Year visibility does not guarantee a claimable refund.',
                    style: TextStyle(color: MkgColors.orange, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => context.go('/organizer'),
                      child: const Text('Open Organizer'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/documents'),
                      child: const Text('Documents'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('State returns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              TextButton(
                onPressed: _busy ? null : _priorYear,
                child: const Text('File a Prior Year'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _stateCode,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  decoration: const InputDecoration(labelText: 'State', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : _addState,
                child: const Text('Add State'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: (ws?.stateReturns ?? const []).isEmpty
              ? const Text(
                  'No state returns yet. Add residency / work / rental states for review.',
                  style: TextStyle(color: MkgColors.textGrey),
                )
              : Column(
                  children: [
                    for (final s in ws!.stateReturns)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              (s['state_code'] ?? '?').toString(),
                              style: const TextStyle(color: MkgColors.primary, fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text('${s['state_code']} · ${s['residency_type'] ?? 'resident'}'),
                          subtitle: Text('Status: ${s['filing_status'] ?? 'Not Started'}'),
                          trailing: Text((s['return_type'] ?? 'original').toString()),
                        ),
                      ),
                  ],
                ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Workspace sections', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        for (final item in const [
          ('Tax Organizer', Icons.assignment_outlined, '/organizer'),
          ('Documents', Icons.folder_outlined, '/documents'),
          ('Tasks', Icons.checklist_outlined, '/home'),
          ('Payments', Icons.payments_outlined, '/billing'),
          ('Messages / TESSA', Icons.smart_toy_outlined, '/tessa'),
          ('Return Summary', Icons.summarize_outlined, '/home'),
        ])
          ListTile(
            leading: Icon(item.$2, color: MkgColors.primary),
            title: Text(item.$1),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(item.$3),
          ),
        if (tax.source == 'local-fallback')
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Laravel workspace APIs require LARAVEL_API_BASE_URL + Sanctum token. Catalog may still render locally.',
              style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
