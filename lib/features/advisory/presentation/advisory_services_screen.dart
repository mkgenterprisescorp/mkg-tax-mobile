import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Finance Advisors / Financial Planning hub.
class AdvisoryServicesScreen extends StatelessWidget {
  const AdvisoryServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const Text('Finance Advisors', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Financial planning and advisory services from MKG Tax Consultants.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 16),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_outlined, color: MkgColors.accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Advisory Services', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Wealth planning, lending guidance, and cash-flow tools live here — alongside your tax workspace.',
                style: TextStyle(color: MkgColors.textGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Icon walkthrough for advisory / advance sections
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final item in const [
              (Icons.payments_outlined, 'Refund Advance', 'Loan Estimate · TILA', '/refund-advance'),
              (Icons.request_quote_outlined, 'Loan Estimate', '0% & 36% APR tiers', '/refund-advance/loan-estimate'),
              (Icons.gavel_outlined, 'TILA', 'Truth in Lending', '/refund-advance/tila'),
              (Icons.forum_outlined, 'Advisor Chat', 'Talk to Finance Advisors', '/chat'),
            ])
              Material(
                color: MkgColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go(item.$4),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$1, color: MkgColors.primary),
                        const Spacer(),
                        Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(item.$3, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in const [
          _AdvLink('Financials & loans', 'Advances, lending calculators, applications', Icons.payments_outlined, '/refund-advance'),
          _AdvLink('Mortgage lending', 'Home financing guidance', Icons.home_work_outlined, '/refund-advance'),
          _AdvLink('Bookkeeping', 'Business books and health checks', Icons.menu_book_outlined, '/bookkeeping'),
          _AdvLink('Billing & payments', 'Invoices and payment plans', Icons.receipt_long_outlined, '/billing'),
          _AdvLink('Talk to an advisor', 'Schedule or message your Finance Advisor', Icons.forum_outlined, '/chat'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: MkgColors.primary.withValues(alpha: 0.1),
              child: Icon(item.icon, color: MkgColors.primary),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(item.path),
          ),
      ],
    );
  }
}

class _AdvLink {
  const _AdvLink(this.title, this.subtitle, this.icon, this.path);
  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
}
