import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/us_states.dart';

void main() {
  test('income-tax set matches web Organizer (41 states + DC)', () {
    expect(statesWithIncomeTax.length, 42);
    expect(statesWithIncomeTax.contains('CA'), isTrue);
    expect(statesWithIncomeTax.contains('NY'), isTrue);
    expect(statesWithIncomeTax.contains('DC'), isTrue);
    // No broad personal income tax
    expect(statesWithIncomeTax.contains('TX'), isFalse);
    expect(statesWithIncomeTax.contains('FL'), isFalse);
    expect(statesWithIncomeTax.contains('WA'), isFalse);
    expect(statesWithIncomeTax.contains('NH'), isFalse);
    expect(incomeTaxStateOptions.length, 42);
    expect(emptyAdditionalStateReturn(stateCode: 'NY')['filingRequired'], isTrue);
    expect(emptyAdditionalStateReturn(stateCode: 'TX')['filingRequired'], isFalse);
  });

  test('CA residency dropdown includes resident and nonresident', () {
    final values = residencyTypeOptions.map((e) => e.$1).toSet();
    expect(values, containsAll(['resident', 'nonresident', 'part_year']));
    expect(
      residencyTypeOptions.map((e) => e.$2).toList(),
      containsAll(['Resident', 'Nonresident']),
    );
  });
}
