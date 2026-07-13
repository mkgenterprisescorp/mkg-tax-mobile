import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Tax Organizer', '/organizer'),
      ('Engagements', '/engagements'),
      ('Documents', '/documents'),
      ('Messages', '/messages'),
      ('Tessa AI', '/tessa'),
      ('Billing', '/billing'),
      ('Bookkeeping', '/bookkeeping'),
      ('Notifications', '/notifications'),
      ('Tax Tools', '/tools'),
      ('Support', '/support'),
      ('Profile', '/profile'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ...items.map((e) => Card(
              child: ListTile(
                title: Text(e.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(e.$2),
              ),
            )),
      ],
    );
  }
}
