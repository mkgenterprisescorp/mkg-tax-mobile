import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/refund_advance_repository.dart';
import 'refund_advance_hub_screen.dart';

/// Federal refund calculator — prefilled from organizer when available.
class RefundEstimateScreen extends ConsumerStatefulWidget {
  const RefundEstimateScreen({super.key});

  @override
  ConsumerState<RefundEstimateScreen> createState() => _RefundEstimateScreenState();
}

class _RefundEstimateScreenState extends ConsumerState<RefundEstimateScreen> {
  final _wages = TextEditingController();
  final _withheld = TextEditingController();
  final _interest = TextEditingController();
  final _business = TextEditingController();
  String _filingStatus = 'single';
  int _dependents = 0;
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromOrganizer());
  }

  @override
  void dispose() {
    _wages.dispose();
    _withheld.dispose();
    _interest.dispose();
    _business.dispose();
    super.dispose();
  }

  Future<void> _prefillFromOrganizer() async {
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) return;
      final preview = await ref.read(refundAdvanceRepositoryProvider).form1040Preview(workspaceId);
      final inputs = preview?['prefill_inputs'] as Map?;
      if (inputs == null || !mounted) return;
      setState(() {
        _filingStatus = '${inputs['filingStatus'] ?? 'single'}';
        _wages.text = '${inputs['wages'] ?? ''}';
        _withheld.text = '${inputs['taxWithheld'] ?? ''}';
        _interest.text = '${inputs['interestIncome'] ?? ''}';
        _business.text = '${inputs['businessIncome'] ?? ''}';
        _dependents = int.tryParse('${inputs['numDependents'] ?? 0}') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _calculate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(refundAdvanceRepositoryProvider).estimateTax({
        'filingStatus': _filingStatus,
        'wages': num.tryParse(_wages.text) ?? 0,
        'taxWithheld': num.tryParse(_withheld.text) ?? 0,
        'interestIncome': num.tryParse(_interest.text) ?? 0,
        'businessIncome': num.tryParse(_business.text) ?? 0,
        'numDependents': _dependents,
      });
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
      final refund = (result['refund'] as num?) ?? 0;
      if (refund > 0) {
        final adv = ref.read(refundAdvanceProvider);
        // Keep prior quote tier but update expected refund context when present.
        if (adv != null) {
          ref.read(refundAdvanceProvider.notifier).setQuote(
                RefundAdvanceQuote(
                  tierLabel: adv.tierLabel,
                  amount: adv.amount,
                  apr: adv.apr,
                  expectedRefund: refund,
                  quote: adv.quote,
                ),
              );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.go('/refund-advance'),
              icon: const Icon(Icons.grid_view_rounded, color: MkgColors.primary),
            ),
            const Expanded(
              child: Text('Refund calculator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Federal estimate only. Prefills from your Tax Organizer when available.',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _filingStatus,
          decoration: const InputDecoration(labelText: 'Filing status'),
          items: const [
            DropdownMenuItem(value: 'single', child: Text('Single')),
            DropdownMenuItem(value: 'married_joint', child: Text('Married filing jointly')),
            DropdownMenuItem(value: 'married_separate', child: Text('Married filing separately')),
            DropdownMenuItem(value: 'head_household', child: Text('Head of household')),
          ],
          onChanged: (v) => setState(() => _filingStatus = v ?? 'single'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _wages, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Wages', prefixText: '\$ ')),
        const SizedBox(height: 10),
        TextField(controller: _withheld, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Federal tax withheld', prefixText: '\$ ')),
        const SizedBox(height: 10),
        TextField(controller: _interest, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interest income', prefixText: '\$ ')),
        const SizedBox(height: 10),
        TextField(controller: _business, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Business income', prefixText: '\$ ')),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Dependents'),
            const Spacer(),
            IconButton(onPressed: () => setState(() => _dependents = (_dependents - 1).clamp(0, 20)), icon: const Icon(Icons.remove_circle_outline)),
            Text('$_dependents', style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(onPressed: () => setState(() => _dependents = (_dependents + 1).clamp(0, 20)), icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _calculate,
          child: Text(_busy ? 'Calculating…' : 'Calculate refund estimate'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: MkgColors.red)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimate summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                _row('Total income', '\$${_result!['totalIncome']}'),
                _row('AGI', '\$${_result!['agi']}'),
                _row('Taxable income', '\$${_result!['taxableIncome']}'),
                _row('Total tax', '\$${_result!['totalTax']}'),
                _row('Withheld', '\$${_result!['taxWithheld']}'),
                _row('Estimated refund', '\$${_result!['refund']}', emphasize: true),
                const SizedBox(height: 8),
                Text('${_result!['advice']}', style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final refund = (_result!['refund'] as num?) ?? 0;
              if (refund > 0) {
                ref.read(refundAdvanceProvider.notifier).setQuote(
                      RefundAdvanceQuote(
                        tierLabel: '\$1000',
                        amount: 1000,
                        apr: 0,
                        expectedRefund: refund,
                        quote: null,
                      ),
                    );
              }
              context.go('/refund-advance/loan-estimate');
            },
            icon: const Icon(Icons.request_quote_outlined),
            label: const Text('Continue to Loan Estimate'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/ca-540'),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Calculate California Form 540 refund'),
          ),
        ],
      ],
    );
  }

  Widget _row(String k, String v, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: MkgColors.textGrey))),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: emphasize ? MkgColors.primary : MkgColors.dark)),
          ],
        ),
      );
}
