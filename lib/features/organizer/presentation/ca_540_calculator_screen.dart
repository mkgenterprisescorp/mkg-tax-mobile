import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/ca540_repository.dart';
import '../data/laravel_organizer_repository.dart';
import '../data/official_form_links.dart';
import '../data/organizer_defaults.dart';
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
          _federalAgi.text = '${ca['federalAGI'] ?? ''}';
          _subtractions.text = '${ca['caSubtractions'] ?? 0}';
          _additions.text = '${ca['caAdditions'] ?? 0}';
          _itemized.text = '${ca['itemizedDeduction'] ?? 0}';
          _withholding.text = '${ca['caWithholding'] ?? 0}';
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
        _result = preview;
      });
    } catch (_) {}
  }

  Map<String, dynamic> _payload() => {
        'filingStatus': _filingStatus,
        'tax_year': 2025,
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
          'calEITC': _n(_calEitc),
          'youngChildTaxCredit': _n(_yctc),
          'fosterYouthTaxCredit': _n(_fytc),
          'useTax': _n(_useTax),
        },
      };

  Future<void> _calculate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(ca540RepositoryProvider).calculate(_payload());
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
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
            IconButton(onPressed: () => context.go('/tools'), icon: const Icon(Icons.arrow_back)),
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
        TextField(
          controller: _federalAgi,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Line 13 — Federal AGI', prefixText: '\$ '),
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
        TextField(
          controller: _withholding,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CA income tax withheld (W-2 Box 17)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _estimated,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CA estimated tax payments', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _calEitc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'CalEITC (FTB 3514)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _yctc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Young Child Tax Credit', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _fytc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Foster Youth Tax Credit', prefixText: '\$ '),
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
