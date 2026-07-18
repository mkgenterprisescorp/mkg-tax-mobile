import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/ca_business_estimate_math.dart';
import 'package:mkg_tax_mobile/features/organizer/presentation/organizer_ca_business_forms.dart';

void main() {
  test('prepType gates CA business forms like web Organizer', () {
    expect(caBusinessFormKeysForPrep('form1120'), containsAll(['caForm100', 'caScheduleR']));
    expect(caBusinessFormKeysForPrep('form1120S'), contains('caForm100S'));
    expect(caBusinessFormKeysForPrep('form1065'), contains('caForm565'));
    expect(caBusinessFormKeysForPrep('form1041'), contains('caForm541'));
    expect(caBusinessFormKeysForPrep('form990'), ['caForm199']);
    expect(caBusinessFormKeysForPrep('personal').length, 7);
  });

  test('Form 100 estimate applies franchise floor', () {
    final summary = summarizeCaForm100({
      'grossReceipts': 10000,
      'costOfGoodsSold': 2000,
      'salaries': 7000,
    });
    expect(summary['grossProfit'], 8000);
    expect(summary['minimumFranchiseTax'], 800);
    expect(summary['totalTax']! >= 800, isTrue);
  });

  test('Form 565 LLC fee bands', () {
    expect(estimateLlcFee(100000), 0);
    expect(estimateLlcFee(300000), 900);
    expect(estimateLlcFee(750000), 2500);
    expect(estimateLlcFee(2000000), 6000);
    expect(estimateLlcFee(6000000), 11790);

    final summary = summarizeCaForm565({'grossReceipts': 300000});
    expect(summary['llcFee'], 900);
    expect(summary['totalTax'], 1700);
  });

  test('Schedule R sales factor', () {
    final summary = summarizeCaScheduleR({
      'totalSalesEverywhere': 1000000,
      'caSales': 250000,
    });
    expect(summary['salesFactor'], 25);
    expect(summary['apportionmentPercentage'], 25);
  });

  test('applyEstimatePatch writes totals', () {
    final patched = applyEstimatePatch(
      {'corporationName': 'Acme'},
      {'totalTax': 800, 'taxDue': 800},
    );
    expect(patched['corporationName'], 'Acme');
    expect(patched['totalTax'], 800);
  });
}
