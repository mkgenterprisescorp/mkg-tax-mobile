import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/clients/presentation/my_clients_screen.dart';
import '../../features/forms/presentation/forms_list_screen.dart';
import '../../features/home/presentation/main_tabs.dart';
import '../../features/iero/presentation/iero_extraction_screen.dart';
import '../../features/more/presentation/feature_screens.dart';
import '../../features/onboarding/presentation/splash_onboarding.dart';
import '../../features/organizer/presentation/organizer_screen.dart';
import '../../features/returns/presentation/all_returns_screen.dart';
import '../../features/shell/app_shell.dart';
import '../auth/app_roles.dart';

GoRouter createRouter({
  required Listenable refreshListenable,
  required AuthState Function() authReader,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = authReader();
      final loc = state.matchedLocation;
      const public = {
        '/splash',
        '/onboarding',
        '/login',
        '/register',
        '/forgot-password',
      };

      if (auth.loading && loc == '/splash') return null;

      if (!auth.isAuthenticated) {
        if (public.contains(loc)) return null;
        return '/login';
      }

      if (loc == '/splash' || loc == '/onboarding' || loc == '/login' || loc == '/register') {
        return '/forms';
      }

      // Legacy chat removed — Tessa AI is the only chat surface.
      if (loc == '/messages' || loc == '/chat') return '/tessa';

      // Professional-only tools: send consumers home.
      final role = auth.user?.role;
      final caps = capabilitiesFor(role);
      if (caps.isConsumer && (loc == '/my-clients' || loc == '/iero')) {
        return '/forms';
      }

      final user = auth.user;
      if (user != null) {
        final kycIncomplete = (user.kycStatus ?? 'incomplete') == 'incomplete';
        final pendingApproval =
            user.approvalStatus == 'pending' && user.kycStatus == 'submitted';
        final allowedWhilePending = loc == '/profile' || loc == '/forms' || loc == '/dashboard';
        if (pendingApproval && !allowedWhilePending) {
          return '/profile';
        }
        final created = user.createdAt != null ? DateTime.tryParse(user.createdAt!) : null;
        final isNew = created != null && !created.isBefore(DateTime.utc(2026, 2, 22));
        if (isNew && kycIncomplete && !(loc == '/profile' || loc == '/forms' || loc == '/dashboard')) {
          return '/profile';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/complete-profile', builder: (context, state) => const CompleteProfileScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/forms', builder: (context, state) => const FormsListScreen()),
          GoRoute(path: '/dashboard', redirect: (context, state) => '/forms'),
          GoRoute(path: '/financial', builder: (context, state) => const FinancialScreen()),
          GoRoute(path: '/financials', redirect: (context, state) => '/financial'),
          GoRoute(path: '/account', builder: (context, state) => const AccountOverviewScreen()),
          GoRoute(path: '/banking', builder: (context, state) => const BankingScreen()),
          GoRoute(path: '/blogs', builder: (context, state) => const BlogsScreen()),
          GoRoute(path: '/organizer', builder: (context, state) => const OrganizerScreen()),
          GoRoute(path: '/engagements', builder: (context, state) => const EngagementsScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/messages', redirect: (context, state) => '/tessa'),
          GoRoute(path: '/chat', redirect: (context, state) => '/tessa'),
          GoRoute(path: '/tessa', builder: (context, state) => const TessaScreen()),
          GoRoute(path: '/ai-assistant', redirect: (context, state) => '/tessa'),
          GoRoute(path: '/billing', builder: (context, state) => const BillingScreen()),
          GoRoute(path: '/payments', redirect: (context, state) => '/billing'),
          GoRoute(path: '/bookkeeping', builder: (context, state) => const BookkeepingScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/tools', builder: (context, state) => const ToolsScreen()),
          GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/refund-tracker', builder: (context, state) => const RefundTrackerScreen()),
          GoRoute(path: '/all-returns', builder: (context, state) => const AllReturnsScreen()),
          GoRoute(path: '/my-clients', builder: (context, state) => const MyClientsScreen()),
          GoRoute(path: '/iero', builder: (context, state) => const IeroExtractionScreen()),
        ],
      ),
    ],
  );
}

GoRouter createRouterFromRef(WidgetRef ref) {
  return createRouter(
    refreshListenable: ref.read(authRouterRefreshProvider),
    authReader: () => ref.read(authProvider),
  );
}
