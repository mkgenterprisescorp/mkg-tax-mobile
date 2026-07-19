import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ca540_estimate_math.dart';
import '../data/computed_field_policy.dart';
import '../data/federal_agi_math.dart';
import '../data/us_states.dart';
import 'organizer_computed_money_field.dart';
import 'organizer_fields.dart';

/// Complete California Form 540 typed entry (web Organizer step 5 parity).
class OrganizerCa540Form extends ConsumerWidget {
  const OrganizerCa540Form({
    super.key,
    required this.ca540,
    required this.filingStatus,
    required this.homeState,
    required this.onChanged,
    this.organizerData = const {},
  });

  final Map<String, dynamic> ca540;
  final String filingStatus;
  final String homeState;
  final ValueChanged<Map<String, dynamic>> onChanged;
  /// Root organizer answers — used to auto-calculate Federal AGI / CA withholding.
  final Map<String, dynamic> organizerData;

  void _patch(String key, dynamic value) {
    onChanged(Map<String, dynamic>.from(ca540)..[key] = value);
  }

  void _patchAll(Map<String, dynamic> patch) {
    onChanged({...ca540, ...patch});
  }

  String get _residency {
    final raw = '${ca540['residencyStatus'] ?? ''}';
    if (residencyTypeOptions.any((e) => e.$1 == raw)) return raw;
    return homeState == 'CA' ? 'resident' : 'nonresident';
  }

  static const _typedKeys = {
    'residencyStatus',
    'filedCA',
    'stateWages',
    'caWages',
    'federalAGI',
    'caSubtractions',
    'caAdditions',
    'caAGI',
    'deductionType',
    'standardDeduction',
    'itemizedDeduction',
    'taxableIncome',
    'personalExemptions',
    'blindExemptions',
    'seniorExemptions',
    'dependentExemptions',
    'exemptionCredits',
    'caTax',
    'scheduleTax',
    'childDependentCareCredit',
    'creditName1',
    'creditCode1',
    'creditAmount1',
    'creditName2',
    'creditCode2',
    'creditAmount2',
    'rentersCredit',
    'otherCredits',
    'amt',
    'behavioralHealthTax',
    'otherTaxes',
    'caWithholding',
    'caTaxWithheld',
    'estimatedPayments',
    'caEstimatedPayments',
    'withholding592B593',
    'motionPictureCredit',
    'calEITC',
    'youngChildTaxCredit',
    'fosterYouthTaxCredit',
    'ihssPayments',
    'useTax',
    'useTaxOwed',
    'healthCareCoverage',
    'isrPenalty',
    'interestPenalties',
    'penaltyUnderpayment',
    'applyToEstimated',
    'totalTax',
    'totalPayments',
    'refundOrOwed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = capabilitiesFor(ref.watch(authProvider).user?.role).isProfessional;
    final synced = syncFederalAgi({...organizerData, 'ca540': ca540});
    final computedAgi = estimateFederalAgi(synced);
    final computedCaWh = () {
      num caWh = 0;
      for (final w2 in ((synced['w2Forms'] as List?) ?? const [])) {
        if (w2 is! Map) continue;
        final state = '${w2['box15_state'] ?? ''}'.toUpperCase();
        if (state.isEmpty || state == 'CA') {
          caWh += _n(w2['box17_stateTax']);
        }
      }
      return caWh;
    }();
    final summary = summarizeCa540(ca540: ca540, filingStatus: filingStatus);
    final deductionType = '${ca540['deductionType'] ?? 'standard'}';
    final health = ca540['healthCareCoverage'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerSection(
          title: 'CA refund & tax tools',
          subtitle: 'Use existing calculator screens — values sync back into this Form 540.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/ca-540'),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('CA Form 540 tax & refund calculator'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/refund-advance/estimate'),
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Federal refund estimator'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/documents/smart-intake'),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Smart upload (W-2 / CA docs)'),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Residency & filing status',
          child: Column(
            children: [
              OrganizerDropdown<String>(
                label: 'California residency status',
                value: _residency,
                items: residencyTypeOptions,
                onChanged: (v) => _patch('residencyStatus', v ?? 'resident'),
              ),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Filing status (from federal)'),
                child: Text(
                  filingStatus.replaceAll('_', ' '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              OrganizerCheckbox(
                label: 'Filing a California Form 540 this year',
                value: ca540['filedCA'] != false,
                onChanged: (v) => _patch('filedCA', v),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Exemptions (Lines 7–11)',
          child: Column(
            children: [
              _intField('Personal exemptions (Line 7)', ca540['personalExemptions'] ?? 1, (v) => _patch('personalExemptions', v)),
              _intField('Blind exemptions (Line 8)', ca540['blindExemptions'], (v) => _patch('blindExemptions', v)),
              _intField('Senior exemptions (Line 9)', ca540['seniorExemptions'], (v) => _patch('seniorExemptions', v)),
              _intField('Dependent exemptions (Line 10)', ca540['dependentExemptions'], (v) => _patch('dependentExemptions', v)),
              _summaryRow('Line 11 — Exemption credits (est.)', summary.exemptionCredits),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Taxable income (Lines 12–19)',
          child: Column(
            children: [
              OrganizerMoneyField(
                label: 'Line 12 — CA wages',
                value: ca540['stateWages'] ?? ca540['caWages'],
                onChanged: (v) => _patchAll({'stateWages': v, 'caWages': v}),
              ),
              OrganizerComputedMoneyField(
                policy: ComputedFieldPolicy.federalAgi,
                computedValue: computedAgi,
                storedValue: ca540['federalAGI'],
                isOverridden: ComputedFieldPolicy.isOverridden(ca540, 'federalAGI'),
                isProfessional: isPro,
                onApplyComputed: () => _patch('federalAGI', computedAgi),
                onManualValue: (v) => _patchAll(
                  ComputedFieldPolicy.markOverridden(
                    {...ca540, 'federalAGI': v},
                    'federalAGI',
                    byProfessional: isPro,
                  ),
                ),
                onMarkOverridden: () => _patchAll(
                  ComputedFieldPolicy.markOverridden(ca540, 'federalAGI', byProfessional: isPro),
                ),
                onClearOverride: () {
                  final cleared = ComputedFieldPolicy.clearOverride(ca540, 'federalAGI');
                  cleared['federalAGI'] = computedAgi;
                  onChanged(cleared);
                },
              ),
              OrganizerMoneyField(
                label: 'Line 14 — CA subtractions (Schedule CA)',
                value: ca540['caSubtractions'],
                onChanged: (v) => _patch('caSubtractions', v),
              ),
              OrganizerMoneyField(
                label: 'Line 16 — CA additions (Schedule CA)',
                value: ca540['caAdditions'],
                onChanged: (v) => _patch('caAdditions', v),
              ),
              _summaryRow('Line 17 — CA AGI (est.)', summary.caAgi),
              OrganizerDropdown<String>(
                label: 'Line 18 — Deduction type',
                value: deductionType == 'itemized' ? 'itemized' : 'standard',
                items: const [
                  ('standard', 'Standard deduction'),
                  ('itemized', 'Itemized deduction'),
                ],
                onChanged: (v) => _patch('deductionType', v ?? 'standard'),
              ),
              if (deductionType == 'itemized')
                OrganizerMoneyField(
                  label: 'Line 18 — Itemized deduction amount',
                  value: ca540['itemizedDeduction'],
                  onChanged: (v) => _patch('itemizedDeduction', v),
                )
              else
                _summaryRow('Line 18 — Standard deduction (est.)', summary.deduction),
              _summaryRow('Line 19 — Taxable income (est.)', summary.taxableIncome),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Tax (Lines 31–35)',
          child: Column(
            children: [
              _summaryRow('Line 31 — Tax on taxable income (est.)', summary.caTax),
              _summaryRow('Line 32 — Exemption credits (est.)', summary.exemptionCredits),
              OrganizerMoneyField(
                label: 'Line 34 — Schedule tax / special tax',
                value: ca540['scheduleTax'],
                onChanged: (v) => _patch('scheduleTax', v),
              ),
              _summaryRow(
                'Line 35 — Tax after exemptions (est.)',
                (() {
                  final after = summary.caTax - summary.exemptionCredits;
                  final base = after > 0 ? after : 0;
                  return base + _n(ca540['scheduleTax']);
                })(),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Special credits (Lines 40–48)',
          child: Column(
            children: [
              OrganizerMoneyField(
                label: 'Line 40 — Child & dependent care credit',
                value: ca540['childDependentCareCredit'],
                onChanged: (v) => _patch('childDependentCareCredit', v),
              ),
              OrganizerTextField(
                label: 'Credit 1 name',
                value: '${ca540['creditName1'] ?? ''}',
                onChanged: (v) => _patch('creditName1', v),
              ),
              OrganizerTextField(
                label: 'Credit 1 code',
                value: '${ca540['creditCode1'] ?? ''}',
                onChanged: (v) => _patch('creditCode1', v),
              ),
              OrganizerMoneyField(
                label: 'Credit 1 amount',
                value: ca540['creditAmount1'],
                onChanged: (v) => _patch('creditAmount1', v),
              ),
              OrganizerTextField(
                label: 'Credit 2 name',
                value: '${ca540['creditName2'] ?? ''}',
                onChanged: (v) => _patch('creditName2', v),
              ),
              OrganizerTextField(
                label: 'Credit 2 code',
                value: '${ca540['creditCode2'] ?? ''}',
                onChanged: (v) => _patch('creditCode2', v),
              ),
              OrganizerMoneyField(
                label: 'Credit 2 amount',
                value: ca540['creditAmount2'],
                onChanged: (v) => _patch('creditAmount2', v),
              ),
              OrganizerMoneyField(
                label: 'Line 46 — Renters credit',
                value: ca540['rentersCredit'],
                onChanged: (v) => _patch('rentersCredit', v),
              ),
              OrganizerMoneyField(
                label: 'Other nonrefundable credits',
                value: ca540['otherCredits'],
                onChanged: (v) => _patch('otherCredits', v),
              ),
              _summaryRow('Line 48 — Tax after nonrefundable credits', summary.taxAfterCredits),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Other taxes (Lines 61–64)',
          child: Column(
            children: [
              OrganizerMoneyField(
                label: 'Line 61 — Alternative minimum tax (AMT)',
                value: ca540['amt'],
                onChanged: (v) => _patch('amt', v),
              ),
              OrganizerMoneyField(
                label: 'Line 62 — Behavioral health services tax',
                value: ca540['behavioralHealthTax'],
                onChanged: (v) => _patch('behavioralHealthTax', v),
              ),
              OrganizerMoneyField(
                label: 'Line 63 — Other taxes',
                value: ca540['otherTaxes'],
                onChanged: (v) => _patch('otherTaxes', v),
              ),
              _summaryRow('Line 64 — Total tax (est.)', summary.totalTax),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Payments (Lines 71–78)',
          child: Column(
            children: [
              OrganizerComputedMoneyField(
                policy: ComputedFieldPolicy.caWithholding,
                computedValue: computedCaWh > 0
                    ? computedCaWh
                    : _n(ca540['caWithholding'] ?? ca540['caTaxWithheld']),
                storedValue: ca540['caWithholding'] ?? ca540['caTaxWithheld'],
                isOverridden: ComputedFieldPolicy.isOverridden(ca540, 'caWithholding'),
                isProfessional: isPro,
                onApplyComputed: () => _patchAll({
                  'caWithholding': computedCaWh,
                  'caTaxWithheld': computedCaWh,
                }),
                onManualValue: (v) => _patchAll(
                  ComputedFieldPolicy.markOverridden(
                    {...ca540, 'caWithholding': v, 'caTaxWithheld': v},
                    'caWithholding',
                    byProfessional: isPro,
                  ),
                ),
                onMarkOverridden: () => _patchAll(
                  ComputedFieldPolicy.markOverridden(ca540, 'caWithholding', byProfessional: isPro),
                ),
                onClearOverride: () {
                  final cleared = ComputedFieldPolicy.clearOverride(ca540, 'caWithholding');
                  cleared['caWithholding'] = computedCaWh;
                  cleared['caTaxWithheld'] = computedCaWh;
                  onChanged(cleared);
                },
              ),
              OrganizerMoneyField(
                label: 'Line 72 — Estimated payments',
                value: ca540['estimatedPayments'] ?? ca540['caEstimatedPayments'],
                onChanged: (v) => _patchAll({'estimatedPayments': v, 'caEstimatedPayments': v}),
              ),
              OrganizerMoneyField(
                label: 'Line 73 — Withholding (Forms 592-B / 593)',
                value: ca540['withholding592B593'],
                onChanged: (v) => _patch('withholding592B593', v),
              ),
              OrganizerMoneyField(
                label: 'Line 74 — Motion picture credit',
                value: ca540['motionPictureCredit'],
                onChanged: (v) => _patch('motionPictureCredit', v),
              ),
              Builder(
                builder: (_) {
                  final earned = _n(ca540['earnedIncome']) > 0
                      ? _n(ca540['earnedIncome'])
                      : (_n(ca540['stateWages']) > 0
                          ? _n(ca540['stateWages'])
                          : (_n(ca540['federalAGI']) > 0 &&
                                  _n(ca540['federalAGI']) <= kCalEitcMaxEarnedIncome
                              ? _n(ca540['federalAGI'])
                              : 0));
                  final est = estimateCalEitc(
                    earnedIncome: earned,
                    federalAgi: _n(ca540['federalAGI']),
                    investmentIncome: _n(ca540['investmentIncome']),
                    qualifyingChildren: _i(ca540['qualifyingChildren'] ?? ca540['dependentExemptions']),
                    hasYoungChild: ca540['hasYoungChild'] == true || _i(ca540['yctcChildAge']) < 6,
                    hasFosterYouth: ca540['hasFosterYouth'] == true,
                  );
                  final cal = _n(ca540['calEITC']);
                  final yctc = _n(ca540['youngChildTaxCredit']);
                  final fytc = _n(ca540['fosterYouthTaxCredit']);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (est.eligible && (cal <= 0 || yctc <= 0))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _patchAll({
                              if (cal <= 0) 'calEITC': est.calEitc,
                              if (yctc <= 0) 'youngChildTaxCredit': est.youngChildTaxCredit,
                              if (fytc <= 0) 'fosterYouthTaxCredit': est.fosterYouthTaxCredit,
                              'earnedIncome': est.earnedIncome,
                              'qualifyingChildren': est.qualifyingChildren,
                            }),
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              'Apply FTB 3514 estimate — CalEITC \$${est.calEitc}'
                              '${est.youngChildTaxCredit > 0 ? ' · YCTC \$${est.youngChildTaxCredit}' : ''}',
                            ),
                          ),
                        ),
                      OrganizerMoneyField(
                        label: 'Line 75 — CalEITC (FTB 3514)',
                        value: cal,
                        onChanged: (v) => _patch('calEITC', v),
                      ),
                      OrganizerMoneyField(
                        label: 'Line 76 — Young child tax credit',
                        value: yctc,
                        onChanged: (v) => _patch('youngChildTaxCredit', v),
                      ),
                      OrganizerMoneyField(
                        label: 'Line 77 — Foster youth tax credit',
                        value: fytc,
                        onChanged: (v) => _patch('fosterYouthTaxCredit', v),
                      ),
                    ],
                  );
                },
              ),
              OrganizerMoneyField(
                label: 'FTB 3514 — IHSS payments',
                value: ca540['ihssPayments'],
                onChanged: (v) => _patch('ihssPayments', v),
              ),
              _summaryRow('Line 78 — Total payments (est.)', summary.totalPayments),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Use tax & health coverage (Lines 91–92)',
          child: Column(
            children: [
              OrganizerMoneyField(
                label: 'Line 91 — Use tax',
                value: ca540['useTax'],
                onChanged: (v) => _patch('useTax', v),
              ),
              OrganizerCheckbox(
                label: 'Line 92 — Full-year health care coverage',
                value: health,
                onChanged: (v) => _patch('healthCareCoverage', v),
              ),
              if (!health)
                OrganizerMoneyField(
                  label: 'ISR penalty',
                  value: ca540['isrPenalty'],
                  onChanged: (v) => _patch('isrPenalty', v),
                ),
              OrganizerMoneyField(
                label: 'Line 112 — Interest & late penalties',
                value: ca540['interestPenalties'],
                onChanged: (v) => _patch('interestPenalties', v),
              ),
              OrganizerMoneyField(
                label: 'Line 113 — Underpayment of estimated tax',
                value: ca540['penaltyUnderpayment'],
                onChanged: (v) => _patch('penaltyUnderpayment', v),
              ),
              OrganizerMoneyField(
                label: 'Apply refund to next-year estimated tax',
                value: ca540['applyToEstimated'],
                onChanged: (v) => _patch('applyToEstimated', v),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'California refund / amount owed',
          subtitle: 'Live estimate from Form 540 lines (server may recalculate).',
          child: MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryRow('Line 48 — Tax after credits', summary.taxAfterCredits),
                if (summary.behavioralHealthTax > 0)
                  _summaryRow('Line 62 — Behavioral health tax', summary.behavioralHealthTax),
                _summaryRow('Line 64 — Total tax', summary.totalTax),
                _summaryRow('Line 78 — Total payments', summary.totalPayments),
                const Divider(height: 20),
                Text(
                  summary.isRefund ? 'Line 97 — Estimated CA refund' : 'Line 100 — Estimated CA amount owed',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(summary.refundOrOwed.abs()),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: summary.isRefund ? MkgColors.green : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final earned = _n(ca540['earnedIncome']) > 0
                        ? _n(ca540['earnedIncome'])
                        : (_n(ca540['stateWages']) > 0
                            ? _n(ca540['stateWages'])
                            : (_n(ca540['federalAGI']) > 0 &&
                                    _n(ca540['federalAGI']) <= kCalEitcMaxEarnedIncome
                                ? _n(ca540['federalAGI'])
                                : 0));
                    final est = estimateCalEitc(
                      earnedIncome: earned,
                      federalAgi: _n(ca540['federalAGI']),
                      qualifyingChildren: _i(ca540['qualifyingChildren'] ?? ca540['dependentExemptions']),
                      hasYoungChild: ca540['hasYoungChild'] == true || _i(ca540['yctcChildAge']) < 6,
                      hasFosterYouth: ca540['hasFosterYouth'] == true,
                    );
                    _patchAll({
                      'caAGI': summary.caAgi,
                      'standardDeduction': summary.deduction,
                      'taxableIncome': summary.taxableIncome,
                      'caTax': summary.caTax,
                      'exemptionCredits': summary.exemptionCredits,
                      'totalTax': summary.totalTax,
                      'totalPayments': summary.totalPayments,
                      'refundOrOwed': summary.refundOrOwed,
                      'behavioralHealthTax': summary.behavioralHealthTax,
                      if (_n(ca540['calEITC']) <= 0 && est.calEitc > 0) 'calEITC': est.calEitc,
                      if (_n(ca540['youngChildTaxCredit']) <= 0 && est.youngChildTaxCredit > 0)
                        'youngChildTaxCredit': est.youngChildTaxCredit,
                      if (_n(ca540['fosterYouthTaxCredit']) <= 0 && est.fosterYouthTaxCredit > 0)
                        'fosterYouthTaxCredit': est.fosterYouthTaxCredit,
                    });
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Write estimate totals into Form 540'),
                ),
              ],
            ),
          ),
        ),
        OrganizerSection(
          title: 'Additional Form 540 fields',
          subtitle: 'Additional California Form 540 details.',
          child: NestedMapEditor(
            data: ca540,
            excludeKeys: _typedKeys,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

  int _i(dynamic v) => int.tryParse('$v') ?? 0;

  String _money(num v) => '\$${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  Widget _summaryRow(String label, num value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: MkgColors.textGrey))),
          Text(_money(value), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _intField(String label, dynamic value, ValueChanged<int> onChanged) {
    final text = value == null || value == 0 ? '' : '$value';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: text,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => onChanged(int.tryParse(v.trim()) ?? 0),
      ),
    );
  }
}
