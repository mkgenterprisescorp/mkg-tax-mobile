import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/forms/presentation/forms_list_screen.dart';
import '../../features/home/presentation/main_tabs.dart';
import '../../features/more/presentation/feature_screens.dart';
import '../../features/shell/app_shell.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/complete-profile', builder: (_, __) => const CompleteProfileScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          // Legacy-parity primary tabs
          GoRoute(path: '/forms', builder: (_, __) => const FormsListScreen()),
          GoRoute(path: '/dashboard', redirect: (_, __) => '/forms'),
          GoRoute(path: '/financial', builder: (_, __) => const FinancialScreen()),
          GoRoute(path: '/account', builder: (_, __) => const AccountOverviewScreen()),
          GoRoute(path: '/banking', builder: (_, __) => const BankingScreen()),
          GoRoute(path: '/blogs', builder: (_, __) => const BlogsScreen()),
          // Feature areas
          GoRoute(path: '/organizer', builder: (_, __) => const OrganizerScreen()),
          GoRoute(path: '/engagements', builder: (_, __) => const EngagementsScreen()),
          GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
          GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
          GoRoute(path: '/tessa', builder: (_, __) => const TessaScreen()),
          GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
          GoRoute(path: '/bookkeeping', builder: (_, __) => const BookkeepingScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/tools', builder: (_, __) => const ToolsScreen()),
          GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
