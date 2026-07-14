import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/router/app_router.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';
import 'package:mkg_tax_mobile/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('login screen uses Figma primary branding', (tester) async {
    final api = ApiClient.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: buildMkgTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MKG Tax Consultants'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Log In'))).colorScheme.primary, const Color(0xFF1A5632));
  });

  test('router starts at splash', () {
    final router = createRouter(
      refreshListenable: AuthRouterRefresh(),
      authReader: () => const AuthState(),
    );
    expect(router.routeInformationProvider.value.uri.path, '/splash');
  });
}
