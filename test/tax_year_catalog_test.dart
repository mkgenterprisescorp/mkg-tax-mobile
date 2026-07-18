import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/laravel_api_client.dart';
import 'package:mkg_tax_mobile/core/tax_year/tax_year_repository.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_defaults.dart';

void main() {
  test('local tax-year fallback uses current calendar year - 1 window', () async {
    final repo = TaxYearRepository(LaravelApiClient.create(baseUrl: 'http://127.0.0.1:9'));
    final catalog = await repo.listTaxYears();
    final expectedCurrent = DateTime.now().year - 1;
    expect(catalog.current, expectedCurrent);
    expect(catalog.years.length, 10);
    expect(catalog.years.first.taxYear, expectedCurrent);
    expect(catalog.years.last.taxYear, expectedCurrent - 9);
    expect(catalog.source, 'local-fallback');
  });

  test('filing year dropdown options cover last 10 years newest first', () {
    final options = filingYearOptions(currentYear: 2025);
    expect(options.length, 10);
    expect(options.map((e) => e.$1).toList(), [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016]);
    expect(options.first.$2, contains('Current Filing Season'));
    expect(options[1].$2, '2024');
  });
}
