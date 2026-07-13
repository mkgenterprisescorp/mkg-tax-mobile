import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mkg_tax_mobile/main.dart';

void main() {
  testWidgets('app boots to login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MkgTaxApp()));
    expect(find.text('MKG Tax'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });
}
