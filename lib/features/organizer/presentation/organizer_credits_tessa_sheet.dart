import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Education credit type options for Form 8863 (stored values match rollups).
const educationCreditTypeOptions = <(String, String)>[
  ('american_opportunity', 'American Opportunity Credit (AOTC)'),
  ('lifetime_learning', 'Lifetime Learning Credit (LLC)'),
];

String normalizeEducationCreditType(dynamic raw) {
  final v = '$raw'.trim().toLowerCase();
  if (v == 'lifetime_learning' || v == 'llc' || v.contains('lifetime')) {
    return 'lifetime_learning';
  }
  return 'american_opportunity';
}

/// Opens Tessa guidance for Credits & Deductions (eligibility, disallowance,
/// penalties, documentation guardrails) and optional acknowledgement.
Future<bool?> showCreditsTessaGuidanceSheet(
  BuildContext context, {
  required bool alreadyAcknowledged,
  required ValueChanged<bool> onAcknowledged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _CreditsTessaGuidanceSheet(
      alreadyAcknowledged: alreadyAcknowledged,
      onAcknowledged: onAcknowledged,
    ),
  );
}

class _CreditsTessaGuidanceSheet extends StatefulWidget {
  const _CreditsTessaGuidanceSheet({
    required this.alreadyAcknowledged,
    required this.onAcknowledged,
  });

  final bool alreadyAcknowledged;
  final ValueChanged<bool> onAcknowledged;

  @override
  State<_CreditsTessaGuidanceSheet> createState() => _CreditsTessaGuidanceSheetState();
}

class _CreditsTessaGuidanceSheetState extends State<_CreditsTessaGuidanceSheet> {
  late bool _ack = widget.alreadyAcknowledged;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SizedBox(
      height: maxH,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: MkgColors.lightPrimary,
                  child: Icon(Icons.smart_toy_outlined, color: MkgColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tessa · Credits & deductions',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Educational guidance only — not legal advice or an IRS determination.',
                        style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _GuardrailBanner(
                  icon: Icons.folder_special_outlined,
                  title: 'Supporting documentation may be required',
                  body:
                      'Your MKG tax preparer may require Forms 1098-T, receipts, dependent care provider TINs, '
                      'energy invoices, adoption records, HSA statements, or other proof before claiming any credit '
                      'or deduction. Incomplete or missing documents can delay filing or mean the credit is not claimed.',
                ),
                const SizedBox(height: 14),
                const _SectionTitle('How common credits & deductions apply'),
                const _GuideTile(
                  title: 'American Opportunity Credit (AOTC) — Form 8863',
                  body:
                      'For eligible students in the first four years of postsecondary education, enrolled at least '
                      'half-time in a program leading to a degree/credential. Up to \$2,500 per student; up to 40% '
                      '(max \$1,000) may be refundable (Form 1040 Line 29). You generally cannot claim AOTC and LLC '
                      'for the same student in the same year.',
                ),
                const _GuideTile(
                  title: 'Lifetime Learning Credit (LLC) — Form 8863',
                  body:
                      'Broader than AOTC: undergraduate, graduate, or courses to acquire/improve job skills. '
                      '20% of qualified expenses up to \$10,000 (max \$2,000 per return). Nonrefundable only '
                      '(flows through Schedule 3 → Form 1040 Line 20).',
                ),
                const _GuideTile(
                  title: 'Child tax credit / ACTC — Schedule 8812',
                  body:
                      'CTC/ODC for qualifying children/dependents with valid TINs; ACTC is the refundable portion '
                      'when CTC is limited by tax. Age, relationship, residency, and support tests apply.',
                ),
                const _GuideTile(
                  title: 'Earned Income Credit (EIC) — Form 1040 Line 27a',
                  body:
                      'Refundable credit for workers with earned income under IRS limits. Qualifying-child rules, '
                      'filing status, investment-income caps, and SSN requirements apply. Wrong claims are a top IRS audit focus.',
                ),
                const _GuideTile(
                  title: 'Child & dependent care — Form 2441',
                  body:
                      'Credit for work-related care of a qualifying person. Provider name and TIN are usually required. '
                      'Expenses must enable you (and spouse if MFJ) to work or look for work.',
                ),
                const _GuideTile(
                  title: 'HSA (Form 8889) & Schedule 1 adjustments',
                  body:
                      'HSA deduction requires HDHP coverage and eligible contributions. Other above-the-line items '
                      '(educator expenses, student loan interest, IRA, ½ SE tax, etc.) each have their own IRS limits.',
                ),
                const _GuideTile(
                  title: 'Schedule A itemized deductions',
                  body:
                      'Only claim if total itemized deductions exceed your standard deduction. SALT is capped; '
                      'charitable and medical rules are strict. Keep contemporaneous records.',
                ),
                const _GuideTile(
                  title: 'Energy, adoption, PTC, and other credits',
                  body:
                      'Residential energy (5695), adoption (8839), Premium Tax Credit (8962), Saver’s credit, and '
                      'foreign tax credit each have separate eligibility, phaseouts, and forms. Enter only amounts '
                      'you can substantiate.',
                ),
                const SizedBox(height: 8),
                const _SectionTitle('When a credit is disallowed (not eligible)'),
                const _GuideTile(
                  title: 'Common disallowance reasons',
                  body:
                      '• Student/dependent does not meet age, enrollment, or TIN rules\n'
                      '• Expenses are not qualified (room/board, insurance, sports fees often do not qualify)\n'
                      '• Income above phaseout / filing status not allowed\n'
                      '• Same expense already used for another credit or tax-free scholarship\n'
                      '• Prior IRS ban on claiming the credit still in effect\n'
                      '• Missing Form 1098-T or provider TIN when required\n\n'
                      'If you are not eligible, do not enter amounts that claim the credit. Ask your preparer or Tessa chat before guessing.',
                ),
                const SizedBox(height: 8),
                const _SectionTitle('Fines & penalties for falsely claiming credits'),
                const _GuideTile(
                  title: 'Civil and criminal exposure (summary)',
                  body:
                      'Falsely claiming credits can lead to:\n'
                      '• Accuracy-related penalty — generally 20% of the underpayment (IRC §6662)\n'
                      '• Civil fraud penalty — up to 75% of the underpayment (IRC §6663)\n'
                      '• Multi-year ban on claiming certain refundable credits (e.g. EITC, CTC/ACTC, AOTC) for '
                      'reckless or intentional disregard (often 2 years) or fraud (often 10 years), plus Form 8862 '
                      'to reclaim later\n'
                      '• Interest on any tax due; in serious cases, criminal tax fraud charges\n\n'
                      'MKG and the IRS treat false claims seriously. Enter only truthful, documentable information.',
                ),
                const SizedBox(height: 12),
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acknowledgement',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'I understand these credits and deductions are eligibility-based, that Tessa’s guidance '
                        'is educational only, that falsely claiming credits can result in disallowance, fines, '
                        'penalties, and credit bans, and that my tax preparer may require supporting documentation '
                        'before any credit or deduction is claimed on my return.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: MkgColors.dark),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _ack,
                        activeColor: MkgColors.primary,
                        title: const Text(
                          'I acknowledge and will only claim credits I am eligible for',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onChanged: (v) => setState(() => _ack = v == true),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: !_ack
                                  ? null
                                  : () {
                                      widget.onAcknowledged(true);
                                      Navigator.pop(context, true);
                                    },
                              child: const Text('Save acknowledgement'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardrailBanner extends StatelessWidget {
  const _GuardrailBanner({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MkgColors.lightPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MkgColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MkgColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12.5, height: 1.4, color: MkgColors.dark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MkgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 12.5, height: 1.4, color: MkgColors.textGrey)),
          ],
        ),
      ),
    );
  }
}
