import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ca540_estimate_math.dart';
import '../data/ca540_repository.dart';
import '../data/computed_field_policy.dart';
import '../data/laravel_organizer_repository.dart';
import '../data/official_form_links.dart';
import '../data/organizer_defaults.dart';
import 'organizer_computed_money_field.dart';
import 'organizer_fields.dart';

/// Complete California Form 540 tax & refund calculator (estimate-only).
/// Uses FTB Form 540 line structure via Laravel Ca540Calculator.
class Ca540CalculatorScreen extends ConsumerStatefulWidget {
  const Ca540CalculatorScreen({super.key});

  @override
  ConsumerState<Ca540CalculatorScreen> createState() => _Ca540CalculatorScreenState();
}

class _Ca540CalculatorScreenState extends ConsumerState<Ca540CalculatorScreen> {
  final _federalAgi = TextEditingController();
  final _subtractions = TextEditingController(text: '0');
  final _additions = TextEditingController(text: '0');
  final _itemized = TextEditingController(text: '0');
  final _withholding = TextEditingController(text: '0');
  final _estimated = TextEditingController(text: '0');
  final _calEitc = TextEditingController(text: '0');
  final _yctc = TextEditingController(text: '0');
  final _fytc = TextEditingController(text: '0');
  final _useTax = TextEditingController(text: '0');
  final _careCredit = TextEditingController(text: '0');

  String _filingStatus = 'single';
  String _deductionType = 'standard';
  int _personalExemptions = 1;
  int _dependentExemptions = 0;
  bool _claimRenters = true;
  bool _autoCalEitc = true;
  bool _hasYoungChild = false;
  bool _agiOverridden = false;
  bool _whOverridden = false;
  num _computedAgi = 0;
  num _computedWithholding = 0;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromOrganizer());
  }

  @override
  void dispose() {
    _federalAgi.dispose();
    _subtractions.dispose();
    _additions.dispose();
    _itemized.dispose();
    _withholding.dispose();
    _estimated.dispose();
    _calEitc.dispose();
    _yctc.dispose();
    _fytc.dispose();
    _useTax.dispose();
    _careCredit.dispose();
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  Future<void> _prefillFromOrganizer() async {
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) return;
      final preview = await ref.read(ca540RepositoryProvider).fromOrganizer(workspaceId);
      if (preview == null || !mounted) return;
      final ca = preview['ca540'] as Map? ?? preview['prefill_inputs']?['ca540'] as Map?;
      final status = '${preview['filing_status'] ?? preview['prefill_inputs']?['filingStatus'] ?? 'single'}';
      setState(() {
        _filingStatus = filingStatusOptions.any((e) => e.$1 == status) ? status : 'single';
        if (ca != null) {
          final agi = num.tryParse('${ca['federalAGI'] ?? 0}') ?? 0;
          final wh = num.tryParse('${ca['caWithholding'] ?? 0}') ?? 0;
          _computedAgi = agi;
          _computedWithholding = wh;
          _agiOverridden = ComputedFieldPolicy.isOverridden(Map<String, dynamic>.from(ca), 'federalAGI');
          _whOverridden = ComputedFieldPolicy.isOverridden(Map<String, dynamic>.from(ca), 'caWithholding');
          _federalAgi.text = '$agi';
          _subtractions.text = '${ca['caSubtractions'] ?? 0}';
          _additions.text = '${ca['caAdditions'] ?? 0}';
          _itemized.text = '${ca['itemizedDeduction'] ?? 0}';
          _withholding.text = '$wh';
          _estimated.text = '${ca['estimatedPayments'] ?? 0}';
          _calEitc.text = '${ca['calEITC'] ?? 0}';
          _yctc.text = '${ca['youngChildTaxCredit'] ?? 0}';
          _fytc.text = '${ca['fosterYouthTaxCredit'] ?? 0}';
          _useTax.text = '${ca['useTax'] ?? 0}';
          _careCredit.text = '${ca['childDependentCareCredit'] ?? 0}';
          _deductionType = '${ca['deductionType'] ?? 'standard'}';
          _personalExemptions = int.tryParse('${ca['personalExemptions'] ?? 1}') ?? 1;
          _dependentExemptions = int.tryParse('${ca['dependentExemptions'] ?? 0}') ?? 0;
          _claimRenters = (num.tryParse('${ca['rentersCredit'] ?? 0}') ?? 0) > 0 || ca['claimRentersCredit'] == true;
        }
        final ftb = preview['ftb3514'] as Map? ?? preview['prefill_inputs']?['ftb3514'] as Map?;
        if (ftb != null) {
          _hasYoungChild = ftb['hasYCTC'] == true || (num.tryParse('${ftb['yctcChildAge'] ?? 99}') ?? 99) < 6;
          if ((num.tryParse('${ftb['calEITCAmount'] ?? 0}') ?? 0) > 0 && _n(_calEitc) <= 0) {
            _calEitc.text = '${ftb['calEITCAmount']}';
          }
        }
        _hasYoungChild = _hasYoungChild ||
            preview['hasYoungChild'] == true ||
            preview['prefill_inputs']?['hasYoungChild'] == true;
        _result = preview;
        if (_autoCalEitc) _applyLocalCalEitcEstimate();
      });
    } catch (_) {}
  }

  void _applyLocalCalEitcEstimate() {
    final agi = _n(_federalAgi);
    final earned = agi > 0 && agi <= kCalEitcMaxEarnedIncome ? agi : 0;
    final est = estimateCalEitc(
      earnedIncome: earned,
      federalAgi: agi,
      qualifyingChildren: _dependentExemptions,
      hasYoungChild: _hasYoungChild,
    );
    if (_n(_calEitc) <= 0) _calEitc.text = '${est.calEitc}';
    if (_n(_yctc) <= 0) _yctc.text = '${est.youngChildTaxCredit}';
    if (_n(_fytc) <= 0) _fytc.text = '${est.fosterYouthTaxCredit}';
  }

  Map<String, dynamic> _payload() {
    if (_autoCalEitc) _applyLocalCalEitcEstimate();
    return {
      'filingStatus': _filingStatus,
      'tax_year': 2025,
      'earnedIncome': _n(_federalAgi) > 0 && _n(_federalAgi) <= kCalEitcMaxEarnedIncome
          ? _n(_federalAgi)
          : 0,
      'qualifyingChildren': _dependentExemptions,
      'hasYoungChild': _hasYoungChild,
      'ca540': {
        'federalAGI': _n(_federalAgi),
        'caSubtractions': _n(_subtractions),
        'caAdditions': _n(_additions),
        'deductionType': _deductionType,
        'itemizedDeduction': _n(_itemized),
        'personalExemptions': _personalExemptions,
        'dependentExemptions': _dependentExemptions,
        'claimRentersCredit': _claimRenters,
        'childDependentCareCredit': _n(_careCredit),
        'caWithholding': _n(_withholding),
        'estimatedPayments': _n(_estimated),
        // Send 0 when auto so server can compute; keep manual overrides.
        'calEITC': _autoCalEitc ? 0 : _n(_calEitc),
        'youngChildTaxCredit': _autoCalEitc ? 0 : _n(_yctc),
        'fosterYouthTaxCredit': _autoCalEitc ? 0 : _n(_fytc),
        'useTax': _n(_useTax),
      },
    };
  }

  Map<String, dynamic> _localCalculate() {
    final payload = _payload();
    final ca = Map<String, dynamic>.from(payload['ca540'] as Map);
    if (_autoCalEitc) {
      final est = estimateCalEitc(
        earnedIncome: payload['earnedIncome'] as num? ?? 0,
        federalAgi: _n(_federalAgi),
        qualifyingChildren: _dependentExemptions,
        hasYoungChild: _hasYoungChild,
      );
      ca['calEITC'] = est.calEitc;
      ca['youngChildTaxCredit'] = est.youngChildTaxCredit;
      ca['fosterYouthTaxCredit'] = est.fosterYouthTaxCredit;
      ca['earnedIncome'] = est.earnedIncome;
      ca['qualifyingChildren'] = est.qualifyingChildren;
      ca['hasYoungChild'] = _hasYoungChild;
    }
    final summary = summarizeCa540(ca540: ca, filingStatus: _filingStatus);
    final refund = summary.refundOrOwed >= 0 ? summary.refundOrOwed : 0;
    final owing = summary.refundOrOwed < 0 ? -summary.refundOrOwed : 0;
    final cal = _nFrom(ca['calEITC']);
    return {
      'estimate_only': true,
      'submission_engine': 'ca540_local',
      'form': '540',
      'filing_status': _filingStatus,
      'ca540': {
        ...ca,
        'caTax': summary.caTax,
        'caAGI': summary.caAgi,
        'taxableIncome': summary.taxableIncome,
        'totalTax': summary.totalTax,
        'totalPayments': summary.totalPayments,
        'refundOrOwed': summary.refundOrOwed,
      },
      'lines': {
        'line_13_federal_agi': _n(_federalAgi),
        'line_17_ca_agi': summary.caAgi,
        'line_18_deduction': summary.deduction,
        'line_19_taxable_income': summary.taxableIncome,
        'line_31_ca_tax': summary.caTax,
        'line_32_exemption_credits': summary.exemptionCredits,
        'line_35_subtotal': summary.taxAfterCredits,
        'line_40_48_nonrefundable_credits': 0,
        'total_tax': summary.totalTax,
        'total_payments': summary.totalPayments,
        'refund_or_owed': summary.refundOrOwed,
      },
      'refund': refund,
      'owing': owing,
      'ftb3514': {
        'cal_eitc': ca['calEITC'],
        'young_child_tax_credit': ca['youngChildTaxCredit'],
        'foster_youth_tax_credit': ca['fosterYouthTaxCredit'],
        'eligible': cal > 0,
      },
      'advice': summary.isRefund
          ? 'Estimated California refund (local Form 540 + CalEITC). Confirm with FTB 3514 tables before filing.'
          : 'Estimated California balance due (local Form 540 + CalEITC). Confirm withholdings and credits with your preparer.',
    };
  }

  num _nFrom(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

  void _syncCreditFieldsFromResult(Map<String, dynamic> result) {
    final ca = result['ca540'];
    if (ca is! Map) return;
    _calEitc.text = '${ca['calEITC'] ?? _calEitc.text}';
    _yctc.text = '${ca['youngChildTaxCredit'] ?? _yctc.text}';
    _fytc.text = '${ca['fosterYouthTaxCredit'] ?? _fytc.text}';
  }

  Future<void> _calculate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(ca540RepositoryProvider).calculate(_payload());
      if (!mounted) return;
      _syncCreditFieldsFromResult(result);
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      // Workflow continues offline with client-side Form 540 + CalEITC estimate.
      final local = _localCalculate();
      if (!mounted) return;
      _syncCreditFieldsFromResult(local);
      setState(() {
        _result = local;
        _error = '${ApiErrorMapper.map(e)} Showing local Form 540 + CalEITC estimate.';
        _busy = false;
      });
    }
  }

  Future<void> _saveToOrganizer() async {
    final ca = _result?['ca540'];
    if (ca is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculate Form 540 first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) throw StateError('Select a tax year workspace first');
      await ref.read(laravelOrganizerRepositoryProvider).updateSection(
            workspaceId: workspaceId,
            sectionKey: 'state_ca_540',
            answers: {
              'ca540': Map<String, dynamic>.from(ca),
            },
            sectionComplete: true,
            prepType: 'personal',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form 540 totals saved to Tax Organizer')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _money(dynamic v) {
    final n = num.tryParse('$v') ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final lines = _result?['lines'] as Map?;
    final ca = _result?['ca540'] as Map?;
    final forms = _result?['official_forms'] as Map?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/organizer'),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Tax Organizer',
            ),
            const Expanded(
              child: Text('CA Form 540', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'California Resident Income Tax Return — tax & refund estimate. '
          'Line math follows FTB Form 540 (estimate only, not a filed return).',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/refund-advance/estimate'),
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Open federal refund estimator'),
        ),
        const SizedBox(height: 12),
        OfficialFormLinksCard(
          title: 'Official FTB Form 540 (TY 2025)',
          subtitle: 'Use these while completing your California return.',
          links: [
            ('2025 Form 540 booklet', '${forms?['booklet'] ?? OfficialFormLinks.ca540Booklet}'),
            ('2025 Form 540 instructions', '${forms?['instructions'] ?? OfficialFormLinks.ca540Instructions}'),
            ('2025 Form 540 PDF', '${forms?['form_pdf'] ?? OfficialFormLinks.ca540Pdf}'),
            ('2025 Form 540-X PDF', '${forms?['form_540x_pdf'] ?? OfficialFormLinks.ca540xPdf}'),
          ],
        ),
        const SizedBox(height: 16),
        const SectionHeader('Taxpayer inputs'),
        OrganizerDropdown<String>(
          label: 'Filing status',
          value: _filingStatus,
          items: filingStatusOptions,
          onChanged: (v) => setState(() => _filingStatus = v ?? 'single'),
        ),
        OrganizerComputedMoneyField(
          policy: ComputedFieldPolicy.federalAgi,
          computedValue: _computedAgi,
          storedValue: _n(_federalAgi),
          isOverridden: _agiOverridden,
          isProfessional: capabilitiesFor(ref.watch(authProvider).user?.role).isProfessional,
          onApplyComputed: () => setState(() {
            _agiOverridden = false;
            _federalAgi.text = '$_computedAgi';
          }),
          onManualValue: (v) => setState(() {
            _agiOverridden = true;
            _federalAgi.text = '$v';
          }),
          onMarkOverridden: () => setState(() => _agiOverridden = true),
          onClearOverride: () => setState(() {
            _agiOverridden = false;
            _federalAgi.text = '$_computedAgi';
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _subtractions,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CA subtractions (Schedule CA)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _additions,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CA additions (Schedule CA)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        OrganizerDropdown<String>(
          label: 'Deduction type',
          value: _deductionType,
          items: const [('standard', 'Standard deduction'), ('itemized', 'Itemized deduction')],
          onChanged: (v) => setState(() => _deductionType = v ?? 'standard'),
        ),
        if (_deductionType == 'itemized')
          TextField(
            controller: _itemized,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Itemized deduction amount', prefixText: '\$ '),
          ),
        const SizedBox(height: 8),
        _stepper('Personal exemptions', _personalExemptions, (v) => setState(() => _personalExemptions = v)),
        _stepper('Dependent exemptions', _dependentExemptions, (v) => setState(() => _dependentExemptions = v)),
        OrganizerCheckbox(
          label: "Claim nonrefundable renter's credit (\$60 / \$120 if AGI qualifies)",
          value: _claimRenters,
          onChanged: (v) => setState(() => _claimRenters = v),
        ),
        TextField(
          controller: _careCredit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Child & dependent care credit (FTB 3506)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        OrganizerComputedMoneyField(
          policy: ComputedFieldPolicy.caWithholding,
          computedValue: _computedWithholding,
          storedValue: _n(_withholding),
          isOverridden: _whOverridden,
          isProfessional: capabilitiesFor(ref.watch(authProvider).user?.role).isProfessional,
          onApplyComputed: () => setState(() {
            _whOverridden = false;
            _withholding.text = '$_computedWithholding';
          }),
          onManualValue: (v) => setState(() {
            _whOverridden = true;
            _withholding.text = '$v';
          }),
          onMarkOverridden: () => setState(() => _whOverridden = true),
          onClearOverride: () => setState(() {
            _whOverridden = false;
            _withholding.text = '$_computedWithholding';
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _estimated,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CA estimated tax payments', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        OrganizerCheckbox(
          label: 'Auto-calculate CalEITC / YCTC (FTB 3514 TY2025 estimate)',
          value: _autoCalEitc,
          onChanged: (v) => setState(() {
            _autoCalEitc = v;
            if (v) _applyLocalCalEitcEstimate();
          }),
        ),
        OrganizerCheckbox(
          label: 'Qualifying child under age 6 (Young Child Tax Credit)',
          value: _hasYoungChild,
          onChanged: (v) => setState(() {
            _hasYoungChild = v;
            if (_autoCalEitc) _applyLocalCalEitcEstimate();
          }),
        ),
        const Text(
          'CalEITC uses federal AGI as earned-income estimate when ≤ \$32,900 and dependent exemptions as qualifying children. Confirm with FTB 3514 before filing.',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _calEitc,
          readOnly: _autoCalEitc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _autoCalEitc ? 'CalEITC (FTB 3514) — auto' : 'CalEITC (FTB 3514)',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _yctc,
          readOnly: _autoCalEitc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _autoCalEitc ? 'Young Child Tax Credit — auto' : 'Young Child Tax Credit',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _fytc,
          readOnly: _autoCalEitc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _autoCalEitc ? 'Foster Youth Tax Credit — auto' : 'Foster Youth Tax Credit',
            prefixText: '\$ ',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _useTax,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Use tax', prefixText: '\$ '),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _calculate,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(_busy ? 'Calculating…' : 'Calculate Form 540 tax & refund'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: MkgColors.red)),
        ],
        if (lines != null) ...[
          const SizedBox(height: 18),
          const SectionHeader('Form 540 line results'),
          MkgCard(
            child: Column(
              children: [
                _row('Line 13 — Federal AGI', _money(lines['line_13_federal_agi'])),
                _row('Line 17 — CA AGI', _money(lines['line_17_ca_agi'])),
                _row('Line 18 — Deduction', _money(lines['line_18_deduction'])),
                _row('Line 19 — Taxable income', _money(lines['line_19_taxable_income'])),
                _row('Line 31 — CA tax', _money(lines['line_31_ca_tax'])),
                _row('Line 32 — Exemption credits', _money(lines['line_32_exemption_credits'])),
                _row('Line 35 — Tax subtotal', _money(lines['line_35_subtotal'])),
                _row('Nonrefundable credits', _money(lines['line_40_48_nonrefundable_credits'])),
                _row('Total tax', _money(lines['total_tax'])),
                _row('Total payments', _money(lines['total_payments'])),
                const Divider(height: 18),
                _row(
                  (_result!['refund'] as num? ?? 0) > 0 ? 'Estimated CA refund' : 'Estimated CA amount owed',
                  _money((_result!['refund'] as num? ?? 0) > 0 ? _result!['refund'] : _result!['owing']),
                  emphasize: true,
                ),
                if (ca != null) ...[
                  const SizedBox(height: 6),
                  _row("Renter's credit applied", _money(ca['rentersCredit'])),
                  _row('Suggested renter\'s credit', _money(_result!['suggested_renters_credit'])),
                ],
                const SizedBox(height: 8),
                Text(
                  '${_result!['advice'] ?? 'Estimate only.'}',
                  style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _saveToOrganizer,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save totals to Tax Organizer'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/refund-advance/estimate'),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('Federal refund calculator'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/organizer'),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open Tax Organizer (CA 540 suite)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final refund = (_result!['refund'] as num?) ?? 0;
              if (refund > 0) {
                context.go('/refund-advance/loan-estimate');
              } else {
                context.go('/refund-advance');
              }
            },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Continue to Refund Advance'),
          ),
        ],
      ],
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(onPressed: () => onChanged((value - 1).clamp(0, 20)), icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(onPressed: () => onChanged((value + 1).clamp(0, 20)), icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(k, style: TextStyle(color: MkgColors.textGrey, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500))),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: emphasize ? MkgColors.primary : MkgColors.dark, fontSize: emphasize ? 16 : 14)),
          ],
        ),
      );
}
