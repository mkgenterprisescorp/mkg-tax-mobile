/// Estimate-only rollups for California business entity forms (TY2025).
///
/// Franchise / LLC fee floors are well-published FTB constants used by the
/// web Organizer. Full certified entity tax engines remain deferred.
library;

num _n(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

/// CA minimum franchise / annual tax floor (Form 100 / 100S / 565 annual tax).
const caMinimumFranchiseTax = 800;

/// Published LLC fee bands (Form 568 / Form 565 LLC fee path) based on total income.
num estimateLlcFee(num totalIncome) {
  if (totalIncome < 250000) return 0;
  if (totalIncome < 500000) return 900;
  if (totalIncome < 1000000) return 2500;
  if (totalIncome < 5000000) return 6000;
  return 11790;
}

Map<String, num> summarizeCaForm100(Map<String, dynamic> form) {
  final grossReceipts = _n(form['grossReceipts']);
  final returnsAllowances = _n(form['returnsAllowances']);
  final cogs = _n(form['costOfGoodsSold']);
  final grossProfit = grossReceipts - returnsAllowances - cogs;
  final incomeParts = [
    grossProfit,
    _n(form['dividends']),
    _n(form['interest']),
    _n(form['rents']),
    _n(form['royalties']),
    _n(form['capitalGains']),
    _n(form['otherIncome']),
  ];
  final totalIncome = incomeParts.fold<num>(0, (a, b) => a + b);
  final deductionParts = [
    _n(form['compensation']),
    _n(form['salaries']),
    _n(form['repairs']),
    _n(form['badDebts']),
    _n(form['rentsExpense']),
    _n(form['taxesLicenses']),
    _n(form['interestExpense']),
    _n(form['depreciation']),
    _n(form['depletion']),
    _n(form['advertising']),
    _n(form['pensionPlans']),
    _n(form['employeeBenefits']),
    _n(form['otherDeductions']),
  ];
  final totalDeductions = deductionParts.fold<num>(0, (a, b) => a + b);
  final netIncome = totalIncome - totalDeductions;
  final netTaxable = _n(form['netTaxableIncome']) != 0 ? _n(form['netTaxableIncome']) : netIncome;
  // C-corp franchise tax rate 8.84% (estimate); floor $800.
  final computedCorporate = (netTaxable * 0.0884).round();
  final minimum = _n(form['minimumFranchiseTax']) > 0
      ? _n(form['minimumFranchiseTax'])
      : caMinimumFranchiseTax;
  final corporateTax =
      _n(form['corporateTax']) > 0 ? _n(form['corporateTax']) : computedCorporate;
  final amt = _n(form['alternativeMinTax']);
  final totalTax = [corporateTax, amt, minimum].fold<num>(0, (a, b) => a > b ? a : b);
  // Prefer max of income tax vs minimum franchise tax + AMT add-on style estimate.
  final taxBeforePayments = corporateTax > minimum ? corporateTax + amt : minimum + amt;
  final estimated = _n(form['estimatedPayments']);
  final withholding = _n(form['withholdingPayments']);
  final totalPayments = estimated + withholding;
  final balance = taxBeforePayments - totalPayments;

  return {
    'grossProfit': grossProfit,
    'totalIncome': totalIncome,
    'totalDeductions': totalDeductions,
    'netIncome': netIncome,
    'netTaxableIncome': netTaxable,
    'corporateTax': corporateTax,
    'minimumFranchiseTax': minimum,
    'totalTax': taxBeforePayments,
    'totalPayments': totalPayments,
    'taxDue': balance > 0 ? balance : 0,
    'overpayment': balance < 0 ? -balance : 0,
    'suggestedTotalTax': totalTax,
  };
}

Map<String, num> summarizeCaForm100S(Map<String, dynamic> form) {
  final grossReceipts = _n(form['grossReceipts']);
  final returnsAllowances = _n(form['returnsAllowances']);
  final cogs = _n(form['costOfGoodsSold']);
  final grossProfit = grossReceipts - returnsAllowances - cogs;
  final otherIncome = _n(form['otherIncome']);
  final totalIncome = grossProfit + otherIncome;
  final totalDeductions = _n(form['totalDeductions']);
  final ordinary = totalIncome - totalDeductions;
  final minimum = _n(form['minimumFranchiseTax']) > 0
      ? _n(form['minimumFranchiseTax'])
      : caMinimumFranchiseTax;
  // S-corp 1.5% entity-level tax estimate on ordinary income.
  final scorpTax = (ordinary * 0.015).round();
  final builtIn = _n(form['builtInGainsTax']);
  final excess = _n(form['excessPassiveIncomeTax']);
  final lics = _n(form['lICSurcharge']);
  final incomeTax = scorpTax + builtIn + excess + lics;
  final totalTax = incomeTax > minimum ? incomeTax : minimum;
  final estimated = _n(form['estimatedPayments']);
  final withholding = _n(form['withholdingPayments']);
  final totalPayments = estimated + withholding;
  final balance = totalTax - totalPayments;

  return {
    'grossProfit': grossProfit,
    'totalIncome': totalIncome,
    'ordinaryIncome': ordinary,
    'minimumFranchiseTax': minimum,
    'totalTax': totalTax,
    'totalPayments': totalPayments,
    'taxDue': balance > 0 ? balance : 0,
    'overpayment': balance < 0 ? -balance : 0,
  };
}

Map<String, num> summarizeCaForm565(Map<String, dynamic> form) {
  final grossReceipts = _n(form['grossReceipts']);
  final returnsAllowances = _n(form['returnsAllowances']);
  final cogs = _n(form['costOfGoodsSold']);
  final grossProfit = grossReceipts - returnsAllowances - cogs;
  final incomeParts = [
    grossProfit,
    _n(form['ordinaryIncome']),
    _n(form['rentalIncome']),
    _n(form['interestIncome']),
    _n(form['dividendIncome']),
    _n(form['royaltyIncome']),
    _n(form['capitalGains']),
    _n(form['otherIncome']),
  ];
  final totalIncome = incomeParts.fold<num>(0, (a, b) => a + b);
  final deductionParts = [
    _n(form['salariesWages']),
    _n(form['guaranteedPayments']),
    _n(form['repairsExpense']),
    _n(form['badDebts']),
    _n(form['rentsExpense']),
    _n(form['taxesLicenses']),
    _n(form['interestExpense']),
    _n(form['depreciation']),
    _n(form['otherDeductions']),
  ];
  final totalDeductions = deductionParts.fold<num>(0, (a, b) => a + b);
  final ordinaryBusiness = totalIncome - totalDeductions;
  final annualTax =
      _n(form['annualTax']) > 0 ? _n(form['annualTax']) : caMinimumFranchiseTax;
  final llcFee = _n(form['llcFee']) > 0
      ? _n(form['llcFee'])
      : estimateLlcFee(totalIncome);
  final totalTax = annualTax + llcFee;
  final estimated = _n(form['estimatedPayments']);
  final totalPayments = estimated;
  final balance = totalTax - totalPayments;

  return {
    'grossProfit': grossProfit,
    'totalIncome': totalIncome,
    'totalDeductions': totalDeductions,
    'ordinaryBusinessIncome': ordinaryBusiness,
    'annualTax': annualTax,
    'llcFee': llcFee,
    'totalTax': totalTax,
    'totalPayments': totalPayments,
    'taxDue': balance > 0 ? balance : 0,
    'overpayment': balance < 0 ? -balance : 0,
  };
}

Map<String, num> summarizeCaForm541(Map<String, dynamic> form) {
  final incomeParts = [
    _n(form['interest']),
    _n(form['dividends']),
    _n(form['businessIncome']),
    _n(form['capitalGains']),
    _n(form['rents']),
    _n(form['farmIncome']),
    _n(form['ordinaryGains']),
    _n(form['otherIncome']),
  ];
  final totalIncome = incomeParts.fold<num>(0, (a, b) => a + b);
  final deductionParts = [
    _n(form['interestExpense']),
    _n(form['taxes']),
    _n(form['fiduciaryFees']),
    _n(form['charitableDeduction']),
    _n(form['attorneyFees']),
    _n(form['otherDeductions']),
  ];
  final totalDeductions = deductionParts.fold<num>(0, (a, b) => a + b);
  final dist = _n(form['incomeDistDeduction']);
  final exemption = _n(form['exemptionAmount']);
  final taxable = totalIncome - totalDeductions - dist - exemption;
  final taxableClamped = taxable < 0 ? 0 : taxable;
  final caTax = _n(form['caTax']);
  final amt = _n(form['amt']);
  final totalTax = caTax + amt;
  final estimated = _n(form['estimatedPayments']);
  final withholding = _n(form['withholdingPayments']);
  final totalPayments = estimated + withholding;
  final balance = totalTax - totalPayments;

  return {
    'totalIncome': totalIncome,
    'totalDeductions': totalDeductions,
    'taxableIncome': taxableClamped,
    'totalTax': totalTax,
    'totalPayments': totalPayments,
    'taxDue': balance > 0 ? balance : 0,
    'overpayment': balance < 0 ? -balance : 0,
  };
}

Map<String, num> summarizeCaForm199(Map<String, dynamic> form) {
  final ubiFederal = _n(form['ubiFederalAmount']);
  final additions = _n(form['ubiCAAdditions']);
  final subtractions = _n(form['ubiCASubtractions']);
  final ubiTaxable = ubiFederal + additions - subtractions;
  final ubiTax = _n(form['ubiTax']);
  final minimum = _n(form['minimumTax']);
  final registration = _n(form['annualRegistrationFee']);
  final totalTax = ubiTax + minimum + registration;
  final estimated = _n(form['estimatedPayments']);
  final balance = totalTax - estimated;

  return {
    'ubiTaxableIncome': ubiTaxable,
    'totalTax': totalTax,
    'totalPayments': estimated,
    'taxDue': balance > 0 ? balance : 0,
    'overpayment': balance < 0 ? -balance : 0,
  };
}

Map<String, num> summarizeCaScheduleR(Map<String, dynamic> form) {
  final totalSales = _n(form['totalSalesEverywhere']);
  final caSales = _n(form['caSales']);
  final totalProperty = _n(form['totalPropertyEverywhere']);
  final caProperty = _n(form['caProperty']);
  final totalPayroll = _n(form['totalPayrollEverywhere']);
  final caPayroll = _n(form['caPayroll']);

  final salesFactor = totalSales > 0 ? (caSales / totalSales) * 100 : 0;
  final propertyFactor = totalProperty > 0 ? (caProperty / totalProperty) * 100 : 0;
  final payrollFactor = totalPayroll > 0 ? (caPayroll / totalPayroll) * 100 : 0;
  // Single-sales-factor style estimate (modern CA) with fallback average.
  final apportionment = salesFactor > 0
      ? salesFactor
      : (propertyFactor + payrollFactor + salesFactor) / 3;
  final nonbusiness = _n(form['nonbusinessIncomeCA']);
  final businessIncome = _n(form['businessIncomeApportioned']);

  return {
    'salesFactor': double.parse(salesFactor.toStringAsFixed(4)),
    'propertyFactor': double.parse(propertyFactor.toStringAsFixed(4)),
    'payrollFactor': double.parse(payrollFactor.toStringAsFixed(4)),
    'apportionmentPercentage': double.parse(apportionment.toStringAsFixed(4)),
    'totalCAIncome': businessIncome + nonbusiness,
  };
}

/// Apply estimate rollup keys back onto a form map (write estimate totals).
Map<String, dynamic> applyEstimatePatch(
  Map<String, dynamic> form,
  Map<String, num> summary,
) {
  final next = Map<String, dynamic>.from(form);
  for (final e in summary.entries) {
    if (e.key == 'suggestedTotalTax') continue;
    next[e.key] = e.value;
  }
  return next;
}
