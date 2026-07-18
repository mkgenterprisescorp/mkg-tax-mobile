import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../states/data/state_workflow_repository.dart';
import '../data/official_form_links.dart';
import '../data/us_states.dart';
import 'organizer_ca540_form.dart';
import 'organizer_ca_business_forms.dart';
import 'organizer_fields.dart';
import 'organizer_nationwide_form.dart';

/// Multi-state intake for every personal-income-tax jurisdiction + CA deep forms
/// + nationwide business/franchise state workflows.
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

  List<Map<String, dynamic>> get _businessRows {
    final raw = (data['stateBusinessReturns'] as List?) ?? const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  String get _prepFamily => returnFamilyForPrepType('${data['prepType'] ?? 'personal'}');

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
              'California includes the deep Form 540 suite below; other states open nationwide form workflows (intake-only).',
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
                      if ('${rows[i]['stateCode']}' != 'CA') ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Open ${rows[i]['stateCode']} nationwide form workflow',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Official primary form fields · intake only',
                            style: TextStyle(fontSize: 12),
                          ),
                          children: [
                            OrganizerNationwideForm(
                              stateCode: '${rows[i]['stateCode']}',
                              family: 'individual',
                              filingType: filingTypeForResidency('${rows[i]['residencyType'] ?? 'nonresident'}'),
                              answers: Map<String, dynamic>.from(
                                (rows[i]['workflowAnswers'] as Map?) ??
                                    {
                                      'residencyType': rows[i]['residencyType'],
                                      'stateWages': rows[i]['wages'],
                                      'stateWithholding': rows[i]['withholding'],
                                      'estimatedPayments': rows[i]['estimatedPayments'],
                                      'filingRequired': rows[i]['filingRequired'],
                                      'professionalReview': rows[i]['professionalReview'],
                                    },
                              ),
                              onChanged: (answers) {
                                final next = List<Map<String, dynamic>>.from(rows);
                                final row = Map<String, dynamic>.from(next[i]);
                                row['workflowAnswers'] = answers;
                                if (answers['stateWages'] != null) row['wages'] = answers['stateWages'];
                                if (answers['stateWithholding'] != null) {
                                  row['withholding'] = answers['stateWithholding'];
                                }
                                if (answers['estimatedPayments'] != null) {
                                  row['estimatedPayments'] = answers['estimatedPayments'];
                                }
                                if (answers['residencyType'] != null) {
                                  row['residencyType'] = answers['residencyType'];
                                }
                                if (answers['filingRequired'] != null) {
                                  row['filingRequired'] = answers['filingRequired'];
                                }
                                if (answers['professionalReview'] != null) {
                                  row['professionalReview'] = answers['professionalReview'];
                                }
                                next[i] = row;
                                onList('additionalStateReturns', next);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        OrganizerSection(
          title: 'Business / franchise / nonprofit state forms',
          subtitle:
              'Nationwide entity workflows for corporation, S-corp, partnership, fiduciary, and exempt orgs '
              '(TX franchise, FL corporate, WA B&O, etc.). California entity forms remain in the CA suite below.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final family = _prepFamily == 'individual' ? 'corporation' : _prepFamily;
                      onList('stateBusinessReturns', [
                        ..._businessRows,
                        emptyBusinessStateReturn(
                          stateCode: homeState.isEmpty || homeState == 'CA' ? 'TX' : homeState,
                          returnFamily: family,
                        ),
                      ]);
                    },
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add business state return'),
                  ),
                  if (_businessRows.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => onList('stateBusinessReturns', const []),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear business states'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_businessRows.isEmpty)
                const Text(
                  'No business state returns yet. Add one for each formation / nexus jurisdiction.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
                ),
              for (var i = 0; i < _businessRows.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_businessRows[i]['stateCode']} · ${_businessRows[i]['returnFamily']}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(_businessRows)..removeAt(i);
                              onList('stateBusinessReturns', next);
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerDropdown<String>(
                        label: 'State',
                        value: usStateOptions.any((e) => e.$1 == '${_businessRows[i]['stateCode']}')
                            ? '${_businessRows[i]['stateCode']}'
                            : 'TX',
                        items: [
                          for (final opt in usStateOptions)
                            if (opt.$1 != 'CA') opt,
                        ],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(_businessRows);
                          next[i] = Map<String, dynamic>.from(next[i])..['stateCode'] = v ?? 'TX';
                          onList('stateBusinessReturns', next);
                        },
                      ),
                      OrganizerDropdown<String>(
                        label: 'Return family',
                        value: const [
                          'corporation',
                          's_corporation',
                          'partnership',
                          'fiduciary',
                          'exempt_organization',
                          'exempt_organization_ez',
                        ].contains('${_businessRows[i]['returnFamily']}')
                            ? '${_businessRows[i]['returnFamily']}'
                            : 'corporation',
                        items: const [
                          ('corporation', 'Corporation'),
                          ('s_corporation', 'S-Corporation'),
                          ('partnership', 'Partnership'),
                          ('fiduciary', 'Fiduciary'),
                          ('exempt_organization', 'Exempt organization'),
                          ('exempt_organization_ez', 'Exempt organization (EZ)'),
                        ],
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(_businessRows);
                          next[i] = Map<String, dynamic>.from(next[i])..['returnFamily'] = v ?? 'corporation';
                          onList('stateBusinessReturns', next);
                        },
                      ),
                      if ('${_businessRows[i]['stateCode']}' != 'CA')
                        OrganizerLazyExpansion(
                          title: 'Open ${_businessRows[i]['stateCode']} business intake form',
                          subtitle: 'Loads workflow fields on expand',
                          child: OrganizerNationwideForm(
                            stateCode: '${_businessRows[i]['stateCode']}',
                            family: '${_businessRows[i]['returnFamily'] ?? 'corporation'}',
                            filingType: 'standard',
                            answers: Map<String, dynamic>.from(
                              (_businessRows[i]['workflowAnswers'] as Map?) ?? const {},
                            ),
                            onChanged: (answers) {
                              final next = List<Map<String, dynamic>>.from(_businessRows);
                              next[i] = Map<String, dynamic>.from(next[i])..['workflowAnswers'] = answers;
                              onList('stateBusinessReturns', next);
                            },
                          ),
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
        OrganizerSection(
          title: 'California Form 540',
          subtitle: 'Complete FTB Form 540 lines — residency dropdown, payments, credits, and live refund estimate.',
          child: OrganizerCa540Form(
            ca540: ca540,
            filingStatus: '${data['filingStatus'] ?? 'single'}',
            homeState: homeState,
            onChanged: (m) => onNested('ca540', m),
          ),
        ),
        // Secondary CA schedules / business forms stay collapsed until opened
        // so State Tax Returns paints quickly.
        OrganizerLazyExpansion(
          title: 'Schedule CA (540)',
          child: NestedMapEditor(data: _map('scheduleCA'), onChanged: (m) => onNested('scheduleCA', m)),
        ),
        OrganizerLazyExpansion(
          title: 'FTB 3514 — CalEITC / YCTC / FYTC',
          child: NestedMapEditor(data: _map('ftb3514'), onChanged: (m) => onNested('ftb3514', m)),
        ),
        OrganizerLazyExpansion(
          title: 'FTB 3506 — CA child & dependent care',
          child: NestedMapEditor(data: _map('ftb3506'), onChanged: (m) => onNested('ftb3506', m)),
        ),
        OrganizerLazyExpansion(
          title: 'Schedule P (540) — CA AMT',
          child: NestedMapEditor(data: _map('scheduleP540'), onChanged: (m) => onNested('scheduleP540', m)),
        ),
        OrganizerLazyExpansion(
          title: 'Schedule S — Other state tax credit',
          child: NestedMapEditor(data: _map('scheduleS'), onChanged: (m) => onNested('scheduleS', m)),
        ),
        OrganizerLazyExpansion(
          title: 'Form 540-X — Amended CA return',
          subtitle: 'Official PDF + amended return fields',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfficialFormLinksCard(
                title: 'Official California Form 540-X',
                subtitle: 'Amended California resident income tax return (FTB 2025).',
                links: [
                  ('2025 Form 540-X PDF', OfficialFormLinks.ca540xPdf),
                  ('2025 Form 540 booklet (includes Schedule X notes)', OfficialFormLinks.ca540Booklet),
                ],
              ),
              const SizedBox(height: 8),
              NestedMapEditor(data: _map('ca540x'), onChanged: (m) => onNested('ca540x', m)),
            ],
          ),
        ),
        OrganizerLazyExpansion(
          title: 'CA payment / direct deposit',
          child: Column(
            children: [
              NestedMapEditor(data: _map('caDirectDeposit'), onChanged: (m) => onNested('caDirectDeposit', m)),
              NestedMapEditor(data: _map('caPayment'), onChanged: (m) => onNested('caPayment', m)),
            ],
          ),
        ),
        OrganizerLazyExpansion(
          title: 'California business entity forms',
          subtitle: 'Form 100 / 100S / 565 / 541 / 199 — expand to load',
          child: OrganizerCaBusinessForms(
            data: data,
            onNested: onNested,
          ),
        ),
      ],
    );
  }
}
