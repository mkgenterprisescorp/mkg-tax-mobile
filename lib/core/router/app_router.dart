import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/shell/app_shell.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/organizer', builder: (_, __) => const _Placeholder('Tax Organizer')),
          GoRoute(path: '/engagements', builder: (_, __) => const _Placeholder('Engagements')),
          GoRoute(path: '/documents', builder: (_, __) => const _Placeholder('Documents')),
          GoRoute(path: '/messages', builder: (_, __) => const _Placeholder('Messages')),
          GoRoute(path: '/tessa', builder: (_, __) => const _Placeholder('Tessa AI')),
          GoRoute(path: '/billing', builder: (_, __) => const _Placeholder('Technology Fee / Billing')),
          GoRoute(path: '/bookkeeping', builder: (_, __) => const _Placeholder('Bookkeeping')),
          GoRoute(path: '/notifications', builder: (_, __) => const _Placeholder('Notifications')),
          GoRoute(path: '/tools', builder: (_, __) => const _Placeholder('Tax Tools')),
          GoRoute(path: '/support', builder: (_, __) => const _Placeholder('Support')),
          GoRoute(path: '/profile', builder: (_, __) => const _Placeholder('Profile')),
        ],
      ),
    ],
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Center(child: Text(title));
}
