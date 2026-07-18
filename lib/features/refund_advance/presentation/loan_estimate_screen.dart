import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/refund_advance_repository.dart';
import 'refund_advance_hub_screen.dart';

sealed class _AdvanceOption {
  const _AdvanceOption();
  String get label;
  double get apr;
  num amountFor(num expectedRefund);
}

class _FixedAdvance extends _AdvanceOption {
  const _FixedAdvance(this.amount);
  final num amount;
  @override
  String get label => '\$$amount';
  @override
  double get apr => 0;
  @override
  num amountFor(num expectedRefund) => amount;
}

class _PercentAdvance extends _AdvanceOption {
  const _PercentAdvance(this.percent);
  final int percent;
  @override
  String get label => '$percent%';
  @override
  double get apr => 36;
  @override
  num amountFor(num expectedRefund) => (expectedRefund * percent / 100).round();
}

/// Loan Estimate — web parity with mkgtaxconsultants.com Financials (0% + 36% APR).
class LoanEstimateScreen extends ConsumerStatefulWidget {
  const LoanEstimateScreen({super.key});

  @override
  ConsumerState<LoanEstimateScreen> createState() => _LoanEstimateScreenState();
}

class _LoanEstimateScreenState extends ConsumerState<LoanEstimateScreen> {
  static const _fixed = [_FixedAdvance(250), _FixedAdvance(500), _FixedAdvance(1000)];
  static const _pct = [_PercentAdvance(25), _PercentAdvance(50), _PercentAdvance(75)];

  _AdvanceOption _selected = const _FixedAdvance(1000);
  final _refundCtrl = TextEditingController(text: '7500');
  Map<String, dynamic>? _quote;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _refundCtrl.dispose();
    super.dispose();
  }

  num get _expectedRefund => num.tryParse(_refundCtrl.text.replaceAll(',', '')) ?? 0;

  Future<void> _calculate() async {
    final amount = _selected.amountFor(_expectedRefund);
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid expected refund / advance amount');
      return;
    }
    if (_selected is _PercentAdvance && _expectedRefund <= 0) {
      setState(() => _error = 'Enter your expected refund amount to calculate a percent advance');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _quote = null;
    });
    try {
      final quote = await ref.read(refundAdvanceRepositoryProvider).calculateLoan(amount);
      if (!mounted) return;
      if (quote.isEmpty || quote['principal'] == null) {
        setState(() {
          _error = 'Could not calculate this loan estimate. Please try again.';
          _busy = false;
        });
        return;
      }
      final apr = (quote['apr'] as num?)?.toDouble() ?? _selected.apr;
      setState(() {
        _quote = quote;
        _busy = false;
        _error = null;
      });
      ref.read(refundAdvanceProvider.notifier).setQuote(
            RefundAdvanceQuote(
              tierLabel: _selected.label,
              amount: amount,
              apr: apr,
              expectedRefund: _expectedRefund,
              quote: quote,
            ),
          );
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
    final advancePreview = _selected.amountFor(_expectedRefund);
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
              child: Text('Loan Estimate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Tax refund advance · Pathward, N.A. · 29-day repayment from IRS refund',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text('No-cost advances — 0% APR', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final t in _fixed) ...[
              Expanded(child: _tierChip(t)),
              if (t != _fixed.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Text('Larger advances — 36.0% APR', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final t in _pct) ...[
              Expanded(child: _tierChip(t)),
              if (t != _pct.last) const SizedBox(width: 8),
            ],
          ],
        ),
        if (_selected is _PercentAdvance) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _refundCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Expected refund amount',
              prefixText: '\$ ',
            ),
            onChanged: (_) {
              setState(() => _quote = null);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Advance amount: \$${advancePreview.toStringAsFixed(0)} '
            '(${(_selected as _PercentAdvance).percent}% of \$${_expectedRefund.toStringAsFixed(0)})',
            style: const TextStyle(color: MkgColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _calculate,
          child: Text(_busy ? 'Calculating…' : 'Calculate Loan Estimate'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: MkgColors.red)),
        ],
        if (_quote != null) ...[
          const SizedBox(height: 16),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loan Estimate summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                _row('Amount financed', '\$${(_quote!['principal'] ?? advancePreview)}'),
                _row(
                  'Annual Percentage Rate',
                  '${((_quote!['apr'] as num?) ?? _selected.apr).toStringAsFixed(2)}% APR',
                  emphasize: true,
                  warn: ((_quote!['apr'] as num?) ?? _selected.apr) > 0,
                ),
                _row('Finance charge (est.)', '\$${(_quote!['interest'] ?? 0)}'),
                _row('Total of payments', '\$${(_quote!['totalRepayment'] ?? 0)}'),
                _row('Late fee', '\$${(_quote!['lateFee'] ?? 15)}'),
                _row('Repayment term', '29 days (from IRS refund)'),
                const SizedBox(height: 8),
                const Text(
                  'This is an estimate. Final terms appear on your TILA disclosure before you apply.',
                  style: TextStyle(fontSize: 11, color: MkgColors.textGrey, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/refund-advance/tila'),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Continue to TILA disclosure'),
          ),
        ],
      ],
    );
  }

  Widget _tierChip(_AdvanceOption opt) {
    final selected = identical(_selected, opt) ||
        (_selected is _FixedAdvance &&
            opt is _FixedAdvance &&
            (_selected as _FixedAdvance).amount == opt.amount) ||
        (_selected is _PercentAdvance &&
            opt is _PercentAdvance &&
            (_selected as _PercentAdvance).percent == opt.percent);
    return Material(
      color: selected ? MkgColors.primary : MkgColors.surfaceGrey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selected = opt;
          _quote = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                opt.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: selected ? Colors.white : MkgColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${opt.apr.toStringAsFixed(0)}% APR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white70 : MkgColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false, bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: MkgColors.textGrey))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: warn ? const Color(0xFFC2410C) : (emphasize ? MkgColors.primary : MkgColors.dark),
            ),
          ),
        ],
      ),
    );
  }
}
