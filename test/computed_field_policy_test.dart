import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/computed_field_policy.dart';
import 'package:mkg_tax_mobile/features/organizer/data/federal_agi_math.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_income_math.dart';

void main() {
  test('estimateFederalAgi rolls wages minus adjustments', () {
    final agi = estimateFederalAgi({
      'w2Forms': [
        {'box1_wagesTips': 50000, 'box2_fedTaxWithheld': 4000},
      ],
      'schedule1': {
        'studentLoanInterest': 1000,
        'totalAdjustments': 1000,
      },
    });
    expect(agi, 49000);
  });

  test('applyIncomeRollups respects computedOverrides', () {
    final rolled = applyIncomeRollups({
      'w2Forms': [
        {'box1_wagesTips': 40000, 'box2_fedTaxWithheld': 3000},
      ],
      'wages': 1,
      'computedOverrides': {
        'wages': {'manual': true},
      },
    });
    expect(rolled['wages'], 1);
    expect(rolled['taxWithheldW2'], 3000);
  });

  test('markOverridden and clearOverride round-trip', () {
    var data = <String, dynamic>{'federalAGI': 10};
    data = ComputedFieldPolicy.markOverridden(data, 'federalAGI', byProfessional: true);
    expect(ComputedFieldPolicy.isOverridden(data, 'federalAGI'), isTrue);
    data = ComputedFieldPolicy.clearOverride(data, 'federalAGI');
    expect(ComputedFieldPolicy.isOverridden(data, 'federalAGI'), isFalse);
  });

  test('federal AGI policy is professional-only', () {
    expect(ComputedFieldPolicy.federalAgi.lockLevel, ComputedLockLevel.professionalOnly);
    expect(ComputedFieldPolicy.wages.lockLevel, ComputedLockLevel.consumerOverrideAllowed);
  });

  test('syncFederalAgi writes ca540.federalAGI when not overridden', () {
    final synced = syncFederalAgi({
      'w2Forms': [
        {
          'box1_wagesTips': 20000,
          'box2_fedTaxWithheld': 1000,
          'box15_state': 'CA',
          'box16_stateWages': 20000,
          'box17_stateTax': 800,
        },
      ],
      'ca540': {},
    });
    expect(synced['federalAGI'], 20000);
    expect((synced['ca540'] as Map)['federalAGI'], 20000);
    expect((synced['ca540'] as Map)['caWithholding'], 800);
  });
}
