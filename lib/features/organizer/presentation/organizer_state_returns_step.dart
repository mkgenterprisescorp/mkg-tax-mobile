import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/official_form_links.dart';
import '../data/us_states.dart';
import 'organizer_fields.dart';

/// Multi-state intake for every personal-income-tax jurisdiction + CA deep forms.
class OrganizerStateReturnsStep extends StatelessWidget {
  const OrganizerStateReturnsStep({
    super.key,
    required this.data,
    required this.onRoot,
    required this.onNested,
    required this.onList,
  });

  final Map<String, dynamic> data;
  final void Function(String key, dynamic value) onRoot;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;
  final void Function(String key, List<Map<String, dynamic>> rows) onList;

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from((data[key] as Map?) ?? {});

  List<Map<String, dynamic>> get _additional {
    final raw = (data['additionalStateReturns'] as List?) ?? const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  void _toggleIncomeTaxState(String code, bool enabled, String homeState) {
    final rows = _additional;
    final exists = rows.any((e) => '${e['stateCode']}' == code);
    if (enabled && !exists) {
      onList('additionalStateReturns', [
        ...rows,
        emptyAdditionalStateReturn(
          stateCode: code,
          residencyType: code == homeState ? 'resident' : 'nonresident',
        ),
      ]);
    } else if (!enabled && exists) {
      onList(
        'additionalStateReturns',
        rows.where((e) => '${e['stateCode']}' != code).toList(),
      );
    }
  }

  void _addAllIncomeTaxStates(String homeState) {
    final existing = {for (final r in _additional) '${r['stateCode']}'};
    final next = List<Map<String, dynamic>>.from(_additional);
    for (final code in statesWithIncomeTax) {
      if (existing.contains(code)) continue;
      next.add(
        emptyAdditionalStateReturn(
          stateCode: code,
          residencyType: code == homeState ? 'resident' : 'nonresident',
        ),
      );
    }
    // Stable sort: home first, then alpha by code.
    next.sort((a, b) {
      final ac = '${a['stateCode']}';
      final bc = '${b['stateCode']}';
      if (ac == homeState) return -1;
      if (bc == homeState) return 1;
      return ac.compareTo(bc);
    });
    onList('additionalStateReturns', next);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _additional;
    final selected = {for (final r in rows) '${r['stateCode']}'};
    final homeState = '${data['state'] ?? ''}'.toUpperCase();
    final ca540 = Map<String, dynamic>.from(_map('ca540'));
    if (ca540.isEmpty) {
      ca540.addAll({
        'residencyStatus': homeState == 'CA' ? 'resident' : 'nonresident',
        'stateWages': data['wages'] ?? 0,
        'caWithholding': 0,
        'estimatedPayments': 0,
      });
    }

    final incomeTaxSelectedCount =
        selected.where(statesWithIncomeTax.contains).length;

    return Column(
      children: [
        OrganizerSection(
          title: 'Home state',
          subtitle: 'Address state from Personal Info.',
          child: MkgCard(
            child: Text(
              homeState.isEmpty
                  ? 'No home state set yet — complete Personal Info first.'
                  : 'Home state: $homeState · ${displayNameForState(homeState)}'
                      '${statesWithIncomeTax.contains(homeState) ? ' (personal income tax)' : ' (no broad personal income tax)'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        OrganizerSection(
          title: 'Personal income tax states (${statesWithIncomeTax.length})',
          subtitle:
              'Select every income-tax jurisdiction where you lived, worked, or had nexus. '
              'California includes the deep Form 540 suite below; other states are organizer intake for professional review.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$incomeTaxSelectedCount of ${statesWithIncomeTax.length} income-tax states selected',
                style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addAllIncomeTaxStates(homeState),
                    icon: const Icon(Icons.select_all),
                    label: const Text('Add all income-tax states'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onList('additionalStateReturns', const []),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final opt in incomeTaxStateOptions)
                    FilterChip(
                      label: Text(opt.$1),
                      selected: selected.contains(opt.$1),
                      onSelected: (v) => _toggleIncomeTaxState(opt.$1, v, homeState),
                      selectedColor: MkgColors.primary.withValues(alpha: 0.18),
                      checkmarkColor: MkgColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected.contains(opt.$1) ? MkgColors.primary : MkgColors.dark,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Selected state return details',
          subtitle: 'Enter wages, withholding, and residency for each selected income-tax state.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No states selected yet. Tap chips above or “Add all income-tax states”.',
                    style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
                  ),
                ),
              for (var i = 0; i < rows.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${rows[i]['stateCode']} · ${displayNameForState('${rows[i]['stateCode']}')}'
                              '${statesWithIncomeTax.contains('${rows[i]['stateCode']}') ? '' : ' (no income tax)'}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(rows)..removeAt(i);
                              onList('additionalStateReturns', next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerDropdown<String>(
                        label: 'State',
                        value: incomeTaxStateOptions.any((e) => e.$1 == '${rows[i]['stateCode']}') ||
                                usStateOptions.any((e) => e.$1 == '${rows[i]['stateCode']}')
                            ? '${rows[i]['stateCode']}'
                            : 'NY',
                        items: [
                          ...incomeTaxStateOptions,
                          // Keep non-income-tax available for specialty/nexus rows.
                          for (final opt in usStateOptions)
                            if (!statesWithIncomeTax.contains(opt.$1)) opt,
                        ],
                        onChanged: (v) {
                          final code = v ?? 'NY';
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['stateCode'] = code
                            ..['filingRequired'] = statesWithIncomeTax.contains(code)
                            ..['hasPersonalIncomeTax'] = statesWithIncomeTax.contains(code)
                            ..['professionalReview'] = code != 'CA';
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerDropdown<String>(
                        label: 'Residency',
                        value: residencyTypeOptions.any((e) => e.$1 == '${rows[i]['residencyType']}')
                            ? '${rows[i]['residencyType']}'
                            : 'nonresident',
                        items: residencyTypeOptions,
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['residencyType'] = v ?? 'nonresident';
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerTextField(
                        label: 'Reason (work, property, nexus, etc.)',
                        value: '${rows[i]['reason'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['reason'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'State wages / income',
                        value: rows[i]['wages'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['wages'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'State withholding',
                        value: rows[i]['withholding'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['withholding'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerMoneyField(
                        label: 'Estimated payments',
                        value: rows[i]['estimatedPayments'],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['estimatedPayments'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerCheckbox(
                        label: 'Filing likely required',
                        value: rows[i]['filingRequired'] == true,
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['filingRequired'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                      OrganizerCheckbox(
                        label: 'Flag for professional review',
                        value: rows[i]['professionalReview'] != false,
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])..['professionalReview'] = v;
                          onList('additionalStateReturns', next);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const OfficialFormLinksCard(
          title: 'Official California Form 540 (complete)',
          subtitle: 'FTB tax year 2025 — booklet, instructions, and blank form.',
          links: [
            ('2025 Form 540 booklet', OfficialFormLinks.ca540Booklet),
            ('2025 Form 540 instructions', OfficialFormLinks.ca540Instructions),
            ('2025 Form 540 PDF', OfficialFormLinks.ca540Pdf),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/ca-540'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Open Form 540 tax & refund calculator'),
        ),
        const SizedBox(height: 12),
        OrganizerSection(
          title: 'California Form 540',
          subtitle: 'Deep CA suite — available when CA is home or selected above.',
          child: NestedMapEditor(
            data: ca540,
            onlyKeys: const [
              'residencyStatus',
              'stateWages',
              'federalAGI',
              'caAGI',
              'taxableIncome',
              'caWithholding',
              'estimatedPayments',
              'caTax',
              'calEITC',
              'youngChildTaxCredit',
              'fosterYouthTaxCredit',
              'rentersCredit',
              'childDependentCareCredit',
              'useTax',
            ].where(ca540.containsKey).toList(),
            onChanged: (m) => onNested('ca540', m),
          ),
        ),
        OrganizerSection(
          title: 'California Form 540 — additional fields',
          child: NestedMapEditor(
            data: ca540,
            excludeKeys: const {
              'residencyStatus',
              'stateWages',
              'federalAGI',
              'caAGI',
              'taxableIncome',
              'caWithholding',
              'estimatedPayments',
              'caTax',
              'calEITC',
              'youngChildTaxCredit',
              'fosterYouthTaxCredit',
              'rentersCredit',
              'childDependentCareCredit',
              'useTax',
            },
            onChanged: (m) => onNested('ca540', m),
          ),
        ),
        OrganizerSection(
          title: 'Schedule CA (540)',
          child: NestedMapEditor(data: _map('scheduleCA'), onChanged: (m) => onNested('scheduleCA', m)),
        ),
        OrganizerSection(
          title: 'FTB 3514 — CalEITC / YCTC / FYTC',
          child: NestedMapEditor(data: _map('ftb3514'), onChanged: (m) => onNested('ftb3514', m)),
        ),
        OrganizerSection(
          title: 'FTB 3506 — CA child & dependent care',
          child: NestedMapEditor(data: _map('ftb3506'), onChanged: (m) => onNested('ftb3506', m)),
        ),
        OrganizerSection(
          title: 'Schedule P (540) — CA AMT',
          child: NestedMapEditor(data: _map('scheduleP540'), onChanged: (m) => onNested('scheduleP540', m)),
        ),
        OrganizerSection(
          title: 'Schedule S — Other state tax credit',
          child: NestedMapEditor(data: _map('scheduleS'), onChanged: (m) => onNested('scheduleS', m)),
        ),
        const OfficialFormLinksCard(
          title: 'Official California Form 540-X',
          subtitle: 'Amended California resident income tax return (FTB 2025).',
          links: [
            ('2025 Form 540-X PDF', OfficialFormLinks.ca540xPdf),
            ('2025 Form 540 booklet (includes Schedule X notes)', OfficialFormLinks.ca540Booklet),
          ],
        ),
        const SizedBox(height: 12),
        OrganizerSection(
          title: 'Form 540X — Amended CA return',
          subtitle: 'Complete when amending a previously filed CA Form 540.',
          child: NestedMapEditor(data: _map('ca540x'), onChanged: (m) => onNested('ca540x', m)),
        ),
        OrganizerSection(
          title: 'CA payment / direct deposit',
          child: Column(
            children: [
              NestedMapEditor(data: _map('caDirectDeposit'), onChanged: (m) => onNested('caDirectDeposit', m)),
              NestedMapEditor(data: _map('caPayment'), onChanged: (m) => onNested('caPayment', m)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'CA business entity forms (if applicable)',
          child: Column(
            children: [
              for (final entry in const [
                ('caForm100', 'Form 100 — C-Corp'),
                ('caForm100S', 'Form 100S — S-Corp'),
                ('caForm565', 'Form 565 — Partnership'),
                ('caForm541', 'Form 541 — Fiduciary'),
                ('caForm199', 'Form 199 — Exempt org'),
                ('caScheduleR', 'CA Schedule R'),
                ('caScheduleK1', 'CA Schedule K-1'),
              ]) ...[
                Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                NestedMapEditor(data: _map(entry.$1), onChanged: (m) => onNested(entry.$1, m)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
