import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/app_roles.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../auth/data/auth_repository.dart';

/// Overflow hub for account, services, and professional tools.
class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final caps = capabilitiesFor(user?.role);

    Widget section(String title, List<_MoreItem> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon, color: MkgColors.primary),
              title: Text(item.label),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              trailing: const Icon(Icons.chevron_right),
              minVerticalPadding: 14,
              onTap: () => context.go(item.path),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: MkgColors.primary,
            child: Text(
              (user?.firstName.isNotEmpty == true ? user!.firstName[0] : 'U').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(user?.displayName ?? 'Account', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(user?.email ?? ''),
          trailing: Text(caps.edition.label, style: const TextStyle(fontWeight: FontWeight.w700, color: MkgColors.primary)),
        ),
        section('Account', const [
          _MoreItem('Profile', Icons.person_outline, '/profile'),
          _MoreItem('Identity verification', Icons.verified_user_outlined, '/profile'),
          _MoreItem('Security / 2FA', Icons.security_outlined, '/profile', subtitle: 'Manage on web if unavailable'),
          _MoreItem('Notifications', Icons.notifications_outlined, '/notifications'),
        ]),
        section('Services', const [
          _MoreItem('Individual & business taxes', Icons.description_outlined, '/returns'),
          _MoreItem('Bookkeeping', Icons.menu_book_outlined, '/bookkeeping'),
          _MoreItem('Financials / loans', Icons.payments_outlined, '/financial'),
          _MoreItem('Mortgage lending', Icons.home_work_outlined, '/financial'),
          _MoreItem('Billing & payments', Icons.receipt_long_outlined, '/billing'),
          _MoreItem('Refund tracker', Icons.track_changes_outlined, '/refund-tracker'),
          _MoreItem('Tax tools', Icons.calculate_outlined, '/tools'),
        ]),
        if (caps.isProfessional)
          section('Professional', const [
            _MoreItem('My Clients', Icons.groups_outlined, '/my-clients'),
            _MoreItem('All Tax Returns', Icons.library_books_outlined, '/all-returns'),
            _MoreItem('IRS iERO Extraction', Icons.travel_explore_outlined, '/iero'),
          ]),
        section('Support', const [
          _MoreItem('Ask TESSA', Icons.smart_toy_outlined, '/tessa'),
          _MoreItem('Support', Icons.support_agent_outlined, '/support'),
          _MoreItem('Terms & disclosures', Icons.policy_outlined, '/support'),
        ]),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: MkgColors.red),
          title: const Text('Sign out'),
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}

class _MoreItem {
  const _MoreItem(this.label, this.icon, this.path, {this.subtitle});
  final String label;
  final IconData icon;
  final String path;
  final String? subtitle;
}
