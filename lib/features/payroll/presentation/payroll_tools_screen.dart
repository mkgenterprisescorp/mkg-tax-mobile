import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../organizer/data/us_states.dart';
import '../../organizer/presentation/organizer_fields.dart';
import '../data/payroll_repository.dart';

/// Estimate-only paycheck + W-4 tools. Server tables are authoritative.
class PayrollToolsScreen extends ConsumerStatefulWidget {
  const PayrollToolsScreen({super.key});

  @override
  ConsumerState<PayrollToolsScreen> createState() => _PayrollToolsScreenState();
}

class _PayrollToolsScreenState extends ConsumerState<PayrollToolsScreen> {
  final _gross = TextEditingController(text: '2000');
  final _preTax = TextEditingController(text: '0');
  final _wages = TextEditingController(text: '80000');
  final _otherIncome = TextEditingController(text: '0');
  final _deductions = TextEditingController(text: '0');
  final _credits = TextEditingController(text: '0');
  String _frequency = 'biweekly';
  String _stateCode = 'CA';
  String _filingStatus = 'single';
  Map<String, dynamic>? _payroll;
  Map<String, dynamic>? _w4;
  bool _busy = false;
  String? _error;

  static const _frequencies = <(String, String)>[
    ('weekly', 'Weekly'),
    ('biweekly', 'Biweekly'),
    ('semimonthly', 'Semi-monthly'),
    ('monthly', 'Monthly'),
  ];

  static const _filingStatuses = <(String, String)>[
    ('single', 'Single'),
    ('married_joint', 'Married filing jointly'),
    ('head_household', 'Head of household'),
  ];

  @override
  void dispose() {
    _gross.dispose();
    _preTax.dispose();
    _wages.dispose();
    _otherIncome.dispose();
    _deductions.dispose();
    _credits.dispose();
    super.dispose();
  }

  String _money(dynamic v) {
    final n = num.tryParse('$v') ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  Future<void> _runPayroll() async {
    final gross = num.tryParse(_gross.text.replaceAll(',', '').trim());
    if (gross == null) {
      setState(() => _error = 'Enter a valid gross pay');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final year = ref.read(taxYearProvider).selectedYear ?? DateTime.now().year;
      final result = await ref.read(payrollRepositoryProvider).calculate(
            taxYear: year,
            grossPay: gross,
            payFrequency: _frequency,
            stateCode: _stateCode,
            preTaxDeductions: num.tryParse(_preTax.text.replaceAll(',', '').trim()) ?? 0,
          );
      if (!mounted) return;
      setState(() {
        _payroll = result;
        _busy = false;
        if (result == null) _error = 'Paycheck estimate unavailable. Please sign in and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiErrorMapper.map(e);
      });
    }
  }

  Future<void> _runW4() async {
    final wages = num.tryParse(_wages.text.replaceAll(',', '').trim());
    if (wages == null) {
      setState(() => _error = 'Enter valid annual wages');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(payrollRepositoryProvider).w4Estimate(
            annualWages: wages,
            filingStatus: _filingStatus,
            otherIncome: num.tryParse(_otherIncome.text.replaceAll(',', '').trim()) ?? 0,
            deductions: num.tryParse(_deductions.text.replaceAll(',', '').trim()) ?? 0,
            credits: num.tryParse(_credits.text.replaceAll(',', '').trim()) ?? 0,
          );
      if (!mounted) return;
      setState(() {
        _w4 = result;
        _busy = false;
        if (result == null) _error = 'W-4 estimate unavailable. Please sign in and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiErrorMapper.map(e);
      });
    }
  }

  Widget _kv(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: MkgColors.textGrey, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500))),
          Text(value, style: TextStyle(fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600, fontSize: emphasize ? 16 : 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stateItems = <(String, String)>[
      for (final opt in usStateOptions) (opt.$1, '${opt.$1} — ${opt.$2}'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        const Text('Paycheck & W-4', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Estimate-only tools. Not tax advice — no payroll elections are submitted to an employer.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 16),
        const SectionHeader('Paycheck calculator'),
        TextField(
          controller: _gross,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Gross pay (per period)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _preTax,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Pre-tax deductions (period)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        OrganizerDropdown<String>(
          label: 'Pay frequency',
          value: _frequency,
          items: _frequencies,
          onChanged: (v) => setState(() => _frequency = v ?? 'biweekly'),
        ),
        OrganizerDropdown<String>(
          label: 'State withholding',
          value: stateItems.any((e) => e.$1 == _stateCode) ? _stateCode : 'CA',
          items: stateItems,
          onChanged: (v) => setState(() => _stateCode = v ?? 'CA'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _runPayroll,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(_busy ? 'Calculating…' : 'Calculate paycheck'),
        ),
        if (_payroll != null) ...[
          const SizedBox(height: 12),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paycheck estimate', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _kv('Gross', _money(_payroll!['gross_pay'])),
                _kv('Federal withholding', _money(_payroll!['federal_withholding'])),
                _kv('Social Security', _money(_payroll!['social_security'])),
                _kv('Medicare', _money(_payroll!['medicare'])),
                _kv('State withholding', _money(_payroll!['state_withholding'])),
                const Divider(height: 18),
                _kv('Net pay', _money(_payroll!['net_pay']), emphasize: true),
                const SizedBox(height: 6),
                Text(
                  '${_payroll!['disclaimer'] ?? 'Estimate only.'}',
                  style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        const SectionHeader('W-4 worksheet estimate'),
        TextField(
          controller: _wages,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Annual wages', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _otherIncome,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Other income (annual)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _deductions,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Deductions (annual)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _credits,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Credits (annual)', prefixText: '\$ '),
        ),
        const SizedBox(height: 10),
        OrganizerDropdown<String>(
          label: 'Filing status',
          value: _filingStatus,
          items: _filingStatuses,
          onChanged: (v) => setState(() => _filingStatus = v ?? 'single'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _runW4,
          icon: const Icon(Icons.description_outlined),
          label: Text(_busy ? 'Estimating…' : 'Estimate W-4 withholding'),
        ),
        if (_w4 != null) ...[
          const SizedBox(height: 12),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('W-4 estimate', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _kv(
                  'Suggested extra per paycheck',
                  _money(_w4!['suggested_extra_withholding_per_paycheck']),
                  emphasize: true,
                ),
                _kv('Filing status', '${_w4!['filing_status'] ?? _filingStatus}'),
                if (_w4!['notes'] is List) ...[
                  const SizedBox(height: 8),
                  for (final n in (_w4!['notes'] as List))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $n', style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
                    ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${_w4!['disclaimer'] ?? 'W-4 guidance estimate only.'}',
                  style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: MkgColors.orange)),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
