import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/main.dart';

void main() {
  testWidgets('app boots to branded login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MkgTaxApp()));
    await tester.pumpAndSettle();
    expect(find.text('MKG Tax Consultants'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('demo login opens forms list', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MkgTaxApp()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'demo@mkgenterprisescorp.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Your 2025 tax forms'), findsOneWidget);
    expect(find.text('Forms List'), findsOneWidget);
  });
}
