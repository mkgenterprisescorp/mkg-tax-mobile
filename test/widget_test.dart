import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/main.dart';

void main() {
  testWidgets('app boots to branded login against financemkgtax API client', (tester) async {
    final api = ApiClient.memory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MkgTaxApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MKG Tax Consultants'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.textContaining('financemkgtax'), findsWidgets);
  });
}
