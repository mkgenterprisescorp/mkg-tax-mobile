import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class RefundAdvanceOverviewScreen extends StatelessWidget {
  const RefundAdvanceOverviewScreen({super.key});

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
              child: Text('Program overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Tax Refund Advances', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 8),
              Text(
                'Optional advance on your expected IRS refund, provided by Pathward, N.A., Member FDIC. '
                'It is not your actual tax refund.',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4),
              ),
              SizedBox(height: 14),
              Text('No-cost advances — 0% APR', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('\$250, \$500, or \$1,000 at 0.00% APR.', style: TextStyle(color: MkgColors.textGrey)),
              SizedBox(height: 12),
              Text('Larger advances — 36.0% APR', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                '25%, 50%, or 75% of your expected refund at 36.0% APR (maximum). '
                'Finance charge estimated over a ~29-day repayment period from your IRS refund.',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Funds typically available within 24 hours of IRS acceptance (program rules apply).',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/refund-advance/loan-estimate'),
          child: const Text('Continue to Loan Estimate'),
        ),
      ],
    );
  }
}

class WrittenGuaranteeScreen extends StatelessWidget {
  const WrittenGuaranteeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const points = [
      'Support year-round — offices open all year for tax and financial needs.',
      'Free consultation — information and consultations are always free.',
      'Satisfaction guarantee — case-by-case review of preparation fee refunds when warranted.',
      'Accuracy guarantee — penalties/interest from preparer errors reimbursed when applicable.',
      'Correspondence & audit assistance for returns prepared by MKG.',
      'Free copies of your paid return from your local office.',
      'Licensed preparers with ongoing education; annual background checks.',
    ];

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
              child: Text('Written guarantee', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Advantages Of Choosing MKG Tax Consultants',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final p in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: MkgColors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p, style: const TextStyle(height: 1.35, fontSize: 13))),
                    ],
                  ),
                ),
              const Divider(),
              const Text(
                'The Written Guarantee covers tax preparation services. It does not waive Pathward refund-advance loan obligations or IRS/FTB fees.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/refund-advance/loan-estimate'),
          child: const Text('Continue to Loan Estimate'),
        ),
      ],
    );
  }
}
