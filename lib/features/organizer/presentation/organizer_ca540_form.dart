import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/ca540_estimate_math.dart';
import '../data/us_states.dart';
import 'organizer_fields.dart';

/// Complete California Form 540 typed entry (web Organizer step 5 parity).
class OrganizerCa540Form extends StatelessWidget {
  const OrganizerCa540Form({
    super.key,
    required this.ca540,
    required this.filingStatus,
    required this.homeState,
    required this.onChanged,
  });

  final Map<String, dynamic> ca540;
  final String filingStatus;
  final String homeState;
  final ValueChanged<Map<String, dynamic>> onChanged;

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
  Widget build(BuildContext context) {
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
              OrganizerMoneyField(
                label: 'Line 13 — Federal AGI',
                value: ca540['federalAGI'],
                onChanged: (v) => _patch('federalAGI', v),
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
              OrganizerMoneyField(
                label: 'Line 71 — CA tax withheld',
                value: ca540['caWithholding'] ?? ca540['caTaxWithheld'],
                onChanged: (v) => _patchAll({'caWithholding': v, 'caTaxWithheld': v}),
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
              OrganizerMoneyField(
                label: 'Line 75 — CalEITC (FTB 3514)',
                value: ca540['calEITC'],
                onChanged: (v) => _patch('calEITC', v),
              ),
              OrganizerMoneyField(
                label: 'Line 76 — Young child tax credit',
                value: ca540['youngChildTaxCredit'],
                onChanged: (v) => _patch('youngChildTaxCredit', v),
              ),
              OrganizerMoneyField(
                label: 'Line 77 — Foster youth tax credit',
                value: ca540['fosterYouthTaxCredit'],
                onChanged: (v) => _patch('fosterYouthTaxCredit', v),
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
          subtitle: 'Any remaining keys from the full schema.',
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
