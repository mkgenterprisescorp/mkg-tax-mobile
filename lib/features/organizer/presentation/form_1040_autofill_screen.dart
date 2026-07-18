import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../refund_advance/data/refund_advance_repository.dart';
import '../data/official_form_links.dart';

/// Prefills a Form 1040 review from the tax organizer + refund estimate.
class Form1040AutofillScreen extends ConsumerStatefulWidget {
  const Form1040AutofillScreen({super.key});

  @override
  ConsumerState<Form1040AutofillScreen> createState() => _Form1040AutofillScreenState();
}

class _Form1040AutofillScreenState extends ConsumerState<Form1040AutofillScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) {
        throw StateError('Select a tax year workspace first.');
      }
      final preview = await ref.read(refundAdvanceRepositoryProvider).form1040Preview(workspaceId);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _preview?['form'] as Map?;
    final estimate = _preview?['refund_estimate'] as Map?;
    final taxpayer = form?['taxpayer'] as Map?;
    final address = form?['address'] as Map?;
    final income = form?['income'] as Map?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.go('/organizer'), icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Text('Autofill Form 1040', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const Text(
            'Values come from your Tax Organizer. SSN and bank numbers are never auto-filled.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else ...[
            MkgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taxpayer', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _kv('Name', '${taxpayer?['first_name'] ?? ''} ${taxpayer?['last_name'] ?? ''}'),
                  _kv('Filing status', '${form?['filing_status'] ?? '—'}'),
                  _kv('Tax year', '${form?['tax_year'] ?? '—'}'),
                  _kv(
                    'Address',
                    '${address?['street'] ?? ''}, ${address?['city'] ?? ''} ${address?['state'] ?? ''} ${address?['zip'] ?? ''}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MkgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Income lines', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _kv('Wages (line 1)', '\$${income?['wages_line1'] ?? '0'}'),
                  _kv('Federal withheld', '\$${income?['tax_withheld'] ?? '0'}'),
                  _kv('Interest', '\$${income?['interest'] ?? '0'}'),
                  _kv('Dividends', '\$${income?['dividends'] ?? '0'}'),
                  _kv('Business', '\$${income?['business'] ?? '0'}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MkgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Refund estimate (federal)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _kv('AGI', '\$${estimate?['agi'] ?? '—'}'),
                  _kv('Total tax', '\$${estimate?['totalTax'] ?? '—'}'),
                  _kv(
                    'Estimated refund / (owing)',
                    '\$${estimate?['refund'] ?? '—'}',
                    emphasize: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${estimate?['advice'] ?? 'Estimate only.'}',
                    style: const TextStyle(color: MkgColors.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OfficialFormLinksCard(
              title: 'Official federal & California forms',
              subtitle: 'Open IRS Form 1040-X and FTB Form 540 / 540-X.',
              links: const [
                ('IRS Form 1040-X', OfficialFormLinks.form1040xAbout),
                ('Form 1040-X PDF', OfficialFormLinks.form1040xPdf),
                ('CA Form 540 booklet (2025)', OfficialFormLinks.ca540Booklet),
                ('CA Form 540 instructions (2025)', OfficialFormLinks.ca540Instructions),
                ('CA Form 540-X PDF (2025)', OfficialFormLinks.ca540xPdf),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/refund-advance/loan-estimate'),
              child: const Text('Use refund in Loan Estimate'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/organizer'),
              child: const Text('Back to Tax Organizer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: MkgColors.textGrey))),
            Text(
              v,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: emphasize ? MkgColors.primary : MkgColors.dark,
              ),
            ),
          ],
        ),
      );
}
