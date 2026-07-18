import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/us_states.dart';
import 'organizer_fields.dart';

/// Multi-state intake (all 50 + DC) plus deep California forms from assets.
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

  @override
  Widget build(BuildContext context) {
    final rows = _additional;
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

    return Column(
      children: [
        OrganizerSection(
          title: 'Home state',
          subtitle: 'Address state from Personal Info. California deep forms are below; add every other state where you had income or nexus.',
          child: MkgCard(
            child: Text(
              homeState.isEmpty
                  ? 'No home state set yet — complete Personal Info first.'
                  : 'Home state: $homeState'
                      '${statesWithIncomeTax.contains(homeState) ? ' (income tax state)' : ' (no personal income tax / special rules)'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        OrganizerSection(
          title: 'Additional state returns',
          subtitle: 'All 50 states + DC. Non-CA jurisdictions are intake for professional review (mobile filing engine is CA-first).',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'State return ${i + 1}',
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
                        value: usStateOptions.any((e) => e.$1 == '${rows[i]['stateCode']}')
                            ? '${rows[i]['stateCode']}'
                            : 'NY',
                        items: usStateOptions,
                        onChanged: (v) {
                          final code = v ?? 'NY';
                          final next = List<Map<String, dynamic>>.from(rows);
                          next[i] = Map<String, dynamic>.from(next[i])
                            ..['stateCode'] = code
                            ..['filingRequired'] = statesWithIncomeTax.contains(code);
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
                      if ('${rows[i]['stateCode']}' != 'CA')
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Detailed non-CA state return forms are prepared by your tax professional from this intake.',
                            style: TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.35),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final used = rows.map((e) => '${e['stateCode']}').toSet();
                  final nextCode = usStateOptions
                      .map((e) => e.$1)
                      .firstWhere((c) => c != homeState && !used.contains(c), orElse: () => 'NY');
                  onList('additionalStateReturns', [...rows, emptyAdditionalStateReturn(stateCode: nextCode)]);
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add state return'),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'California Form 540',
          subtitle: 'Canonical ca540 keys matching the web portal.',
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
        OrganizerSection(
          title: 'Form 540X — Amended CA return',
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
          subtitle: 'Also used with entity prep types (100 / 100S / 565 / 541 / 199).',
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
