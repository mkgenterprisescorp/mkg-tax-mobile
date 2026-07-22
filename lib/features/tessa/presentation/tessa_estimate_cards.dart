import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Display-only cards for Laravel Tessa automation payloads.
/// Flutter never computes tax — values come from API responses.
class TessaEstimateCards {
  TessaEstimateCards._();

  static Widget forAction({
    required String type,
    required Map<String, dynamic> payload,
    required bool ok,
    required String summary,
  }) {
    if (!ok) {
      return _SummaryOnly(summary: summary, ok: false);
    }
    switch (type) {
      case 'run_federal_1040_preview':
        return _Federal1040PreviewCard(payload: payload, summary: summary);
      case 'run_federal_tax_estimate':
        return _FederalEstimateCard(payload: _estimateMap(payload), summary: summary);
      case 'run_ca540_estimate':
        return _Ca540EstimateCard(payload: payload, summary: summary);
      case 'analyze_form_completeness':
        return _FormPlanCard(payload: payload, summary: summary);
      default:
        return _SummaryOnly(summary: summary, ok: true);
    }
  }

  /// Federal estimate may be top-level or nested under refund_estimate.
  static Map<String, dynamic> _estimateMap(Map<String, dynamic> payload) {
    final nested = payload['refund_estimate'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return payload;
  }
}

class _SummaryOnly extends StatelessWidget {
  const _SummaryOnly({required this.summary, required this.ok});
  final String summary;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${ok ? '✓' : '✗'} $summary',
      style: TextStyle(color: ok ? MkgColors.dark : Colors.red.shade800),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value, {this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: emphasize ? MkgColors.primary : MkgColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(dynamic v) {
  if (v == null) return '—';
  if (v is num) {
    final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    return '\$$s';
  }
  final t = '$v'.trim();
  if (t.isEmpty) return '—';
  if (t.startsWith('\$')) return t;
  return '\$$t';
}

class _Federal1040PreviewCard extends StatelessWidget {
  const _Federal1040PreviewCard({required this.payload, required this.summary});
  final Map<String, dynamic> payload;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final form = payload['form'] is Map ? Map<String, dynamic>.from(payload['form'] as Map) : null;
    final estimate = payload['refund_estimate'] is Map
        ? Map<String, dynamic>.from(payload['refund_estimate'] as Map)
        : null;
    final taxpayer = form?['taxpayer'] is Map ? Map<String, dynamic>.from(form!['taxpayer'] as Map) : null;
    final income = form?['income'] is Map ? Map<String, dynamic>.from(form!['income'] as Map) : null;
    final credits = form?['credits'] is Map
        ? Map<String, dynamic>.from(form!['credits'] as Map)
        : (estimate?['credits'] is Map ? Map<String, dynamic>.from(estimate!['credits'] as Map) : null);
    final deductions = form?['deductions'] is Map
        ? Map<String, dynamic>.from(form!['deductions'] as Map)
        : (estimate?['deductions'] is Map
            ? Map<String, dynamic>.from(estimate!['deductions'] as Map)
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✓ $summary', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Form 1040 preview', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Laravel estimate/intake only — not a certified return.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 8),
              if (taxpayer != null)
                _Kv('Taxpayer', '${taxpayer['first_name'] ?? ''} ${taxpayer['last_name'] ?? ''}'.trim()),
              if (form != null) ...[
                _Kv('Filing status', '${form['filing_status'] ?? '—'}'),
                _Kv('Tax year', '${form['tax_year'] ?? '—'}'),
              ],
              if (income != null) ...[
                const SizedBox(height: 4),
                const Text('Income', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                _Kv('Wages (line 1)', _money(income['wages_line1'] ?? income['wages'])),
                _Kv('Interest', _money(income['interest'])),
                _Kv('Dividends', _money(income['dividends'])),
                _Kv('Business', _money(income['business'])),
                _Kv('Federal withheld', _money(income['tax_withheld'] ?? income['withholding'])),
              ],
              if (deductions != null) ...[
                const SizedBox(height: 4),
                const Text('Deductions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                _Kv('Standard / itemized', _money(deductions['standard'] ?? deductions['total'] ?? deductions['amount'])),
                if (deductions['type'] != null) _Kv('Type', '${deductions['type']}'),
              ],
              if (credits != null && credits.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Credits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ...credits.entries.take(8).map((e) => _Kv(_humanKey(e.key), _money(e.value))),
              ],
              if (estimate != null) ...[
                const SizedBox(height: 4),
                const Text('Federal estimate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                _Kv('Total income', _money(estimate['totalIncome'] ?? estimate['total_income'])),
                _Kv('AGI', _money(estimate['agi'])),
                _Kv('Deduction', _money(estimate['deduction'])),
                _Kv('Taxable income', _money(estimate['taxableIncome'] ?? estimate['taxable_income'])),
                _Kv('Total tax', _money(estimate['totalTax'] ?? estimate['total_tax'])),
                _Kv('Credits applied', _money(estimate['totalCredits'] ?? estimate['credits_total'])),
                ..._flatCreditRows(estimate),
                _Kv(
                  'Estimated refund / (owing)',
                  _money(estimate['refund'] ?? estimate['owing']),
                  emphasize: true,
                ),
                if (estimate['advice'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${estimate['advice']}',
                      style: const TextStyle(color: MkgColors.textGrey, fontSize: 11),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/organizer/form-1040'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open full Form 1040 preview'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<Widget> _flatCreditRows(Map<String, dynamic> estimate) {
  const keys = <String, String>{
    'childTaxCredit': 'Child tax credit',
    'child_tax_credit': 'Child tax credit',
    'earnedIncomeCredit': 'Earned income credit',
    'earned_income_credit': 'Earned income credit',
    'otherCredits': 'Other credits',
    'other_credits': 'Other credits',
    'educationCredit': 'Education credit',
    'education_credit': 'Education credit',
  };
  final rows = <Widget>[];
  for (final e in keys.entries) {
    if (estimate[e.key] != null) {
      rows.add(_Kv(e.value, _money(estimate[e.key])));
    }
  }
  return rows;
}

class _FederalEstimateCard extends StatelessWidget {
  const _FederalEstimateCard({required this.payload, required this.summary});
  final Map<String, dynamic> payload;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✓ $summary', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Federal tax estimate', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Estimate-only — Laravel TaxEstimateCalculator. Not a filed return.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 8),
              _Kv('Total income', _money(payload['totalIncome'] ?? payload['total_income'])),
              _Kv('AGI', _money(payload['agi'])),
              _Kv('Deduction', _money(payload['deduction'])),
              _Kv('Taxable income', _money(payload['taxableIncome'] ?? payload['taxable_income'])),
              _Kv('Total tax', _money(payload['totalTax'] ?? payload['total_tax'])),
              _Kv('Tax withheld', _money(payload['taxWithheld'] ?? payload['tax_withheld'])),
              _Kv('Credits', _money(payload['totalCredits'] ?? payload['credits_total'])),
              ..._flatCreditRows(payload),
              _Kv('Estimated refund', _money(payload['refund']), emphasize: true),
              _Kv('Amount owing', _money(payload['owing'])),
              if (payload['advice'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${payload['advice']}',
                    style: const TextStyle(color: MkgColors.textGrey, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/refund-advance/estimate'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open full refund estimate'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ca540EstimateCard extends StatelessWidget {
  const _Ca540EstimateCard({required this.payload, required this.summary});
  final Map<String, dynamic> payload;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final lines = payload['lines'] is Map
        ? Map<String, dynamic>.from(payload['lines'] as Map)
        : (payload['ca540'] is Map && (payload['ca540'] as Map)['lines'] is Map
            ? Map<String, dynamic>.from((payload['ca540'] as Map)['lines'] as Map)
            : <String, dynamic>{});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✓ $summary', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CA Form 540 estimate', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Laravel CA540 calculator — estimate only, not FTB-certified.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 8),
              if (lines.isNotEmpty) ...[
                _Kv('Federal AGI (line 13)', _money(lines['line_13_federal_agi'])),
                _Kv('CA AGI (line 17)', _money(lines['line_17_ca_agi'])),
                _Kv('Taxable income (line 19)', _money(lines['line_19_taxable_income'])),
                _Kv('CA tax (line 31)', _money(lines['line_31_ca_tax'])),
                _Kv('Total tax', _money(lines['total_tax'] ?? payload['total_tax'])),
                _Kv('Total payments', _money(lines['total_payments'] ?? payload['total_payments'])),
                _Kv(
                  'Refund / (owing)',
                  _money(lines['refund_or_owed'] ?? payload['refund'] ?? payload['owing']),
                  emphasize: true,
                ),
              ] else ...[
                _Kv('Refund', _money(payload['refund'])),
                _Kv('Owing', _money(payload['owing'])),
              ],
              if (payload['advice'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${payload['advice']}',
                    style: const TextStyle(color: MkgColors.textGrey, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/ca-540'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open full CA Form 540'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormPlanCard extends StatelessWidget {
  const _FormPlanCard({required this.payload, required this.summary});
  final Map<String, dynamic> payload;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final plan = payload['form_plan'] is Map
        ? Map<String, dynamic>.from(payload['form_plan'] as Map)
        : <String, dynamic>{};
    final forms = plan['required_forms'] is List
        ? (plan['required_forms'] as List).map((formId) => '$formId').toList()
        : const <String>[];
    final diagnostics = payload['diagnostics'] is List
        ? (payload['diagnostics'] as List).whereType<Map>().take(6).toList()
        : const <Map>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('✓ $summary', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Form completeness', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (forms.isNotEmpty) _Kv('Required forms', forms.join(', ')),
              if (plan['jurisdictions'] is List)
                _Kv('Jurisdictions', (plan['jurisdictions'] as List).join(', ')),
              if (diagnostics.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ...diagnostics.map((d) {
                  final msg = '${d['message'] ?? d['code'] ?? d}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $msg', style: const TextStyle(fontSize: 12)),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _humanKey(String key) {
  return key
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
