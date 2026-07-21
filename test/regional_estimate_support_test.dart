import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/regional_estimate_support.dart';
import 'package:mkg_tax_mobile/features/organizer/data/rollout_regions.dart';
import 'package:mkg_tax_mobile/features/states/data/regional_state_tax_repository.dart';

void main() {
  test('Regions 2–5 PIT states support regional personal estimates', () {
    expect(supportsRegionalPersonalEstimate('IL'), isTrue);
    expect(supportsRegionalPersonalEstimate('OH'), isTrue);
    expect(supportsRegionalPersonalEstimate('GA'), isTrue);
    expect(supportsRegionalPersonalEstimate('PA'), isTrue);
    expect(supportsRegionalPersonalEstimate('NY'), isTrue);
    expect(supportsRegionalPersonalEstimate('NJ'), isTrue);
    expect(supportsRegionalPersonalEstimate('MA'), isTrue);

    expect(isRegion2Through5EstimateState('IL'), isTrue);
    expect(isRegion2Through5EstimateState('NY'), isTrue);
    expect(isRegion2Through5EstimateState('AZ'), isFalse); // Region 1
    expect(isRegion2Through5EstimateState('CO'), isFalse); // Region 6
  });

  test('no-broad-PIT and CA do not show personal estimate UI', () {
    expect(supportsRegionalPersonalEstimate('CA'), isFalse);
    expect(supportsRegionalPersonalEstimate('TX'), isFalse);
    expect(supportsRegionalPersonalEstimate('FL'), isFalse);
    expect(supportsRegionalPersonalEstimate('WA'), isFalse);
    expect(supportsRegionalPersonalEstimate('SD'), isFalse);
    expect(supportsRegionalPersonalEstimate('NH'), isFalse);
  });

  test('business family does not use personal estimate action', () {
    expect(
      supportsRegionalPersonalEstimate('IL', family: 'corporation'),
      isFalse,
    );
    expect(
      supportsRegionalPersonalEstimate('IL', family: 'individual'),
      isTrue,
    );
  });

  test('estimateCapableStatesForRegions covers Midwest through Northeast', () {
    final codes = estimateCapableStatesForRegions(regions2Through5);
    expect(codes, containsAll(['IL', 'IN', 'GA', 'PA', 'NY', 'MA']));
    expect(codes, isNot(contains('AZ')));
    expect(codes, isNot(contains('TX')));
    expect(codes, isNot(contains('CA')));
    // Every listed code maps to R2–5.
    for (final code in codes) {
      expect(regions2Through5.contains(regionForState(code)!.id), isTrue);
    }
  });

  test('RegionalEstimateView parses legacy Region 1 and engine payloads', () {
    final legacy = RegionalEstimateView.fromResponse({
      'form': '140',
      'tax': 1200,
      'refund_or_owed': 300,
      'disclaimer': 'legacy',
      'status': 'estimated',
    });
    expect(legacy.formLabel, '140');
    expect(legacy.tax, 1200);
    expect(legacy.refundOrOwed, 300);

    final engine = RegionalEstimateView.fromResponse({
      'gross_state_tax': 2100,
      'estimated_refund': 0,
      'balance_due': 400,
      'status': 'estimated',
      'tax_regime': 'broad_personal_income_tax',
      'forms': [
        {'form_code': 'IT-201'},
      ],
    });
    expect(engine.formLabel, 'IT-201');
    expect(engine.tax, 2100);
    expect(engine.refundOrOwed, -400);
    expect(engine.taxRegime, 'broad_personal_income_tax');
  });
}
