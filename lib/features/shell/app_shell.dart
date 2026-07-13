import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mkg_theme.dart';
import '../auth/data/auth_repository.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <({String path, String label, IconData icon})>[
    (path: '/financial', label: 'Financial', icon: Icons.payments_outlined),
    (path: '/account', label: 'Account', icon: Icons.notifications_outlined),
    (path: '/forms', label: 'Home', icon: Icons.dashboard_customize_outlined),
    (path: '/banking', label: 'Banking', icon: Icons.account_balance_outlined),
    (path: '/blogs', label: 'Learn', icon: Icons.article_outlined),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 2;
  }

  String _titleFor(String location) {
    if (location.startsWith('/documents')) return 'DOCUMENTS';
    if (location.startsWith('/messages')) return 'MESSAGES';
    if (location.startsWith('/tessa')) return 'TAXPRO ASSIST';
    if (location.startsWith('/billing')) return 'PAYMENTS';
    if (location.startsWith('/bookkeeping')) return 'BOOKKEEPING';
    if (location.startsWith('/organizer')) return 'TAX ORGANIZER';
    if (location.startsWith('/profile')) return 'PROFILE';
    if (location.startsWith('/support')) return 'SUPPORT';
    if (location.startsWith('/tools')) return 'TAX TOOLS';
    if (location.startsWith('/financial')) return 'FINANCIALS';
    if (location.startsWith('/account')) return 'ACCOUNT';
    if (location.startsWith('/banking')) return 'BANKING';
    if (location.startsWith('/blogs')) return 'LEARN';
    return 'DASHBOARD';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFor(location);
    final showBottomNav = _tabs.any((t) => location.startsWith(t.path));
    final user = ref.watch(authProvider).user;

    return Scaffold(
      drawer: _AppDrawer(userName: user?.displayName ?? 'Client', userEmail: user?.email ?? ''),
      appBar: AppBar(
        title: Text(_titleFor(location)),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.go('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i].path),
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
              ],
            )
          : null,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.userName, required this.userEmail});
  final String userName;
  final String userEmail;

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
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: MkgColors.primary, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                  Text(userEmail, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            item(Icons.dashboard_outlined, 'Dashboard', '/forms'),
            item(Icons.folder_outlined, 'Documents', '/documents'),
            item(Icons.assignment_outlined, 'Tax Organizer', '/organizer'),
            item(Icons.receipt_long_outlined, 'Payments', '/billing'),
            item(Icons.menu_book_outlined, 'Bookkeeping', '/bookkeeping'),
            item(Icons.smart_toy_outlined, 'TaxPro Assist', '/tessa'),
            item(Icons.build_outlined, 'Tax Tools', '/tools'),
            item(Icons.support_agent_outlined, 'Support', '/support'),
            item(Icons.person_outline, 'Profile', '/profile'),
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
