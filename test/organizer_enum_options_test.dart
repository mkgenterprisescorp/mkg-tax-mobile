import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_enum_options.dart';

void main() {
  test('normalizeEnumValue exact and case-insensitive match', () {
    expect(normalizeEnumValue('self', hsaCoverageOptions, fallback: 'family'), 'self');
    expect(normalizeEnumValue('FAMILY', hsaCoverageOptions, fallback: 'self'), 'family');
    expect(normalizeEnumValue('cash', accountingMethodOptions, fallback: 'accrual'), 'cash');
  });

  test('normalizeEnumValue empty prefers empty option when present', () {
    expect(normalizeEnumValue('', w2Box12CodeOptions, fallback: 'D'), '');
    expect(normalizeEnumValue(null, w2Box12CodeOptions, fallback: 'D'), '');
  });

  test('normalizeEnumValue does not false-match short IRS codes', () {
    expect(normalizeEnumValue('AA', w2Box12CodeOptions, fallback: ''), 'AA');
    expect(normalizeEnumValue('A', w2Box12CodeOptions, fallback: ''), 'A');
    expect(normalizeEnumValue('ZZ', w2Box12CodeOptions, fallback: ''), '');
  });

  test('normalizeEnumValue loose-matches longer free-text labels', () {
    expect(
      normalizeEnumValue('Self-only', hsaCoverageOptions, fallback: 'family'),
      'self',
    );
    expect(
      normalizeEnumValue('sole proprietorship', scheduleCBusinessTypeOptions, fallback: ''),
      'sole_proprietorship',
    );
  });

  test('shared option lists cover organizer high-priority enums', () {
    expect(hsaCoverageOptions.map((e) => e.$1), containsAll(['self', 'family']));
    expect(accountingMethodOptions.map((e) => e.$1), containsAll(['cash', 'accrual']));
    expect(scheduleRFilingStatusOptions, isNotEmpty);
    expect(form1041EntityTypeOptions.map((e) => e.$1), contains('simple_trust'));
    expect(partnershipTypeOptions.map((e) => e.$1), contains('general'));
    expect(bankAccountTypeOptions.map((e) => e.$1), containsAll(['checking', 'savings']));
    expect(caPaymentMethodOptions.map((e) => e.$1), contains('web_pay'));
    expect(form1099RDistributionCodeOptions.map((e) => e.$1), contains('7'));
  });
}
