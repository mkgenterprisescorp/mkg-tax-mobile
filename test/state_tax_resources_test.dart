import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/states/data/state_tax_resources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => StateTaxResourcesCatalog.clearCache());

  test('bundled registry covers 51 jurisdictions with forms URLs', () async {
    final doc = await StateTaxResourcesCatalog.loadBundled();
    final states = (doc['states'] as List).whereType<Map>().toList();
    expect(states, hasLength(51));

    final federal = Map<String, dynamic>.from(doc['federal'] as Map);
    expect(federal['refund_tracker_url'], 'https://www.irs.gov/refunds');
    expect(federal['forms_url'], isNotEmpty);

    final byCode = {
      for (final s in states) s['code'].toString(): Map<String, dynamic>.from(s),
    };
    expect(byCode['CA']?['forms_url'], contains('ftb.ca.gov'));
    expect(byCode['CA']?['refund_tracker_url'], isNotNull);
    expect(byCode['TX']?['refund_tracker_url'], isNull);
    expect(byCode['AL']?['forms_url'], contains('revenue.alabama.gov'));

    for (final s in states) {
      expect(s['agency_url'], isNotEmpty, reason: '${s['code']} agency');
      expect(s['forms_url'], isNotEmpty, reason: '${s['code']} forms');
      expect(s['form_urls'], isA<Map>());
    }
  });
}
