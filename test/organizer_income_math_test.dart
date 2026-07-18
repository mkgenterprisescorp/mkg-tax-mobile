import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_income_math.dart';

void main() {
  test('W-2 rolls to Line 1a and 25a', () {
    final rolled = applyIncomeRollups({
      'w2Forms': [
        {'box1_wagesTips': 50000, 'box2_fedTaxWithheld': 4000},
        {'box1_wagesTips': 10000, 'box2_fedTaxWithheld': 800},
      ],
    });
    expect(rolled['wages'], 60000);
    expect(rolled['taxWithheldW2'], 4800);
    expect(rolled['taxWithheld'], 4800);
  });

  test('1099-NEC and 1099-K feed business income', () {
    final rolled = applyIncomeRollups({
      'form1099NEC': [
        {'box1_nonemployeeComp': 12000, 'box4_fedTaxWithheld': 100},
      ],
      'form1099K': [
        {'box1a_grossAmount': 3000},
      ],
    });
    expect(rolled['necCompensation'], 12000);
    expect(rolled['businessIncome'], 15000);
    expect(rolled['taxWithheld1099'], 100);
  });

  test('1099-R IRA vs pension split for Lines 4 and 5', () {
    final rolled = applyIncomeRollups({
      'form1099R': [
        {
          'box1_grossDistribution': 8000,
          'box2a_taxableAmount': 8000,
          'box7_iraSepSimple': true,
          'box4_fedTaxWithheld': 200,
        },
        {
          'box1_grossDistribution': 20000,
          'box2a_taxableAmount': 15000,
          'box7_iraSepSimple': false,
        },
      ],
    });
    expect(rolled['iraDistributionsGross'], 8000);
    expect(rolled['iraDistributions'], 8000);
    expect(rolled['pensionAnnuitiesGross'], 20000);
    expect(rolled['pensionAnnuities'], 15000);
    expect(rolled['taxWithheld1099'], 200);
  });

  test('SSA-1099 and 1099-G map to Lines 6 and Schedule 1', () {
    final rolled = applyIncomeRollups({
      'formSSA1099': [
        {'box5_netBenefits': 18000, 'taxableBenefits': 9000, 'box6_voluntaryTaxWithheld': 300},
      ],
      'form1099G': [
        {'box1_unemployment': 2400, 'box2_stateLocalRefund': 450, 'box4_fedTaxWithheld': 50},
      ],
    });
    expect(rolled['socialSecurityGross'], 18000);
    expect(rolled['socialSecurityBenefits'], 9000);
    expect(rolled['unemploymentComp'], 2400);
    expect(rolled['stateTaxRefund'], 450);
    expect(rolled['schedule1']['unemployment'], 2400);
    expect(rolled['schedule1']['stateTaxRefund'], 450);
    expect(rolled['taxWithheld1099'], 350);
  });

  test('1099-DA and 1099-B roll to Line 7 capital gains', () {
    final rolled = applyIncomeRollups({
      'form1099DA': [
        {'proceeds': 5000, 'costBasis': 2000, 'gainLoss': 3000},
      ],
      'form1099B': [
        {'proceeds': 1000, 'costBasis': 1500},
      ],
    });
    expect(rolled['capitalGains'], 2500);
  });

  test('1099-INT/DIV roll to Lines 2b / 3a / 3b', () {
    final rolled = applyIncomeRollups({
      'form1099INT': [
        {'box1_interestIncome': 120},
      ],
      'form1099DIV': [
        {'box1a_ordinaryDividends': 400, 'box1b_qualifiedDividends': 250},
      ],
    });
    expect(rolled['interestIncome'], 120);
    expect(rolled['dividendIncome'], 400);
    expect(rolled['qualifiedDividends'], 250);
    final summary = summarizeForm1040Income(rolled);
    expect(summary.line2bInterest, 120);
    expect(summary.line3aQualifiedDividends, 250);
    expect(summary.line3bOrdinaryDividends, 400);
  });
}
