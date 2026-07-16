import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/payroll_repository.dart';

/// Estimate-only paycheck + W-4 tools (Phase 4). Server tables are authoritative.
class PayrollToolsScreen extends ConsumerStatefulWidget {
  const PayrollToolsScreen({super.key});

  @override
  ConsumerState<PayrollToolsScreen> createState() => _PayrollToolsScreenState();
}

class _PayrollToolsScreenState extends ConsumerState<PayrollToolsScreen> {
  final _gross = TextEditingController(text: '2000');
  final _wages = TextEditingController(text: '80000');
  Map<String, dynamic>? _payroll;
  Map<String, dynamic>? _w4;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _gross.dispose();
    _wages.dispose();
    super.dispose();
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
      final year = ref.read(taxYearProvider).selectedYear ?? DateTime.now().year - 1;
      final result = await ref.read(payrollRepositoryProvider).calculate(
            taxYear: year,
            grossPay: gross,
            payFrequency: 'biweekly',
            stateCode: 'CA',
          );
      if (!mounted) return;
      setState(() {
        _payroll = result;
        _busy = false;
        if (result == null) _error = 'Payroll estimate unavailable (sign in with Sanctum /api/v1).';
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
            filingStatus: 'single',
          );
      if (!mounted) return;
      setState(() {
        _w4 = result;
        _busy = false;
        if (result == null) _error = 'W-4 estimate unavailable (sign in with Sanctum /api/v1).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiErrorMapper.map(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Payroll & W-4 estimates'),
        const Card(
          child: ListTile(
            title: Text('Estimates only'),
            subtitle: Text(
              'Calculations use server tax tables. Not tax advice. No payroll elections are submitted.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gross,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Gross pay (period)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _runPayroll,
          child: const Text('Calculate paycheck estimate'),
        ),
        if (_payroll != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(_payroll!['estimate'] == true ? 'Estimate' : 'Result'),
              subtitle: Text(_payroll.toString()),
            ),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _wages,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Annual wages (W-4)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _runW4,
          child: const Text('Estimate W-4 worksheet'),
        ),
        if (_w4 != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: Text(_w4!['estimate'] == true ? 'W-4 estimate' : 'Result'),
              subtitle: Text(_w4.toString()),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: MkgColors.orange)),
        ],
        if (_busy) const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}
