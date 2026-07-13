import 'package:flutter/material.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class FinancialScreen extends StatelessWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = const [
      ('Mortgage', Icons.home_work_outlined),
      ('Auto', Icons.directions_car_outlined),
      ('IRA / 401k', Icons.savings_outlined),
      ('Small Business', Icons.storefront_outlined),
      ('Self Directed IRA', Icons.account_balance_wallet_outlined),
      ('Credit Strong', Icons.credit_score_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF003F7A), MkgColors.primary],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial services', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 8),
              Text(
                'Payments, loans & wealth tools',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _toast(context, 'Cash App Send/Receive (demo)'),
                icon: const Icon(Icons.south_west),
                label: const Text('Send / Receive'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _toast(context, 'Venmo loan payment (demo)'),
                icon: const Icon(Icons.north_east),
                label: const Text('Loan Payment'),
              ),
            ),
          ],
        ),
        const SectionHeader('Products'),
        ...products.map(
          (p) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: MkgColors.lightPrimary,
                child: Icon(p.$2, color: MkgColors.primary),
              ),
              title: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Tap to learn more'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _toast(context, '${p.$1} details coming soon'),
            ),
          ),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class AccountOverviewScreen extends StatelessWidget {
  const AccountOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = const [
      ('IRS Funding Update', 'Reviewed', MkgColors.green),
      ('E-File Status', 'Accepted', MkgColors.primary),
      ('Audit Notice', 'None', MkgColors.textGrey),
      ('State Funding', 'Pending', MkgColors.orange),
      ('Secure Messages', '2 new', MkgColors.primary),
    ];

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: MkgColors.primary,
            tabs: [
              Tab(text: 'Notification Center'),
              Tab(text: 'Account Activity'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final a in alerts)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.notifications_active_outlined, color: MkgColors.primary),
                          title: Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: StatusChip(label: a.$2, color: a.$3),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    Card(
                      child: ListTile(
                        title: Text('Profile updated'),
                        subtitle: Text('Yesterday · Demo activity feed'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text('Document uploaded'),
                        subtitle: Text('2 days ago · W-2.pdf'),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        title: Text('Form started'),
                        subtitle: Text('3 days ago · Client Data Sheet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BankingScreen extends StatelessWidget {
  const BankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: MkgColors.primary,
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DDA / Refund account', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text('•••• 4281', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Bank verification: Pending', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        const SectionHeader('Banking details'),
        const TextField(decoration: InputDecoration(labelText: 'Routing number', prefixIcon: Icon(Icons.tag))),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Account number', prefixIcon: Icon(Icons.credit_card))),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Debit card (optional)', prefixIcon: Icon(Icons.payment))),
        const SizedBox(height: 16),
        const SectionHeader('Mobile check deposit'),
        Row(
          children: [
            Expanded(child: _UploadTile(label: 'Front of check', icon: Icons.photo_camera_front_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _UploadTile(label: 'Back of check', icon: Icons.photo_camera_back_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo: banking submit will call Laravel API.')),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: MkgColors.surfaceGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EEF5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: MkgColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class BlogsScreen extends StatelessWidget {
  const BlogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = const [
      ('Tax season checklist for 2025', 'Planning', '5 min read'),
      ('What documents should I upload?', 'Documents', '3 min read'),
      ('Understanding your refund timeline', 'Refunds', '4 min read'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('Latest News'),
        for (final p in posts)
          Card(
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MkgColors.lightPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.article, color: MkgColors.primary),
              ),
              title: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p.$2} · ${p.$3}'),
              trailing: const Icon(Icons.bookmark_border),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening “${p.$1}” (demo)')),
                );
              },
            ),
          ),
      ],
    );
  }
}
