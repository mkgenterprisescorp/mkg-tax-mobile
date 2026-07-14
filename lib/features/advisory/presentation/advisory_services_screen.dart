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
        for (final item in const [
          _AdvLink('Financials & loans', 'Advances, lending calculators, applications', Icons.payments_outlined, '/financial'),
          _AdvLink('Mortgage lending', 'Home financing guidance', Icons.home_work_outlined, '/financial'),
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
