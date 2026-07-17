import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';
import 'package:mkg_tax_mobile/features/auth/presentation/forgot_password_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient.memory());

  int requestCount = 0;
  int resetCount = 0;
  String? lastEmail;
  String? lastCode;
  String? lastPassword;
  String? failRequestWith;
  String? failResetWith;

  @override
  Future<void> requestPasswordReset(String email) async {
    requestCount++;
    lastEmail = email;
    if (failRequestWith != null) throw AuthException(failRequestWith!);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    resetCount++;
    lastEmail = email;
    lastCode = code;
    lastPassword = newPassword;
    if (failResetWith != null) throw AuthException(failResetWith!);
  }
}

void main() {
  testWidgets('forgot password walks email → code → new password', (tester) async {
    final fake = _FakeAuthRepository();
    final router = GoRouter(
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login page'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          theme: buildMkgTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'reset-user@example.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();

    expect(fake.requestCount, 1);
    expect(find.text('Enter reset code'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Create new password'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'NewPass123!');
    await tester.enterText(fields.at(1), 'NewPass123!');
    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();

    expect(fake.resetCount, 1);
    expect(fake.lastEmail, 'reset-user@example.com');
    expect(fake.lastCode, '123456');
    expect(fake.lastPassword, 'NewPass123!');
    expect(find.text('Login page'), findsOneWidget);
  });

  testWidgets(
    'forgot password: success and AuthException produce identical observable state',
    (tester) async {
      final existingAccountResult = await _runSendCodeStep(tester, failRequestWith: null);
      final nonexistentAccountResult = await _runSendCodeStep(
        tester,
        failRequestWith: 'Some server-reported outcome that must never surface',
      );

      expect(
        existingAccountResult.snackBarText,
        nonexistentAccountResult.snackBarText,
        reason: 'the acknowledgement text must be identical regardless of account existence',
      );
      expect(
        existingAccountResult.screenTitle,
        nonexistentAccountResult.screenTitle,
        reason: 'the screen transition must be identical regardless of account existence',
      );
      expect(existingAccountResult.screenTitle, 'Enter reset code');
      expect(existingAccountResult.snackBarText, passwordResetAcknowledgement);
      expect(existingAccountResult.snackBarText, isNot(contains('Some server-reported outcome')));
    },
  );

  testWidgets(
    'forgot password: unexpected repository throw still shows the same acknowledgement and code step',
    (tester) async {
      final result = await _runSendCodeStep(
        tester,
        failRequestWith: 'DioException [bad response]: Internal server error',
      );
      expect(result.snackBarText, passwordResetAcknowledgement);
      expect(result.screenTitle, 'Enter reset code');
      expect(result.snackBarText, isNot(contains('DioException')));
      expect(result.snackBarText, isNot(contains('Internal server error')));
    },
  );
}

/// Blocker 4: drives the "send code" step for a given fake repository
/// behavior and returns everything observable to the user afterward - the
/// SnackBar text and the screen title reached. Used to compare an
/// existing-account (success) run against a nonexistent-account
/// (AuthException) run and assert they are indistinguishable. Each call
/// pumps its own fresh widget tree so the two runs can't leak state into
/// each other.
Future<({String? snackBarText, String screenTitle})> _runSendCodeStep(
  WidgetTester tester, {
  String? failRequestWith,
}) async {
  final fake = _FakeAuthRepository()..failRequestWith = failRequestWith;
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login page'))),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp.router(
        theme: buildMkgTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'probe@example.com');
  await tester.tap(find.text('Send Reset Code'));
  await tester.pump();
  // One frame after the SnackBar is shown, before pumpAndSettle would let
  // its timer dismiss it - this is the moment the observable state (text +
  // screen) must already be identical between the two runs.
  await tester.pump(const Duration(milliseconds: 100));

  String? snackBarText;
  final snackBarFinder = find.byType(SnackBar);
  if (snackBarFinder.evaluate().isNotEmpty) {
    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    snackBarText = (snackBar.content as Text).data;
  }

  await tester.pumpAndSettle();
  final screenTitle = find.text('Forgot password').evaluate().isNotEmpty
      ? 'Forgot password'
      : find.text('Enter reset code').evaluate().isNotEmpty
          ? 'Enter reset code'
          : 'unknown';

  return (snackBarText: snackBarText, screenTitle: screenTitle);
}
