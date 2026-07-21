import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../organizer/data/laravel_organizer_repository.dart';

class _SavingItem {
  const _SavingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.cue,
    required this.formHint,
    required this.organizerFocus,
  });

  final String id;
  final String name;
  final String category;
  final String cue;
  final String formHint;
  final String organizerFocus;
}

/// Tax savings — checklist + guided interview + Laravel value-savings preview.
class TaxSavingsScreen extends ConsumerStatefulWidget {
  const TaxSavingsScreen({super.key});

  @override
  ConsumerState<TaxSavingsScreen> createState() => _TaxSavingsScreenState();
}

class _TaxSavingsScreenState extends ConsumerState<TaxSavingsScreen> {
  static const _items = <_SavingItem>[
    _SavingItem(id: 'ctc', name: 'Child Tax Credit', category: 'Credits', cue: 'Qualifying children under 17', formHint: 'Form 1040 / Schedule 8812', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'eitc', name: 'Earned Income Tax Credit (EITC)', category: 'Credits', cue: 'Income & family size limits', formHint: 'Form 1040 / Schedule EIC', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'cdc', name: 'Child & Dependent Care Credit', category: 'Credits', cue: 'Daycare / after-school care', formHint: 'Form 2441', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'aotc', name: 'American Opportunity Credit', category: 'Credits', cue: 'First 4 years of college', formHint: 'Form 8863', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'llc', name: 'Lifetime Learning Credit', category: 'Credits', cue: 'Tuition and related expenses', formHint: 'Form 8863', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'saver', name: 'Saver’s Credit', category: 'Credits', cue: 'IRA / 401(k) contributions', formHint: 'Form 8880', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'ira', name: 'Traditional IRA deduction', category: 'Above-the-line', cue: 'Contribution limits apply', formHint: 'Form 1040 Schedule 1', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'hsa', name: 'HSA contributions', category: 'Above-the-line', cue: 'HDHP required', formHint: 'Form 8889', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'se_health', name: 'Self-employed health insurance', category: 'Above-the-line', cue: 'Schedule C / partnership', formHint: 'Schedule 1 / Schedule C', organizerFocus: 'schedule_c'),
    _SavingItem(id: 'se_tax', name: 'Deductible half of SE tax', category: 'Above-the-line', cue: 'Self-employment', formHint: 'Schedule SE', organizerFocus: 'schedule_c'),
    _SavingItem(id: 'student', name: 'Student loan interest', category: 'Above-the-line', cue: 'Form 1098-E', formHint: 'Form 1040 Schedule 1', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'educator', name: 'Educator expenses', category: 'Above-the-line', cue: 'K–12 teachers', formHint: 'Form 1040 Schedule 1', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'mortgage', name: 'Mortgage interest', category: 'Itemized', cue: 'Form 1098', formHint: 'Schedule A', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'salt', name: 'State & local taxes (SALT)', category: 'Itemized', cue: 'Cap may apply', formHint: 'Schedule A', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'charity', name: 'Charitable contributions', category: 'Itemized', cue: 'Cash and non-cash', formHint: 'Schedule A', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'medical', name: 'Medical & dental expenses', category: 'Itemized', cue: 'AGI floor applies', formHint: 'Schedule A', organizerFocus: 'credits_deductions'),
    _SavingItem(id: 'home_office', name: 'Home office (Schedule C)', category: 'Business', cue: 'Exclusive & regular use', formHint: 'Schedule C / Form 8829', organizerFocus: 'schedule_c'),
    _SavingItem(id: 'vehicle', name: 'Business vehicle / mileage', category: 'Business', cue: 'Keep a contemporaneous log', formHint: 'Schedule C', organizerFocus: 'schedule_c'),
    _SavingItem(id: 'supplies', name: 'Office supplies & software', category: 'Business', cue: 'Ordinary & necessary', formHint: 'Schedule C', organizerFocus: 'schedule_c'),
    _SavingItem(id: 'caleitc', name: 'California CalEITC / YCTC', category: 'California', cue: 'FTB 3514 — CA residents', formHint: 'CA Form 540', organizerFocus: 'state_returns'),
    _SavingItem(id: 'renter', name: 'CA renter’s credit', category: 'California', cue: 'Income limits apply', formHint: 'CA Form 540', organizerFocus: 'state_returns'),
  ];

  /// claimed = true, ask preparer = false, untouched = absent
  final Map<String, bool> _status = {};
  String _tab = 'All';
  String _mode = 'interview'; // interview | checklist
  int _interviewIndex = 0;
  bool _saving = false;
  bool _loadingPlan = false;
  List<Map<String, dynamic>> _valueSavings = const [];
  String? _planDisclaimer;
  String? _error;

  List<String> get _categories => [
        'All',
        ...{for (final i in _items) i.category},
      ];

  List<_SavingItem> get _filtered {
    if (_tab == 'All') return _items;
    return _items.where((i) => i.category == _tab).toList();
  }

  int get _claimed => _status.values.where((v) => v).length;
  int get _missed => _status.values.where((v) => !v).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateChecklist();
      _loadValueSavings();
    });
  }

  Future<void> _hydrateChecklist() async {
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) return;
      final org = await ref.read(laravelOrganizerRepositoryProvider).show(workspaceId);
      final sections = org?['sections'];
      final answersRoot = sections is Map ? sections['answers'] : null;
      if (answersRoot is! Map) return;
      final credits = answersRoot['credits_deductions'];
      final checklist = credits is Map ? credits['tax_savings_checklist'] : null;
      if (checklist is! Map || !mounted) return;
      setState(() {
        for (final e in checklist.entries) {
          final v = e.value?.toString();
          if (v == 'claim') _status['${e.key}'] = true;
          if (v == 'ask_preparer') _status['${e.key}'] = false;
        }
      });
    } catch (_) {}
  }

  Future<void> _persistChecklist() async {
    final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
    if (workspaceId == null) return;
    setState(() => _saving = true);
    try {
      final map = <String, String>{};
      for (final e in _status.entries) {
        map[e.key] = e.value ? 'claim' : 'ask_preparer';
      }
      await ref.read(laravelOrganizerRepositoryProvider).updateSection(
            workspaceId: workspaceId,
            sectionKey: 'credits_deductions',
            answers: {'tax_savings_checklist': map},
          );
    } catch (e) {
      if (mounted) {
        setState(() => _error = ApiErrorMapper.map(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadValueSavings() async {
    final api = ref.read(laravelApiClientProvider);
    if (api.bearerToken == null) return;
    setState(() {
      _loadingPlan = true;
      _error = null;
    });
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final tax = ref.read(taxYearProvider);
      final res = await api.post<Map<String, dynamic>>(
        '/api/v1/tessa/assist/planning',
        data: {
          'tax_year': tax.selectedYear ?? tax.currentFilingYear ?? 2025,
          'home_state': 'CA',
          if (tax.workspace?.workspaceId != null) 'workspace_id': tax.workspace!.workspaceId,
        },
      );
      if (!PlatformApi.ok(res)) {
        throw StateError(ApiErrorMapper.mapStatusCode(res.statusCode));
      }
      final map = PlatformApi.unwrapMap(res) ?? {};
      final savings = map['value_savings'] ?? map['strategies'];
      if (!mounted) return;
      setState(() {
        _valueSavings = savings is List
            ? savings.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : const [];
        _planDisclaimer = map['disclaimer']?.toString();
        _loadingPlan = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPlan = false;
          _error = ApiErrorMapper.map(e);
        });
      }
    }
  }

  void _answerInterview(bool claim) {
    final item = _filtered[_interviewIndex.clamp(0, _filtered.length - 1)];
    setState(() {
      _status[item.id] = claim;
      if (_interviewIndex < _filtered.length - 1) {
        _interviewIndex += 1;
      }
    });
    _persistChecklist();
  }

  @override
  Widget build(BuildContext context) {
    final interviewItem = _filtered.isEmpty
        ? null
        : _filtered[_interviewIndex.clamp(0, _filtered.length - 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/tools'), icon: const Icon(Icons.arrow_back)),
            const Expanded(
              child: Text('Tax savings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Guided interview or direct checklist maps ideas onto Form 1040 / CA 540 / Schedule C lines. '
          'Tessa value savings are propose-only from Laravel — not a formal tax opinion.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'interview', label: Text('Interview'), icon: Icon(Icons.forum_outlined)),
            ButtonSegment(value: 'checklist', label: Text('Checklist'), icon: Icon(Icons.checklist)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _interviewIndex = 0;
          }),
        ),
        const SizedBox(height: 12),
        MkgCard(
          child: Row(
            children: [
              Expanded(child: _stat('Claiming', '$_claimed', MkgColors.green)),
              Expanded(child: _stat('Review', '$_missed', MkgColors.orange)),
              Expanded(child: _stat('Total ideas', '${_items.length}', MkgColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Value savings (in-app)', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(
              onPressed: _loadingPlan ? null : _loadValueSavings,
              child: Text(_loadingPlan ? 'Refreshing…' : 'Refresh'),
            ),
          ],
        ),
        if (_planDisclaimer != null)
          Text(_planDisclaimer!, style: const TextStyle(color: MkgColors.textGrey, fontSize: 11)),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        if (_valueSavings.isEmpty && !_loadingPlan)
          const Text(
            'Run Organizer income/credits first, then refresh for Tessa recommendations.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
          ),
        for (final s in _valueSavings.take(6))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${s['title'] ?? 'Strategy'}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${s['rationale'] ?? ''}\nImpact: ${s['estimated_impact_band'] ?? s['estimatedImpactBand'] ?? '—'}',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
              isThreeLine: true,
              trailing: StatusChip(
                label: '${s['priority'] ?? 'review'}',
                color: MkgColors.primary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _tab == c,
                    onSelected: (_) => setState(() {
                      _tab = c;
                      _interviewIndex = 0;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_mode == 'interview' && interviewItem != null) ...[
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_interviewIndex + 1} of ${_filtered.length}',
                  style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(interviewItem.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                Text(interviewItem.cue, style: const TextStyle(color: MkgColors.textGrey)),
                const SizedBox(height: 8),
                Text('Maps to: ${interviewItem.formHint}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _answerInterview(true),
                      child: const Text('I claim / want this'),
                    ),
                    OutlinedButton(
                      onPressed: () => _answerInterview(false),
                      child: const Text('Ask preparer'),
                    ),
                    TextButton(
                      onPressed: () => context.go(
                        '/organizer?mode=interview&focus=${interviewItem.organizerFocus}',
                      ),
                      child: const Text('Open form lines'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          for (final item in _filtered)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(item.cue, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
                    Text(item.formHint, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('I claim this'),
                          selected: _status[item.id] == true,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _status[item.id] = true;
                              } else {
                                _status.remove(item.id);
                              }
                            });
                            _persistChecklist();
                          },
                        ),
                        FilterChip(
                          label: const Text('Ask preparer'),
                          selected: _status[item.id] == false,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _status[item.id] = false;
                              } else {
                                _status.remove(item.id);
                              }
                            });
                            _persistChecklist();
                          },
                        ),
                        TextButton(
                          onPressed: () => context.go(
                            '/organizer?mode=direct&focus=${item.organizerFocus}',
                          ),
                          child: const Text('Form lines'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.go('/forms/entry'),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Interview or direct input — 1040 / 540 / C / 1120'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/organizer'),
          icon: const Icon(Icons.folder_open),
          label: const Text('Open Tax Organizer'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/tessa'),
          icon: const Icon(Icons.smart_toy_outlined),
          label: const Text('Preview return with Tessa'),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
      ],
    );
  }
}
