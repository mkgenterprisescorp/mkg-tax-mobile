import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Client-facing appointment checklist (parity with portal Things to Bring).
class ThingsToBringScreen extends StatefulWidget {
  const ThingsToBringScreen({super.key});

  @override
  State<ThingsToBringScreen> createState() => _ThingsToBringScreenState();
}

class _ThingsToBringScreenState extends State<ThingsToBringScreen> {
  static const items = <String>[
    'Social Security card(s)',
    "Driver's License(s) / State Issued ID(s)",
    "Dependents' Social Security card(s) and dates of birth*",
    "Last year's Federal and State tax return",
    'W-2s',
    'Self-employment business income and expenses / 1099-MISC* / 1099-K',
    'Commissions received/paid*',
    'Pension, retirement income / 1099-R*',
    'IRA contributions*',
    'Unemployment income / 1099-G*',
    'Interest and dividend income / 1099-INT / 1099-DIV*',
    'Social Security income / SSA-1099*',
    'Statements on the sales of stocks or bonds / 1099-B*',
    'State refund amount / 1099-G*',
    'Income and expenses from rentals*',
    'Canceled Debt Amount / 1099-C*',
    'Lottery or gambling winnings/losses*',
    'Alimony paid or received*',
    'Record of purchase or sale of residence*',
    'Educator expenses*',
    'Child care expenses and provider information',
    'Real estate and personal property taxes*',
    'State or local taxes paid or Sales tax paid*',
    'Medical and dental expenses*',
    'Estimated taxes or foreign taxes paid*',
    'Cash and non-cash charitable donations*',
    'Mortgage or home equity loan interest paid / 1098*',
    'Unreimbursed employment-related expenses*',
    'Job-related educational expenses*',
    'Form 1095-A (Health Insurance Marketplace Statement)**',
    'Form 1095-B/1095-C — Health Coverage Statements',
    'Casualty or theft losses*',
    'Receipt(s) for qualified energy efficient home improvements*',
    'Moving expenses*',
    'Tuition and Education Fees / 1098-T*',
    'Student loan interest / 1098-E*',
    'IRS tax notices received*',
    'State tax notices received*',
    'Large document packets (upload via TitanFile Secure File Submit)*',
  ];

  static const _titanFileUrl = 'https://upload-mkgtax.titanfile.com/';

  static const _shareTemplate = '''MKG Tax Consultants — Tax Appointment Checklist

Please bring (if applicable):
- Social Security cards (yours & dependents)
- Driver's License / State ID
- Last year's tax return
- W-2s & 1099s
- Self-employment income & expenses
- Mortgage interest (1098) & property taxes
- Child care expenses & provider info
- Medical/dental records
- Charitable donation receipts
- Education expenses (1098-T, 1098-E)
- Health insurance forms (1095-A/B/C)
- Investment statements (1099-B, 1099-DIV)
- Rental property income & expenses
- IRS and state tax notices
- Large files: upload securely at https://upload-mkgtax.titanfile.com/

Questions? Call (559) 412-7248
MKG Tax Consultants
4021 N Fresno St, Suite 107, Fresno, CA 93726''';

  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    final done = _checked.length;
    final pct = items.isEmpty ? 0.0 : done / items.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/tools'), icon: const Icon(Icons.arrow_back)),
            const Expanded(
              child: Text('Things to bring', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Documents for your tax appointment. Tap items as you gather them.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 14),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$done of ${items.length} gathered', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: MkgColors.surfaceGrey,
                  color: MkgColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(_checked.clear),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: _shareTemplate));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checklist copied — paste into a message')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy list'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/documents'),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Upload gathered documents'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(_titanFileUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Upload large docs / notices (TitanFile)'),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _checked.contains(i),
            activeColor: MkgColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(items[i], style: const TextStyle(fontSize: 14)),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _checked.add(i);
                } else {
                  _checked.remove(i);
                }
              });
            },
          ),
        const SizedBox(height: 8),
        const Text('* If applicable', style: TextStyle(color: MkgColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic)),
        const Text(
          '** If you purchased health insurance through the Marketplace.',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
