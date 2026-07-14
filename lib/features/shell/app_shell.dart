import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/app_roles.dart';
import '../../core/theme/mkg_theme.dart';
import '../auth/data/auth_repository.dart';

/// Final recommended IA:
/// Home | Tax Returns | Organizer | Documents | TESSA | More
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const tabs = <({String path, String label, IconData icon})>[
    (path: '/home', label: 'Home', icon: Icons.home_outlined),
    (path: '/returns', label: 'Returns', icon: Icons.description_outlined),
    (path: '/organizer', label: 'Organizer', icon: Icons.assignment_outlined),
    (path: '/documents', label: 'Documents', icon: Icons.folder_outlined),
    (path: '/tessa', label: 'TESSA', icon: Icons.smart_toy_outlined),
    (path: '/more', label: 'More', icon: Icons.menu_outlined),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < tabs.length; i++) {
      if (location == tabs[i].path || location.startsWith('${tabs[i].path}/')) return i;
    }
    // Legacy aliases map into primary tabs.
    if (location.startsWith('/forms') || location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/all-returns')) return 1;
    if (location.startsWith('/profile') ||
        location.startsWith('/financial') ||
        location.startsWith('/billing') ||
        location.startsWith('/my-clients') ||
        location.startsWith('/iero')) {
      return 5;
    }
    return 0;
  }

  String _titleFor(String location, RoleCapabilities caps) {
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
    if (location.startsWith('/bookkeeping')) return 'BOOKKEEPING';
    if (location.startsWith('/profile')) return 'PROFILE';
    if (location.startsWith('/support')) return 'SUPPORT';
    if (location.startsWith('/tools')) return 'TAX TOOLS';
    if (location.startsWith('/financial')) return 'FINANCIALS';
    if (location.startsWith('/refund-tracker')) return 'REFUND TRACKER';
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
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/brand/mkg_tax_logo.png', width: 28, height: 28, fit: BoxFit.cover),
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
      floatingActionButton: location.startsWith('/tessa')
          ? null
          : FloatingActionButton(
              onPressed: () => _showQuickActions(context, caps),
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

  void _showQuickActions(BuildContext context, RoleCapabilities caps) {
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
              tile(Icons.document_scanner_outlined, 'Scan Receipt', '/documents'),
              tile(Icons.smart_toy_outlined, 'Ask TESSA', '/tessa'),
              tile(Icons.assignment_outlined, 'Start Tax Organizer', '/organizer'),
              tile(Icons.description_outlined, 'Continue Tax Return', '/returns'),
              tile(Icons.history_edu_outlined, 'File a Prior Year', '/returns'),
              tile(Icons.event_outlined, 'Schedule Appointment', '/more'),
              tile(Icons.home_work_outlined, 'Apply for Mortgage', '/financial'),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/brand/mkg_tax_logo.png', width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                  Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                  Text(userEmail, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text(
                    '${caps.edition.label} · ${caps.role}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            item(Icons.home_outlined, 'Home', '/home'),
            item(Icons.description_outlined, 'Tax Returns', '/returns'),
            item(Icons.assignment_outlined, 'Tax Organizer', '/organizer'),
            item(Icons.folder_outlined, 'Documents', '/documents'),
            item(Icons.smart_toy_outlined, 'TESSA AI', '/tessa'),
            item(Icons.menu_outlined, 'More', '/more'),
            const Divider(),
            if (caps.canManageClients) item(Icons.groups_outlined, 'My Clients', '/my-clients'),
            if (caps.canUseIeroTools) item(Icons.travel_explore_outlined, 'IRS iERO Extraction', '/iero'),
            item(Icons.payments_outlined, 'Financials', '/financial'),
            item(Icons.receipt_long_outlined, 'Payments', '/billing'),
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
