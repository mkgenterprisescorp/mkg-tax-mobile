import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mkg_theme.dart';
import '../auth/data/auth_repository.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Aligned to web client primary destinations.
  static const _tabs = <({String path, String label, IconData icon})>[
    (path: '/forms', label: 'Home', icon: Icons.dashboard_customize_outlined),
    (path: '/documents', label: 'Docs', icon: Icons.folder_outlined),
    (path: '/organizer', label: 'Organizer', icon: Icons.assignment_outlined),
    (path: '/financial', label: 'Money', icon: Icons.payments_outlined),
    (path: '/profile', label: 'Profile', icon: Icons.person_outline),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  String _titleFor(String location) {
    if (location.startsWith('/documents')) return 'DOCUMENTS';
    if (location.startsWith('/messages') || location.startsWith('/chat')) return 'MESSAGES';
    if (location.startsWith('/tessa') || location.startsWith('/ai-assistant')) return 'TAXPRO ASSIST';
    if (location.startsWith('/billing') || location.startsWith('/payments')) return 'PAYMENTS';
    if (location.startsWith('/bookkeeping')) return 'BOOKKEEPING';
    if (location.startsWith('/organizer')) return 'TAX ORGANIZER';
    if (location.startsWith('/profile')) return 'PROFILE';
    if (location.startsWith('/support')) return 'SUPPORT';
    if (location.startsWith('/tools')) return 'TAX TOOLS';
    if (location.startsWith('/financial')) return 'FINANCIALS';
    if (location.startsWith('/account')) return 'ACCOUNT';
    if (location.startsWith('/banking')) return 'BANKING';
    if (location.startsWith('/blogs')) return 'LEARN';
    if (location.startsWith('/refund-tracker')) return 'REFUND TRACKER';
    return 'DASHBOARD';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexFor(location);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      drawer: _AppDrawer(userName: user?.displayName ?? 'Client', userEmail: user?.email ?? ''),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/brand/mkg_tax_logo.png', width: 28, height: 28, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(_titleFor(location), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.go('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'TaxPro Assist',
            onPressed: () => context.go('/tessa'),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final tab in _tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/mkg_tax_logo.png', width: 48, height: 48, fit: BoxFit.cover),
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
            item(Icons.payments_outlined, 'Financials', '/financial'),
            item(Icons.receipt_long_outlined, 'Payments', '/billing'),
            item(Icons.chat_bubble_outline, 'Messages', '/messages'),
            item(Icons.smart_toy_outlined, 'TaxPro Assist', '/tessa'),
            item(Icons.track_changes_outlined, 'Refund Tracker', '/refund-tracker'),
            item(Icons.menu_book_outlined, 'Bookkeeping', '/bookkeeping'),
            item(Icons.build_outlined, 'Tax Tools', '/tools'),
            item(Icons.support_agent_outlined, 'Support', '/support'),
            item(Icons.person_outline, 'Profile / KYC', '/profile'),
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
