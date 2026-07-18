/// Client-side CA Form 540 estimate math (web Organizer parity).
/// Server may recalculate; this powers live Line 97/100 summary in the mobile form.
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

  final totalPayments = _n(ca540['caWithholding'] ?? ca540['caTaxWithheld']) +
      _n(ca540['estimatedPayments'] ?? ca540['caEstimatedPayments']) +
      _n(ca540['withholding592B593']) +
      _n(ca540['motionPictureCredit']) +
      _n(ca540['calEITC']) +
      _n(ca540['youngChildTaxCredit']) +
      _n(ca540['fosterYouthTaxCredit']);

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
