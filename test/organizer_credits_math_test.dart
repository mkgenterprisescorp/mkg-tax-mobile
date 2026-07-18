import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_credits_math.dart';

void main() {
  test('scheduleATotal sums itemized rows', () {
    expect(
      scheduleATotal({
        'medicalExpenses': 100,
        'stateLocalTaxes': 200,
        'mortgageInterest': 300,
        'charitableCash': 50,
      }),
      650,
    );
  });

  test('form8863 AOTC caps at 2500 with refundable portion', () {
    final edu = form8863Estimate({
      'tuitionPaid': 8000,
      'scholarships': 0,
      'creditType': 'american_opportunity',
    });
    expect(edu.total, 2500);
    expect(edu.refundableAotc, 1000);
    expect(edu.nonrefundable, 1500);
  });

  test('form8863 LLC is 20% up to 2000', () {
    final edu = form8863Estimate({
      'tuitionPaid': 10000,
      'scholarships': 0,
      'creditType': 'lifetime_learning',
    });
    expect(edu.total, 2000);
    expect(edu.refundableAotc, 0);
  });

  test('scheduleSeEstimate computes SE tax and deductible half', () {
    final se = scheduleSeEstimate(netProfitScheduleC: 10000, netProfitPartnership: 0, farmIncome: 0, churchEmployeeIncome: 0);
    expect(se.netEarnings, closeTo(9235, 0.01));
    expect(se.selfEmploymentTax, closeTo(1412.96, 0.02));
    expect(se.deductiblePart, closeTo(706.48, 0.02));
  });

  test('applyCreditsRollups wires HSA, Sch A, 8812, 5695, QBI to Form 1040 fields', () {
    final rolled = applyCreditsRollups({
      'itemizeDeductions': true,
      'businessIncome': 50000,
      'form8889': {'hsaDeduction': 4150},
      'schedule1': {'educatorExpenses': 300},
      'scheduleA': {
        'medicalExpenses': 0,
        'stateLocalTaxes': 5000,
        'realEstateTaxes': 4000,
        'personalPropertyTaxes': 0,
        'mortgageInterest': 12000,
        'mortgageInsurancePremiums': 0,
        'charitableCash': 2000,
        'charitableNonCash': 0,
        'casualtyLosses': 0,
        'otherItemized': 0,
      },
      'schedule8812': {'qualifyingChildren': 2, 'otherDependents': 1},
      'form5695': {'solarElectric': 3000},
      'form8995': {'qualifiedBusinessIncome': 40000},
      'scheduleSE': {'netProfitScheduleC': 10000},
      'form8863': {
        'tuitionPaid': 8000,
        'scholarships': 0,
        'creditType': 'american_opportunity',
      },
    });

    expect(rolled['schedule1']['hsaDeduction'], 4150);
    expect(rolled['schedule1']['totalAdjustments'], greaterThan(4150));
    expect(rolled['scheduleA']['totalItemized'], 23000);
    expect(rolled['itemizedDeductions'], 23000);
    expect(rolled['childTaxCredit'], 4400);
    expect(rolled['otherDependentsCredit'], 500);
    expect(rolled['additionalChildTaxCredit'], 3400);
    expect(rolled['residentialEnergyCredit'], 3000);
    expect(rolled['qbiDeduction'], 8000);
    expect(rolled['educationCredits'], 2500);
    expect(rolled['form8863']['refundableAotc'], 1000);
    expect(rolled['schedule2']['selfEmploymentTax'], greaterThan(0));
    expect(rolled['scheduleSE']['deductiblePart'], greaterThan(0));

    final summary = summarizeForm1040Credits(rolled);
    expect(summary.line12eItemized, 23000);
    expect(summary.line13aQbi, 8000);
    expect(summary.line19CtcOdc, 4900);
    expect(summary.line28Actc, 3400);
    expect(summary.line29Aotc, 1000);
  });
}
