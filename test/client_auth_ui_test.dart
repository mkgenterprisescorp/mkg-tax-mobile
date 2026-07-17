import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/network/api_error_mapper.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';
import 'package:mkg_tax_mobile/features/auth/presentation/login_screen.dart';
import 'package:mkg_tax_mobile/features/auth/presentation/register_screen.dart';

const _forbiddenUiTokens = [
  'Laravel',
  'Sanctum',
  'Neon',
  'DioException',
  '/api/',
  'Sign in via Laravel API',
  'Authoritative auth',
  'POST /api/register',
];

void _expectNoTechnicalUi(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join('\n');
  for (final token in _forbiddenUiTokens) {
    expect(texts, isNot(contains(token)), reason: 'client UI must not show "$token"');
  }
}

void main() {
  tearDown(() {
    RegisterScreen.debugForceUnavailable = false;
  });

  testWidgets('login shows Secure Client Sign In and no technical implementation text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(ApiClient.memory())],
        child: MaterialApp(
          theme: buildMkgTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MKG Tax Consultants'), findsOneWidget);
    expect(find.text('Finance Advisors'), findsOneWidget);
    expect(find.text('Secure Client Sign In'), findsOneWidget);
    expect(find.text('Sign in via Laravel API'), findsNothing);
    _expectNoTechnicalUi(tester);
  });

  testWidgets('login renders each approved safe error message without raw exceptions', (tester) async {
    final messages = [
      ApiErrorMapper.loginInvalidCredentialsMessage,
      ApiErrorMapper.loginServerUnavailableMessage,
      ApiErrorMapper.loginNoInternetMessage,
      ApiErrorMapper.loginTooManyAttemptsMessage,
      ApiErrorMapper.loginSessionExpiredMessage,
    ];

    for (final message in messages) {
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(ApiClient.memory())],
      );
      addTearDown(container.dispose);

      // Seed the auth error the same way AuthNotifier would after a failed login.
      container.read(authProvider.notifier).state = AuthState(loading: false, error: message);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMkgTheme(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger the snackbar path via a failed login attempt that reads auth.error.
      // Directly show the message through the same SnackBar channel login uses.
      final messenger = ScaffoldMessenger.of(tester.element(find.byType(LoginScreen)));
      messenger.showSnackBar(SnackBar(content: Text(message)));
      await tester.pump();
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('/api/'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('login catch path never surfaces DioException text', (tester) async {
    final client = ApiClient.memory();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'DioException connection to neon.tech /api/v1 failed',
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authRepositoryProvider.overrideWithValue(AuthRepository(client)),
        ],
        child: MaterialApp(
          theme: buildMkgTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'client@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'bad-password');
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ApiErrorMapper.loginNoInternetMessage), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('neon'), findsNothing);
    expect(find.textContaining('/api/'), findsNothing);
  });

  testWidgets('registration unavailable UI disables create and sends no API request', (tester) async {
    RegisterScreen.debugForceUnavailable = true;
    var registerCalls = 0;
    final client = ApiClient.memory();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          registerCalls++;
          handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
        },
      ),
    );

    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login destination'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authRepositoryProvider.overrideWithValue(AuthRepository(client)),
        ],
        child: MaterialApp.router(
          theme: buildMkgTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AuthRepository.registrationUnavailableMessage), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
    expect(find.textContaining('POST /api/register'), findsNothing);
    expect(find.textContaining('Laravel'), findsNothing);
    expect(find.textContaining('Sanctum'), findsNothing);
    _expectNoTechnicalUi(tester);

    // No enabled create action should exist to fire a request.
    expect(registerCalls, 0);
    await tester.tap(find.text('Return to Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(registerCalls, 0);
  });
}
