import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/ca540_estimate_math.dart';

void main() {
  test('calcCaTax single matches known AGI 52000 bracket path', () {
    // Taxable = 52000 - 5706 = 46294 → ~1325
    expect(calcCaTax(46294, 'single'), 1325);
  });

  test('summarizeCa540 produces refund for AGI 52000 / WH 2500 single', () {
    final summary = summarizeCa540(
      ca540: {
        'federalAGI': 52000,
        'caSubtractions': 0,
        'caAdditions': 0,
        'deductionType': 'standard',
        'personalExemptions': 1,
        'caWithholding': 2500,
        'estimatedPayments': 0,
      },
      filingStatus: 'single',
    );
    expect(summary.caTax, 1325);
    expect(summary.taxableIncome, 46294);
    expect(summary.isRefund, isTrue);
    expect(summary.refundOrOwed, greaterThan(0));
  });

  test('residency nonresident still computes estimate from payments/tax', () {
    final summary = summarizeCa540(
      ca540: {
        'residencyStatus': 'nonresident',
        'federalAGI': 10000,
        'caWithholding': 500,
        'personalExemptions': 1,
      },
      filingStatus: 'single',
    );
    // Low AGI also picks up auto CalEITC in payments when blank.
    expect(summary.totalPayments, greaterThanOrEqualTo(500));
  });

  test('estimateCalEitc TY2025 peaks and income cap', () {
    final peak = estimateCalEitc(earnedIncome: 4661, qualifyingChildren: 0);
    expect(peak.calEitc, 302);
    final over = estimateCalEitc(earnedIncome: 40000, qualifyingChildren: 2);
    expect(over.calEitc, 0);
    final withKid = estimateCalEitc(
      earnedIncome: 18000,
      federalAgi: 18000,
      qualifyingChildren: 1,
      hasYoungChild: true,
    );
    expect(withKid.calEitc, greaterThan(0));
    expect(withKid.youngChildTaxCredit, 1189);
  });

  test('summarizeCa540 auto-includes CalEITC when blank and eligible', () {
    final summary = summarizeCa540(
      ca540: {
        'federalAGI': 18000,
        'caWithholding': 200,
        'dependentExemptions': 1,
        'hasYoungChild': true,
      },
      filingStatus: 'single',
    );
    expect(summary.totalPayments, greaterThan(200));
  });
}
