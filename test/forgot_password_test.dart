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
}
