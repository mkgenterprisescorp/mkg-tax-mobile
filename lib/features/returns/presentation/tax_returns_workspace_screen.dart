import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../organizer/data/us_states.dart';
import '../../states/data/states_repository.dart';

/// Tax-year workspace: federal + state returns, statuses, prior-year filing.
class TaxReturnsWorkspaceScreen extends ConsumerStatefulWidget {
  const TaxReturnsWorkspaceScreen({super.key});

  @override
  ConsumerState<TaxReturnsWorkspaceScreen> createState() => _TaxReturnsWorkspaceScreenState();
}

class _TaxReturnsWorkspaceScreenState extends ConsumerState<TaxReturnsWorkspaceScreen> {
  String _selectedState = 'CA';
  List<Map<String, dynamic>> _stateDetails = const [];
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
      _loadStates();
    });
  }

  Future<void> _loadStates() async {
    final tax = ref.read(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear ?? DateTime.now().year - 1;
    final details = await ref.read(statesRepositoryProvider).catalogDetails(taxYear: year);
    if (!mounted) return;
    setState(() {
      _stateDetails = details;
      if (details.isNotEmpty && details.every((e) => e['code']?.toString() != _selectedState)) {
        _selectedState = details.first['code']?.toString() ?? 'CA';
      }
    });
  }

  String? get _stateSupportMessage {
    final match = _stateDetails.where((e) => e['code']?.toString() == _selectedState);
    if (match.isEmpty) {
      if (statesWithIncomeTax.contains(_selectedState) && _selectedState != 'CA') {
        return 'This state has a personal income tax. Mobile collects organizer intake for professional review.';
      }
      return null;
    }
    final row = match.first;
    final support = row['tax_filing_support']?.toString();
    if (support == 'organizer_supported') return null;
    if (support == 'organizer_intake' || support == 'unsupported' || support == 'no_income_tax') {
      return row['unsupported_message']?.toString();
    }
    return null;
  }

  List<Map<String, dynamic>> get _sortedStateDetails {
    final details = _stateDetails.isEmpty
        ? [
            for (final opt in incomeTaxStateOptions)
              {
                'code': opt.$1,
                'display_name': opt.$2,
                'has_personal_income_tax': true,
                'tax_filing_support': opt.$1 == 'CA' ? 'organizer_supported' : 'organizer_intake',
              },
          ]
        : List<Map<String, dynamic>>.from(_stateDetails);
    details.sort((a, b) {
      final ac = a['code']?.toString() ?? '';
      final bc = b['code']?.toString() ?? '';
      final ai = statesWithIncomeTax.contains(ac);
      final bi = statesWithIncomeTax.contains(bc);
      if (ai != bi) return ai ? -1 : 1;
      return ac.compareTo(bc);
    });
    return details;
  }

  Future<void> _addState() async {
    final tax = ref.read(taxYearProvider);
    final workspaceId = tax.workspace?.workspaceId;
    if (workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activate a tax-year workspace first, then try again.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final code = _selectedState.trim().toUpperCase();
      final created = await ref.read(taxYearRepositoryProvider).addState(workspaceId, code);
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save state return. Please sign in and try again.')),
        );
      } else {
        await ref.read(taxYearProvider.notifier).refreshWorkspace();
        if (!mounted) return;
        final msg = _stateSupportMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
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
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tax year $year workspace ready. Complete the organizer next.')),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Income-tax states are listed first (42 jurisdictions). California has deep Form 540 support; other income-tax states use organizer intake for professional review.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _sortedStateDetails.any((e) => e['code']?.toString() == _selectedState)
                          ? _selectedState
                          : (_sortedStateDetails.isNotEmpty ? _sortedStateDetails.first['code']?.toString() : 'CA'),
                      decoration: const InputDecoration(labelText: 'State'),
                      items: [
                        for (final s in _sortedStateDetails)
                          DropdownMenuItem(
                            value: s['code']?.toString(),
                            child: Text(
                              '${s['code']} · ${s['display_name'] ?? s['code']}'
                              '${(s['has_personal_income_tax'] == true || statesWithIncomeTax.contains('${s['code']}')) ? ' · income tax' : ''}',
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _selectedState = v);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _addState,
                    child: const Text('Add State'),
                  ),
                ],
              ),
              if (_stateSupportMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _stateSupportMessage!,
                  style: const TextStyle(color: MkgColors.orange, fontSize: 12),
                ),
              ],
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
              'Showing the local tax-year catalog. Sign in to sync your full workspace.',
              style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
