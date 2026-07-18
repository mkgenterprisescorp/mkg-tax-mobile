import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../data/official_form_links.dart';
import 'organizer_fields.dart';

/// Federal Form 1040-X (amended return) organizer intake.
class OrganizerForm1040xStep extends StatelessWidget {
  const OrganizerForm1040xStep({
    super.key,
    required this.data,
    required this.onNested,
  });

  final Map<String, dynamic> data;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;

  Map<String, dynamic> get _form => Map<String, dynamic>.from((data['form1040x'] as Map?) ?? {});

  void _patch(String key, dynamic value) {
    final next = Map<String, dynamic>.from(_form)..[key] = value;
    onNested('form1040x', next);
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    final isAmended = form['isAmended'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        const Text('Form 1040-X', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Amended U.S. Individual Income Tax Return. Use when correcting a previously filed Form 1040.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 12),
        OfficialFormLinksCard(
          title: 'Official IRS Form 1040-X',
          subtitle: 'Open the IRS instructions and blank form.',
          links: const [
            ('About Form 1040-X (IRS)', OfficialFormLinks.form1040xAbout),
            ('Form 1040-X PDF', OfficialFormLinks.form1040xPdf),
          ],
        ),
        const SizedBox(height: 12),
        OrganizerSection(
          title: 'Amended federal return',
          subtitle: 'Enable only if you need to amend a prior federal filing.',
          child: Column(
            children: [
              OrganizerCheckbox(
                label: 'I am filing Form 1040-X (amended federal return)',
                value: isAmended,
                onChanged: (v) => _patch('isAmended', v),
              ),
              if (isAmended) ...[
                OrganizerTextField(
                  label: 'Tax year being amended',
                  value: '${form['taxYearAmended'] ?? data['filingYear'] ?? ''}',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _patch('taxYearAmended', v),
                ),
                OrganizerDropdown<String>(
                  label: 'Primary reason',
                  value: const {'income', 'credits', 'filing_status', 'dependents', 'other'}
                          .contains('${form['amendedReason'] ?? ''}')
                      ? '${form['amendedReason']}'
                      : 'other',
                  items: const [
                    ('income', 'Income change'),
                    ('credits', 'Credits / deductions'),
                    ('filing_status', 'Filing status'),
                    ('dependents', 'Dependents'),
                    ('other', 'Other'),
                  ],
                  onChanged: (v) => _patch('amendedReason', v ?? 'other'),
                ),
                OrganizerTextField(
                  label: 'Explanation of changes',
                  value: '${form['explanation'] ?? ''}',
                  maxLines: 4,
                  onChanged: (v) => _patch('explanation', v),
                ),
                OrganizerMoneyField(
                  label: 'Original tax as filed',
                  value: form['originalTax'],
                  onChanged: (v) => _patch('originalTax', v),
                ),
                OrganizerMoneyField(
                  label: 'Corrected tax',
                  value: form['correctedTax'],
                  onChanged: (v) => _patch('correctedTax', v),
                ),
                OrganizerMoneyField(
                  label: 'Original refund (if any)',
                  value: form['originalRefund'],
                  onChanged: (v) => _patch('originalRefund', v),
                ),
                OrganizerMoneyField(
                  label: 'Corrected refund / (amount owed)',
                  value: form['correctedRefund'],
                  onChanged: (v) => _patch('correctedRefund', v),
                ),
                OrganizerMoneyField(
                  label: 'Net change (refund increase or balance due)',
                  value: form['netChange'],
                  onChanged: (v) => _patch('netChange', v),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
