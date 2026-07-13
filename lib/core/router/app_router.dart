import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/forms/presentation/forms_list_screen.dart';
import '../../features/home/presentation/main_tabs.dart';
import '../../features/more/presentation/feature_screens.dart';
import '../../features/onboarding/presentation/splash_onboarding.dart';
import '../../features/organizer/presentation/organizer_screen.dart';
import '../../features/shell/app_shell.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/splash',
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
          GoRoute(path: '/account', builder: (context, state) => const AccountOverviewScreen()),
          GoRoute(path: '/banking', builder: (context, state) => const BankingScreen()),
          GoRoute(path: '/blogs', builder: (context, state) => const BlogsScreen()),
          GoRoute(path: '/organizer', builder: (context, state) => const OrganizerScreen()),
          GoRoute(path: '/engagements', builder: (context, state) => const EngagementsScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/messages', builder: (context, state) => const MessagesScreen()),
          GoRoute(path: '/tessa', builder: (context, state) => const TessaScreen()),
          GoRoute(path: '/billing', builder: (context, state) => const BillingScreen()),
          GoRoute(path: '/bookkeeping', builder: (context, state) => const BookkeepingScreen()),
          GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/tools', builder: (context, state) => const ToolsScreen()),
          GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
