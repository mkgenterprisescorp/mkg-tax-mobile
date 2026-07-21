import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../organizer/data/us_states.dart';
import '../../states/data/states_repository.dart';
import '../data/state_return_picker_catalog.dart';

/// Tax-year workspace: federal + state returns, statuses, prior-year filing.
class TaxReturnsWorkspaceScreen extends ConsumerStatefulWidget {
  const TaxReturnsWorkspaceScreen({super.key});

  @override
  ConsumerState<TaxReturnsWorkspaceScreen> createState() => _TaxReturnsWorkspaceScreenState();
}

class _TaxReturnsWorkspaceScreenState extends ConsumerState<TaxReturnsWorkspaceScreen> {
  String _selectedState = 'CA';
  String _residencyType = 'resident';
  List<Map<String, dynamic>> _stateDetails = const [];
  bool _busy = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final tax = ref.read(taxYearProvider);
    if (tax.years.isEmpty || tax.selectedYear == null || tax.currentFilingYear == null) {
      await ref.read(taxYearProvider.notifier).bootstrap();
    } else {
      await ref.read(taxYearProvider.notifier).refreshWorkspace(force: true);
    }
    await _loadStates();
  }

  Future<void> _loadStates() async {
    final tax = ref.read(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear ?? DateTime.now().year - 1;
    List<Map<String, dynamic>> details = const [];
    try {
      details = await ref.read(statesRepositoryProvider).catalogDetails(taxYear: year);
    } catch (_) {
      details = const [];
    }
    if (!mounted) return;
    setState(() {
      _stateDetails = details
          .where((e) {
            final code = (e['code'] ?? e['state_code'] ?? '').toString().trim();
            return code.isNotEmpty;
          })
          .map((e) {
            final code = (e['code'] ?? e['state_code']).toString().trim().toUpperCase();
            return <String, dynamic>{
              ...e,
              'code': code,
            };
          })
          .toList(growable: false);
      final codes = _stateCodes.toSet();
      if (!codes.contains(_selectedState) && codes.isNotEmpty) {
        _selectedState = codes.contains('CA') ? 'CA' : codes.first;
      }
    });
  }

  String? get _stateSupportMessage {
    final match = _pickerRows.where((e) => e.code == _selectedState);
    if (match.isEmpty) {
      if (statesWithIncomeTax.contains(_selectedState) && _selectedState != 'CA') {
        return 'This state has a personal income tax. Mobile collects organizer intake for professional review.';
      }
      return null;
    }
    final row = match.first;
    final support = row.taxFilingSupport;
    if (support == 'organizer_supported') return null;
    final api = _stateDetails.where((e) => e['code']?.toString() == _selectedState);
    if (support == 'organizer_intake' || support == 'unsupported' || support == 'no_income_tax') {
      final msg = api.isEmpty ? null : api.first['unsupported_message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      if (support == 'no_income_tax') {
        return 'This jurisdiction has no broad personal income tax. Business / franchise intake may still apply.';
      }
      return 'This state uses nationwide organizer intake for professional review.';
    }
    return null;
  }

  List<StateReturnPickerSection> get _pickerSections =>
      buildStateReturnPickerSections(enrichment: _stateDetails);

  List<StateReturnPickerRow> get _pickerRows =>
      buildStateReturnPickerRows(enrichment: _stateDetails);

  List<String> get _stateCodes => [for (final row in _pickerRows) row.code];

  Future<String?> _ensureWorkspaceId() async {
    var tax = ref.read(taxYearProvider);
    var workspaceId = tax.workspace?.workspaceId;
    if (workspaceId != null && workspaceId.isNotEmpty && tax.source == 'laravel') {
      return workspaceId;
    }
    if (AppConfig.usesLaravelAuth) {
      if (tax.selectedYear == null && tax.currentFilingYear != null) {
        await ref.read(taxYearProvider.notifier).selectYear(tax.currentFilingYear!);
      } else {
        await ref.read(taxYearProvider.notifier).refreshWorkspace(force: true);
      }
      tax = ref.read(taxYearProvider);
      workspaceId = tax.workspace?.workspaceId;
      if (workspaceId != null && workspaceId.isNotEmpty) return workspaceId;
      return null;
    }
    return workspaceId;
  }

  Future<void> _addState() async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      final workspaceId = await _ensureWorkspaceId();
      if (!mounted) return;
      if (workspaceId == null || workspaceId.isEmpty) {
        final msg = ref.read(taxYearProvider).error ??
            'No tax-year workspace. Select a year and try again.';
        setState(() => _localError = msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
      final code = _selectedState.trim().toUpperCase();
      await ref.read(taxYearRepositoryProvider).addState(
            workspaceId,
            code,
            residencyType: _residencyType,
          );
      // Must force — warm cache would skip reloading state_workspaces.
      await ref.read(taxYearProvider.notifier).refreshWorkspace(force: true);
      if (!mounted) return;
      final msg = _stateSupportMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg ??
                '$code state return added. Tap it below to continue in the Organizer.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = ApiErrorMapper.map(e);
      setState(() => _localError = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _priorYear() async {
    final year = ref.read(taxYearProvider).selectedYear ??
        ref.read(taxYearProvider).currentFilingYear;
    if (year == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(taxYearProvider.notifier).selectYear(year);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tax year $year workspace ready. Complete the organizer next.')),
      );
      context.go('/organizer');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openStateReturn(Map<String, dynamic> state) {
    final code = (state['state_code'] ?? state['stateCode'] ?? '').toString().toUpperCase();
    if (code.isEmpty) return;
    if (code == 'CA') {
      context.go('/ca-540');
      return;
    }
    // Nationwide intake lives in Organizer → State Tax Returns.
    context.go('/organizer');
  }

  String _statusLabel(Map<String, dynamic> state) {
    final raw = (state['status'] ?? state['filing_status'] ?? 'not_started').toString();
    if (raw.isEmpty) return 'Not Started';
    return raw
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  Future<void> _pickState() async {
    final sections = _pickerSections;
    final total = sections.fold<int>(0, (sum, s) => sum + s.rows.length);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            if (total == 0) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const Text(
                    'Select a state return',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No states are available right now. Pull to refresh or try again.',
                    style: TextStyle(color: MkgColors.textGrey),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadStates();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: 1 + sections.fold<int>(0, (sum, s) => sum + 1 + s.rows.length),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select a state return',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All 50 states + DC · Regions 1–6 nationwide intake',
                          style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                var cursor = 1;
                for (final section in sections) {
                  if (index == cursor) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Region ${section.region.id} · ${section.region.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MkgColors.primary,
                        ),
                      ),
                    );
                  }
                  cursor += 1;
                  for (final row in section.rows) {
                    if (index == cursor) {
                      final selected = row.code == _selectedState;
                      return ListTile(
                        selected: selected,
                        leading: CircleAvatar(
                          backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            row.code,
                            style: const TextStyle(
                              color: MkgColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text('${row.code} · ${row.displayName}'),
                        subtitle: Text(row.subtitle),
                        trailing: selected
                            ? const Icon(Icons.check, color: MkgColors.primary)
                            : null,
                        onTap: () => Navigator.pop(ctx, row.code),
                      );
                    }
                    cursor += 1;
                  }
                }
                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
    if (chosen == null || !mounted) return;
    setState(() => _selectedState = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final tax = ref.watch(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear;
    final ws = tax.workspace;
    final yearInfo = tax.years.where((y) => y.taxYear == year).toList();
    final stateReturns = ws?.stateReturns ?? const <Map<String, dynamic>>[];
    final selectedName = displayNameForState(_selectedState);

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
                Text(
                  'Federal return · TY ${year ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  ws?.federalReturnStatus ?? 'Not Started',
                  style: const TextStyle(color: MkgColors.primary, fontWeight: FontWeight.w700),
                ),
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
                  runSpacing: 8,
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
                'All 50 states + DC across Regions 1–6. California has deep Form 540 support; other jurisdictions use nationwide organizer intake for professional review.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _pickState,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_selectedState · $selectedName',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: residencyTypeOptions.any((e) => e.$1 == _residencyType)
                    ? _residencyType
                    : 'resident',
                decoration: const InputDecoration(labelText: 'Residency'),
                items: [
                  for (final opt in residencyTypeOptions)
                    DropdownMenuItem(value: opt.$1, child: Text(opt.$2)),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _residencyType = v);
                      },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _addState,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: Text(_busy ? 'Adding…' : 'Add state return'),
              ),
              if (_stateSupportMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _stateSupportMessage!,
                  style: const TextStyle(color: MkgColors.orange, fontSize: 12),
                ),
              ],
              if (_localError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _localError!,
                  style: const TextStyle(color: MkgColors.orange, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: stateReturns.isEmpty
              ? const Text(
                  'No state returns yet. Choose a state above, then tap Add state return.',
                  style: TextStyle(color: MkgColors.textGrey),
                )
              : Column(
                  children: [
                    for (final s in stateReturns)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _openStateReturn(s),
                          leading: CircleAvatar(
                            backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              (s['state_code'] ?? '?').toString(),
                              style: const TextStyle(
                                color: MkgColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            '${s['state_code']} · ${s['residency_type'] ?? 'resident'}',
                          ),
                          subtitle: Text('Status: ${_statusLabel(s)} · Tap to open'),
                          trailing: const Icon(Icons.chevron_right),
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
