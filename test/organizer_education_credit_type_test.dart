import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/presentation/organizer_credits_tessa_sheet.dart';

void main() {
  test('normalizeEducationCreditType maps AOTC and LLC aliases', () {
    expect(normalizeEducationCreditType('american_opportunity'), 'american_opportunity');
    expect(normalizeEducationCreditType('AMERICAN_OPPORTUNITY'), 'american_opportunity');
    expect(normalizeEducationCreditType(null), 'american_opportunity');
    expect(normalizeEducationCreditType(''), 'american_opportunity');
    expect(normalizeEducationCreditType('lifetime_learning'), 'lifetime_learning');
    expect(normalizeEducationCreditType('llc'), 'lifetime_learning');
    expect(normalizeEducationCreditType('Lifetime Learning'), 'lifetime_learning');
  });

  test('educationCreditTypeOptions expose friendly labels', () {
    expect(educationCreditTypeOptions.map((e) => e.$1).toList(), [
      'american_opportunity',
      'lifetime_learning',
    ]);
    expect(educationCreditTypeOptions.first.$2, contains('American Opportunity'));
    expect(educationCreditTypeOptions.last.$2, contains('Lifetime Learning'));
  });
}
