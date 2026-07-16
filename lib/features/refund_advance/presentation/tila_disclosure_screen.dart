import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import 'refund_advance_hub_screen.dart';

/// Truth in Lending Act disclosure for tax refund advances (max 36% APR).
class TilaDisclosureScreen extends ConsumerStatefulWidget {
  const TilaDisclosureScreen({super.key});

  @override
  ConsumerState<TilaDisclosureScreen> createState() => _TilaDisclosureScreenState();
}

class _TilaDisclosureScreenState extends ConsumerState<TilaDisclosureScreen> {
  bool _ack1 = false;
  bool _ack2 = false;
  bool _ack3 = false;
  bool _submitting = false;
  final _signature = TextEditingController();

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  bool get _canAccept =>
      _ack1 && _ack2 && _ack3 && _signature.text.trim().length >= 2 && ref.read(refundAdvanceProvider)?.quote != null;

  Future<void> _acceptAndApply() async {
    final adv = ref.read(refundAdvanceProvider);
    if (adv?.quote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete Loan Estimate first.')),
      );
      context.go('/refund-advance/loan-estimate');
      return;
    }
    setState(() => _submitting = true);
    try {
      ref.read(refundAdvanceProvider.notifier).acceptTila();
      dynamic returnId;
      try {
        final current = await ref.read(apiClientProvider).get('/api/tax-returns/current');
        if (current.statusCode == 200 && current.data is Map) {
          returnId = (current.data as Map)['id'];
        }
      } catch (_) {}
      await ref.read(portalRepositoryProvider).applyLoan({
        'amount': adv!.amount,
        'amountRequested': adv.amount,
        'taxReturnId': ?returnId,
        'apr': adv.apr,
        'tierLabel': adv.tierLabel,
        'tilaAccepted': true,
        'tilaSignedName': _signature.text.trim(),
        'tilaSignedAt': DateTime.now().toIso8601String(),
        ...?adv.quote,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TILA accepted · advance application submitted.')),
      );
      context.go('/refund-advance');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorMapper.map(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adv = ref.watch(refundAdvanceProvider);
    final q = adv?.quote;

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
              child: Text('TILA disclosure', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Truth in Lending Act · Tax Refund Advance',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Creditor', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Pathward, N.A., Member FDIC — Refund Advance product offered through MKG Tax Consultants.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (q == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Complete your Loan Estimate first so this disclosure shows your exact APR and finance charge.',
                      style: TextStyle(color: MkgColors.textGrey),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.go('/refund-advance/loan-estimate'),
                      child: const Text('Open Loan Estimate'),
                    ),
                  ],
                )
              else ...[
                _kv('Amount financed', '\$${q['principal'] ?? adv?.amount}'),
                _kv('APR', '${(q['apr'] as num?)?.toStringAsFixed(2) ?? adv?.apr}% (max 36.0%)'),
                _kv('Finance charge', '\$${q['interest'] ?? 0}'),
                _kv('Total of payments', '\$${q['totalRepayment'] ?? 0}'),
                _kv('Payment schedule', 'Single repayment from IRS tax refund within ~29 days'),
                _kv('Late payment fee', '\$${q['lateFee'] ?? 15}'),
                _kv('Selected tier', adv?.tierLabel ?? ''),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Important disclosures', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                '• This is a loan / advance, not your tax refund.\n'
                '• Larger advances use a 36.0% APR; no-cost tiers (\$250/\$500/\$1,000) are 0% APR.\n'
                '• Repayment is deducted from your IRS refund when issued.\n'
                '• You may cancel before funds are disbursed per program rules.\n'
                '• MKG Written Guarantee covers tax preparation services; it does not waive Pathward loan obligations.',
                style: TextStyle(height: 1.45, fontSize: 13, color: MkgColors.textGrey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _ack1,
          onChanged: (v) => setState(() => _ack1 = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: MkgColors.primary,
          title: const Text('I received this Loan Estimate and TILA disclosure', style: TextStyle(fontSize: 14)),
        ),
        CheckboxListTile(
          value: _ack2,
          onChanged: (v) => setState(() => _ack2 = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: MkgColors.primary,
          title: const Text('I understand the APR may be up to 36.0% for larger advances', style: TextStyle(fontSize: 14)),
        ),
        CheckboxListTile(
          value: _ack3,
          onChanged: (v) => setState(() => _ack3 = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: MkgColors.primary,
          title: const Text('I authorize repayment from my IRS refund', style: TextStyle(fontSize: 14)),
        ),
        TextField(
          controller: _signature,
          decoration: const InputDecoration(labelText: 'Type full legal name (electronic signature)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: !_canAccept || _submitting ? null : _acceptAndApply,
          child: Text(_submitting ? 'Submitting…' : 'Accept TILA & submit application'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/refund-advance/loan-estimate'),
          child: const Text('Back to Loan Estimate'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13))),
            Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
      );
}

