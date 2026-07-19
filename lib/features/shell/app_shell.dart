import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_roles.dart';
import '../../core/theme/mkg_theme.dart';
import '../auth/data/auth_repository.dart';

/// Dual-brand primary IA (home stays clean):
/// Home | Tax Center | Advisory | Chat | More
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const tabs = <({String path, String label, IconData icon})>[
    (path: '/home', label: 'Home', icon: Icons.home_outlined),
    (path: '/tax-center', label: 'Tax Center', icon: Icons.account_balance_wallet_outlined),
    (path: '/advisory', label: 'Advisory', icon: Icons.trending_up_outlined),
    (path: '/chat', label: 'Chat', icon: Icons.forum_outlined),
    (path: '/more', label: 'More', icon: Icons.menu_outlined),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < tabs.length; i++) {
      if (location == tabs[i].path || location.startsWith('${tabs[i].path}/')) return i;
    }
    if (location.startsWith('/forms') || location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/returns') ||
        location.startsWith('/organizer') ||
        location.startsWith('/documents') ||
        location.startsWith('/all-returns') ||
        location.startsWith('/refund-tracker') ||
        location.startsWith('/tax-resources') ||
        location.startsWith('/tools') ||
        location.startsWith('/payroll-tools') ||
        location.startsWith('/things-to-bring') ||
        location.startsWith('/tax-savings') ||
        location.startsWith('/ca-540')) {
      return 1;
    }
    if (location.startsWith('/financial') ||
        location.startsWith('/refund-advance') ||
        location.startsWith('/bookkeeping') ||
        location.startsWith('/banking') ||
        location.startsWith('/billing') ||
        location.startsWith('/payments')) {
      return 2;
    }
    if (location.startsWith('/tessa') ||
        location.startsWith('/ai-assistant') ||
        location.startsWith('/messages') ||
        location.startsWith('/support')) {
      return 3;
    }
    if (location.startsWith('/profile') ||
        location.startsWith('/my-clients') ||
        location.startsWith('/iero')) {
      return 4;
    }
    return 0;
  }

  String _titleFor(String location, RoleCapabilities caps) {
    if (location.startsWith('/tax-center')) return 'TAX CENTER';
    if (location.startsWith('/advisory')) return 'FINANCE ADVISORS';
    if (location.startsWith('/chat')) return 'ADVISOR CHAT';
    if (location.startsWith('/returns') || location.startsWith('/all-returns')) return 'TAX RETURNS';
    if (location.startsWith('/organizer')) return 'TAX ORGANIZER';
    if (location.startsWith('/documents')) return 'DOCUMENTS';
    if (location.startsWith('/tessa') || location.startsWith('/ai-assistant') || location.startsWith('/messages')) {
      return 'TESSA AI';
    }
    if (location.startsWith('/more')) return 'MORE';
    if (location.startsWith('/my-clients')) return 'MY CLIENTS';
    if (location.startsWith('/iero')) return 'IRS iERO';
    if (location.startsWith('/billing') || location.startsWith('/payments')) return 'PAYMENTS';
    if (location.startsWith('/banking')) return 'BANKING';
    if (location.startsWith('/bookkeeping')) return 'BOOKKEEPING';
    if (location.startsWith('/profile')) return 'PROFILE';
    if (location.startsWith('/support')) return 'SUPPORT';
    if (location.startsWith('/tools') || location.startsWith('/financial-tools') || location.startsWith('/payroll-tools')) {
      return 'FINANCIAL TOOLS';
    }
    if (location.startsWith('/tax-savings')) return 'TAX SAVINGS';
    if (location.startsWith('/things-to-bring')) return 'THINGS TO BRING';
    if (location.startsWith('/ca-540') || location.startsWith('/organizer/ca-540')) {
      return 'CA FORM 540';
    }
    if (location.startsWith('/financial') || location.startsWith('/refund-advance')) {
      return 'REFUND ADVANCE';
    }
    if (location.startsWith('/refund-tracker')) return 'REFUND TRACKER';
    if (location.startsWith('/tax-resources')) return 'TAX RESOURCES';
    return caps.isProfessional ? 'PRO HOME' : 'HOME';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(authProvider).user;
    final caps = capabilitiesFor(user?.role);
    final index = _indexFor(location);

    return Scaffold(
      drawer: _AppDrawer(
        userName: user?.displayName ?? 'User',
        userEmail: user?.email ?? '',
        caps: caps,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 28,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset('assets/brand/mkg_tax_logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(_titleFor(location, caps), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  caps.edition.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      floatingActionButton: location.startsWith('/tessa') || location.startsWith('/chat')
          ? null
          : FloatingActionButton(
              onPressed: () => _showQuickActions(context),
              backgroundColor: MkgColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, tabs.length - 1),
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(IconData icon, String label, String path) {
          return ListTile(
            leading: Icon(icon, color: MkgColors.primary),
            title: Text(label),
            minVerticalPadding: 16,
            onTap: () {
              Navigator.pop(ctx);
              context.go(path);
            },
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              tile(Icons.upload_file_outlined, 'Upload Document', '/documents'),
              tile(Icons.assignment_outlined, 'Start Tax Organizer', '/organizer'),
              tile(Icons.description_outlined, 'Continue Tax Return', '/returns'),
              tile(Icons.calculate_outlined, 'Financial Tools', '/tools'),
              tile(Icons.checklist_outlined, 'Things to Bring', '/things-to-bring'),
              tile(Icons.trending_up_outlined, 'Financial Planning', '/advisory'),
              tile(Icons.forum_outlined, 'Advisor Chat', '/chat'),
              tile(Icons.smart_toy_outlined, 'Ask TESSA', '/tessa'),
              tile(Icons.event_outlined, 'Schedule Appointment', '/support'),
            ],
          ),
        );
      },
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({
    required this.userName,
    required this.userEmail,
    required this.caps,
  });

  final String userName;
  final String userEmail;
  final RoleCapabilities caps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(IconData icon, String label, String path) {
      return ListTile(
        leading: Icon(icon, color: MkgColors.primary),
        title: Text(label),
        onTap: () {
          Navigator.of(context).pop();
          context.go(path);
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: MkgColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 56,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset('assets/brand/mkg_tax_logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 10),
                  const Text('MKG Tax Consultants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Finance Advisors', style: TextStyle(color: MkgColors.accent.withValues(alpha: 0.95), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(userEmail, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            item(Icons.home_outlined, 'Home', '/home'),
            item(Icons.account_balance_wallet_outlined, 'Tax Center', '/tax-center'),
            item(Icons.trending_up_outlined, 'Financial Planning', '/advisory'),
            item(Icons.forum_outlined, 'Advisor Chat', '/chat'),
            item(Icons.menu_outlined, 'More', '/more'),
            const Divider(),
            item(Icons.description_outlined, 'Tax Returns', '/returns'),
            item(Icons.assignment_outlined, 'Tax Organizer', '/organizer'),
            item(Icons.folder_outlined, 'Documents', '/documents'),
            item(Icons.calculate_outlined, 'Financial Tools', '/tools'),
            item(Icons.payments_outlined, 'Refund Advance', '/refund-advance'),
            item(Icons.receipt_long_outlined, 'Payments', '/billing'),
            item(Icons.smart_toy_outlined, 'TESSA AI', '/tessa'),
            if (caps.canManageClients) item(Icons.groups_outlined, 'My Clients', '/my-clients'),
            if (caps.canUseIeroTools) item(Icons.travel_explore_outlined, 'IRS iERO Extraction', '/iero'),
            item(Icons.person_outline, 'Profile / KYC', '/profile'),
            item(Icons.support_agent_outlined, 'Support', '/support'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: MkgColors.red),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
