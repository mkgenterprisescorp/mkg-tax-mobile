// Client-side CA Form 540 estimate math (web Organizer parity).
// Server may recalculate; this powers live Line 97/100 summary in the mobile form.

/// TY2025 CalEITC / YCTC / FYTC estimate (FTB 3514) for Form 540 autofill.
class CaCalEitcEstimate {
  const CaCalEitcEstimate({
    required this.calEitc,
    required this.youngChildTaxCredit,
    required this.fosterYouthTaxCredit,
    required this.earnedIncome,
    required this.qualifyingChildren,
    required this.eligible,
  });

  final num calEitc;
  final num youngChildTaxCredit;
  final num fosterYouthTaxCredit;
  final num earnedIncome;
  final int qualifyingChildren;
  final bool eligible;

  num get totalRefundable => calEitc + youngChildTaxCredit + fosterYouthTaxCredit;
}

/// TY2025 FTB published caps (estimate-only; full table is staff-reviewed).
const double kCalEitcMaxEarnedIncome = 32900;
const double kCalEitcInvestmentLimit = 4814;
const List<double> kCalEitcMaxCredits = [302, 2016, 3339, 3756];
const List<double> kCalEitcPhaseInEnds = [4661, 6998, 9823, 9823];
const double kYctcMax = 1189;
const double kYctcPhaseoutStart = 27425;
const double kYctcPhaseoutEnd = 32901;
const double kYctcReductionPer100 = 21.71;

CaCalEitcEstimate estimateCalEitc({
  required num earnedIncome,
  num? federalAgi,
  num investmentIncome = 0,
  int qualifyingChildren = 0,
  bool hasYoungChild = false,
  bool hasFosterYouth = false,
  bool disqualified = false,
}) {
  final earned = earnedIncome < 0 ? 0.0 : earnedIncome.toDouble();
  final agi = (federalAgi ?? earned).toDouble();
  final kids = qualifyingChildren.clamp(0, 3);
  final inv = investmentIncome < 0 ? 0.0 : investmentIncome.toDouble();

  var cal = 0.0;
  if (!disqualified &&
      inv <= kCalEitcInvestmentLimit &&
      earned >= 1 &&
      earned <= kCalEitcMaxEarnedIncome &&
      agi <= kCalEitcMaxEarnedIncome) {
    cal = _calEitcAmount(earned, kids);
  }

  var yctc = 0.0;
  if (hasYoungChild &&
      !disqualified &&
      inv <= kCalEitcInvestmentLimit &&
      agi <= kCalEitcMaxEarnedIncome &&
      (cal > 0 || earned <= 0)) {
    yctc = _yctcPhaseout(earned > 0 ? earned : 0);
  }

  var fytc = 0.0;
  if (hasFosterYouth &&
      cal > 0 &&
      !disqualified &&
      inv <= kCalEitcInvestmentLimit) {
    fytc = _yctcPhaseout(earned);
  }

  return CaCalEitcEstimate(
    calEitc: _round2(cal),
    youngChildTaxCredit: _round2(yctc),
    fosterYouthTaxCredit: _round2(fytc),
    earnedIncome: _round2(earned),
    qualifyingChildren: kids,
    eligible: cal > 0 || yctc > 0 || fytc > 0,
  );
}

double _calEitcAmount(double earned, int kids) {
  final max = kCalEitcMaxCredits[kids];
  final phaseInEnd = kCalEitcPhaseInEnds[kids];
  if (earned < 1 || earned > kCalEitcMaxEarnedIncome) return 0;
  if (earned <= phaseInEnd) return max * (earned / phaseInEnd);
  final span = kCalEitcMaxEarnedIncome - phaseInEnd;
  if (span <= 0) return 0;
  final ratio = 1 - ((earned - phaseInEnd) / span);
  return max * (ratio < 0 ? 0 : ratio);
}

double _yctcPhaseout(double earned) {
  if (earned <= kYctcPhaseoutStart) return kYctcMax;
  if (earned >= kYctcPhaseoutEnd) return 0;
  final excessHundreds = (earned - kYctcPhaseoutStart) / 100;
  return (kYctcMax - excessHundreds * kYctcReductionPer100).clamp(0, kYctcMax).toDouble();
}

num _round2(num v) => (v * 100).round() / 100;

class Ca540EstimateSummary {
  const Ca540EstimateSummary({
    required this.caAgi,
    required this.deduction,
    required this.taxableIncome,
    required this.caTax,
    required this.exemptionCredits,
    required this.taxAfterCredits,
    required this.totalTax,
    required this.totalPayments,
    required this.refundOrOwed,
    required this.behavioralHealthTax,
  });

  final num caAgi;
  final num deduction;
  final num taxableIncome;
  final num caTax;
  final num exemptionCredits;
  final num taxAfterCredits;
  final num totalTax;
  final num totalPayments;
  final num refundOrOwed;
  final num behavioralHealthTax;

  bool get isRefund => refundOrOwed >= 0;
}

num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

int _i(dynamic v) => int.tryParse('$v') ?? 0;

/// TY2025-style progressive CA tax (matches web `calcCATax`).
num calcCaTax(num taxableIncome, String filingStatus) {
  final isJoint = filingStatus == 'married_joint' ||
      filingStatus == 'married_filing_jointly' ||
      filingStatus == 'qualifying_widow' ||
      filingStatus == 'qualifying_surviving_spouse';
  final brackets = isJoint
      ? const <(double, double)>[
          (21980, 0.01),
          (52070, 0.02),
          (82160, 0.04),
          (113830, 0.06),
          (145500, 0.08),
          (750442, 0.093),
          (900530, 0.103),
          (1500882, 0.113),
          (double.infinity, 0.123),
        ]
      : const <(double, double)>[
          (10990, 0.01),
          (26035, 0.02),
          (41080, 0.04),
          (56915, 0.06),
          (72750, 0.08),
          (375221, 0.093),
          (450265, 0.103),
          (750441, 0.113),
          (double.infinity, 0.123),
        ];
  var tax = 0.0;
  var prev = 0.0;
  final income = taxableIncome.toDouble();
  for (final b in brackets) {
    if (income <= prev) break;
    final taxable = (income < b.$1 ? income : b.$1) - prev;
    tax += taxable * b.$2;
    prev = b.$1;
  }
  return tax.round();
}

num standardDeductionFor(String filingStatus) {
  final jointLike = filingStatus == 'married_joint' ||
      filingStatus == 'married_filing_jointly' ||
      filingStatus == 'qualifying_widow' ||
      filingStatus == 'qualifying_surviving_spouse' ||
      filingStatus == 'head_of_household';
  return jointLike ? 11412 : 5706;
}

Ca540EstimateSummary summarizeCa540({
  required Map<String, dynamic> ca540,
  required String filingStatus,
}) {
  final federalAgi = _n(ca540['federalAGI']);
  final subtractions = _n(ca540['caSubtractions']);
  final additions = _n(ca540['caAdditions']);
  final line15 = federalAgi - subtractions;
  final caAgi = line15 + additions;

  final deductionType = '${ca540['deductionType'] ?? 'standard'}';
  final std = standardDeductionFor(filingStatus);
  final deduction = deductionType == 'itemized' ? _n(ca540['itemizedDeduction']) : std;
  final taxableIncome = (caAgi - deduction) > 0 ? (caAgi - deduction) : 0;

  final caTax = calcCaTax(taxableIncome, filingStatus);
  final exemptionCredits = (_i(ca540['personalExemptions'] ?? 1) * 153) +
      (_i(ca540['blindExemptions']) * 153) +
      (_i(ca540['seniorExemptions']) * 153) +
      (_i(ca540['dependentExemptions']) * 475);
  final taxAfterExemptions = (caTax - exemptionCredits) > 0 ? (caTax - exemptionCredits) : 0;
  final line35 = taxAfterExemptions + _n(ca540['scheduleTax']);

  final nonrefundable = _n(ca540['childDependentCareCredit']) +
      _n(ca540['creditAmount1']) +
      _n(ca540['creditAmount2']) +
      _n(ca540['rentersCredit']) +
      _n(ca540['otherCredits']);
  final line48 = (line35 - nonrefundable) > 0 ? (line35 - nonrefundable) : 0;

  final bhStored = _n(ca540['behavioralHealthTax']);
  final bh = bhStored > 0
      ? bhStored
      : (taxableIncome > 1000000 ? ((taxableIncome - 1000000) * 0.01).round() : 0);
  final totalTax = line48 + _n(ca540['amt']) + bh + _n(ca540['otherTaxes']);

  // Auto-estimate CalEITC/YCTC/FYTC for live Form 540 payments when blank.
  var calEitc = _n(ca540['calEITC']);
  var yctc = _n(ca540['youngChildTaxCredit']);
  var fytc = _n(ca540['fosterYouthTaxCredit']);
  if (calEitc <= 0 || yctc <= 0 || fytc <= 0) {
    final earned = _n(ca540['earnedIncome']).toDouble() > 0
        ? _n(ca540['earnedIncome'])
        : (_n(ca540['stateWages']) > 0
            ? _n(ca540['stateWages'])
            : (federalAgi > 0 && federalAgi <= kCalEitcMaxEarnedIncome ? federalAgi : 0));
    final est = estimateCalEitc(
      earnedIncome: earned,
      federalAgi: federalAgi,
      investmentIncome: _n(ca540['investmentIncome']),
      qualifyingChildren: _i(ca540['qualifyingChildren'] ?? ca540['dependentExemptions']),
      hasYoungChild: ca540['hasYoungChild'] == true || _i(ca540['yctcChildAge']) < 6,
      hasFosterYouth: ca540['hasFosterYouth'] == true,
      disqualified: ca540['disqualifiedIncome'] == true,
    );
    if (calEitc <= 0) calEitc = est.calEitc;
    if (yctc <= 0) yctc = est.youngChildTaxCredit;
    if (fytc <= 0) fytc = est.fosterYouthTaxCredit;
  }

  final totalPayments = _n(ca540['caWithholding'] ?? ca540['caTaxWithheld']) +
      _n(ca540['estimatedPayments'] ?? ca540['caEstimatedPayments']) +
      _n(ca540['withholding592B593']) +
      _n(ca540['motionPictureCredit']) +
      calEitc +
      yctc +
      fytc;

  final useTax = _n(ca540['useTax']);
  final isr = _n(ca540['isrPenalty']);
  final refundOrOwed = totalPayments - totalTax - useTax - isr;

  return Ca540EstimateSummary(
    caAgi: caAgi,
    deduction: deduction,
    taxableIncome: taxableIncome,
    caTax: caTax,
    exemptionCredits: exemptionCredits,
    taxAfterCredits: line48,
    totalTax: totalTax,
    totalPayments: totalPayments,
    refundOrOwed: refundOrOwed,
    behavioralHealthTax: bh,
  );
}
