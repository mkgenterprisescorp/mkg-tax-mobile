import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/core/widgets/mkg_widgets.dart';

void main() {
  testWidgets('dual brand header shows MKG Tax Consultants + Finance Advisors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMkgTheme(),
        home: const Scaffold(
          backgroundColor: MkgColors.primary,
          body: Center(child: DualBrandHeader(subtitle: 'Tax · Advisory · Planning')),
        ),
      ),
    );
    expect(find.text('MKG Tax Consultants'), findsOneWidget);
    expect(find.text('Finance Advisors'), findsOneWidget);
    expect(find.text('Tax · Advisory · Planning'), findsOneWidget);
  });
}
