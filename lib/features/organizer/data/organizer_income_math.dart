/// Client-side Form 1040 income rollups from W-2 / 1099 schemas (TY2025).
/// Intake estimates for professional review — not a certified e-file engine.
/// Line map follows IRS Free File Fillable Forms line-by-line help:
/// https://www.irs.gov/e-file-providers/line-by-line-instructions-free-file-fillable-forms
library;

num incomeNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

List<Map<String, dynamic>> incomeList(Map<String, dynamic> data, String key) {
  final raw = data[key];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

num _sumField(List<Map<String, dynamic>> rows, String key) =>
    rows.fold<num>(0, (s, r) => s + incomeNum(r[key]));

num _sumFirst(List<Map<String, dynamic>> rows, List<String> keys) {
  return rows.fold<num>(0, (s, r) {
    for (final k in keys) {
      final v = incomeNum(r[k]);
      if (v != 0) return s + v;
    }
    // Prefer first key even when zero so empty rows don't double-count aliases.
    return s + incomeNum(r[keys.first]);
  });
}

/// W-2 Box 1 → Form 1040 Line 1a; Box 2 → Line 25a.
({num wages, num fedWithheld}) sumW2(List<Map<String, dynamic>> w2s) => (
      wages: _sumField(w2s, 'box1_wagesTips'),
      fedWithheld: _sumField(w2s, 'box2_fedTaxWithheld'),
    );

/// 1099-NEC Box 1 → Schedule C / business income (Sch. 1 line 3 path).
num sum1099Nec(List<Map<String, dynamic>> rows) =>
    _sumFirst(rows, const ['box1_nonemployeeComp', 'nonemployeeComp']);

/// 1099-INT Box 1 → Form 1040 Line 2b (via Schedule B).
num sum1099Int(List<Map<String, dynamic>> rows) =>
    _sumFirst(rows, const ['box1_interestIncome', 'interestIncome']);

/// 1099-DIV Box 1a → Line 3b; Box 1b → Line 3a.
({num ordinary, num qualified}) sum1099Div(List<Map<String, dynamic>> rows) => (
      ordinary: _sumFirst(rows, const ['box1a_ordinaryDividends', 'ordinaryDividends']),
      qualified: _sumFirst(rows, const ['box1b_qualifiedDividends', 'qualifiedDividends']),
    );

/// 1099-B / 1099-DA proceeds − basis → Form 1040 Line 7 / Schedule D.
num sumBrokerGainLoss(List<Map<String, dynamic>> rows) {
  return rows.fold<num>(0, (s, r) {
    final explicit = incomeNum(r['gainLoss']);
    if (explicit != 0) return s + explicit;
    return s + (incomeNum(r['proceeds']) - incomeNum(r['costBasis']));
  });
}

/// 1099-K Box 1a gross → business / marketplace income intake.
num sum1099K(List<Map<String, dynamic>> rows) =>
    _sumFirst(rows, const ['box1a_grossAmount', 'grossAmount']);

/// 1099-R: IRA/SEP/SIMPLE → Lines 4a/4b; else pensions → 5a/5b.
({num iraGross, num iraTaxable, num pensionGross, num pensionTaxable, num fedWithheld})
    sum1099R(List<Map<String, dynamic>> rows) {
  num iraGross = 0, iraTaxable = 0, pensionGross = 0, pensionTaxable = 0, fed = 0;
  for (final r in rows) {
    final gross = _sumFirst([r], const ['box1_grossDistribution', 'grossDistribution']);
    final taxableAmt = r['box2b_taxableAmountNotDetermined'] == true
        ? gross
        : (incomeNum(r['box2a_taxableAmount']) != 0
            ? incomeNum(r['box2a_taxableAmount'])
            : incomeNum(r['taxableAmount']));
    final isIra = r['box7_iraSepSimple'] == true ||
        '${r['box7_distributionCode'] ?? ''}'.toUpperCase().contains('IRA') ||
        r['isIra'] == true;
    fed += _sumFirst([r], const ['box4_fedTaxWithheld', 'fedTaxWithheld']);
    if (isIra) {
      iraGross += gross;
      iraTaxable += taxableAmt;
    } else {
      pensionGross += gross;
      pensionTaxable += taxableAmt;
    }
  }
  return (
    iraGross: iraGross,
    iraTaxable: iraTaxable,
    pensionGross: pensionGross,
    pensionTaxable: pensionTaxable,
    fedWithheld: fed,
  );
}

/// SSA-1099 Box 5 → Form 1040 Line 6a; simplified taxable → Line 6b.
({num gross, num taxable, num voluntaryWithheld}) sumSsa1099(
  List<Map<String, dynamic>> rows,
) {
  final gross = _sumFirst(rows, const ['box5_netBenefits', 'netBenefits', 'benefitsPaid']);
  final withheld = _sumFirst(rows, const ['box6_voluntaryTaxWithheld', 'voluntaryTaxWithheld']);
  // Intake default: keep prior taxable if set on rows; else 85% placeholder of Box 5.
  final taxable = rows.fold<num>(0, (s, r) {
    final t = incomeNum(r['taxableBenefits']);
    if (t > 0) return s + t;
    final g = _sumFirst([r], const ['box5_netBenefits', 'netBenefits', 'benefitsPaid']);
    return s + (g * 0.85);
  });
  return (gross: gross, taxable: taxable, voluntaryWithheld: withheld);
}

/// 1099-G: Box 1 unemployment → Sch. 1 line 7; Box 2 state refund → Sch. 1 line 1.
({num unemployment, num stateRefund, num fedWithheld}) sum1099G(
  List<Map<String, dynamic>> rows,
) =>
    (
      unemployment: _sumFirst(rows, const ['box1_unemployment', 'unemployment']),
      stateRefund: _sumFirst(rows, const ['box2_stateLocalRefund', 'stateLocalRefund']),
      fedWithheld: _sumFirst(rows, const ['box4_fedTaxWithheld', 'fedTaxWithheld']),
    );

num _sumFedWithholding1099(Map<String, dynamic> data) {
  num total = 0;
  for (final key in const [
    'form1099NEC',
    'form1099INT',
    'form1099DIV',
    'form1099B',
    'form1099K',
    'form1099DA',
    'form1099R',
    'form1099G',
    'formSSA1099',
  ]) {
    for (final r in incomeList(data, key)) {
      total += incomeNum(r['box4_fedTaxWithheld']);
      total += incomeNum(r['fedTaxWithheld']);
      total += incomeNum(r['box6_voluntaryTaxWithheld']);
      total += incomeNum(r['voluntaryTaxWithheld']);
    }
  }
  return total;
}

/// Compact Form 1040 income line summary for the Income step header.
class Form1040IncomeSummary {
  const Form1040IncomeSummary({
    required this.line1aWages,
    required this.line2bInterest,
    required this.line3aQualifiedDividends,
    required this.line3bOrdinaryDividends,
    required this.line4aIraGross,
    required this.line4bIraTaxable,
    required this.line5aPensionGross,
    required this.line5bPensionTaxable,
    required this.line6aSsGross,
    required this.line6bSsTaxable,
    required this.line7CapitalGain,
    required this.line8AdditionalIncome,
    required this.line25aW2Withheld,
    required this.line25b1099Withheld,
    required this.necCompensation,
    required this.unemployment,
    required this.stateTaxRefund,
  });

  final num line1aWages;
  final num line2bInterest;
  final num line3aQualifiedDividends;
  final num line3bOrdinaryDividends;
  final num line4aIraGross;
  final num line4bIraTaxable;
  final num line5aPensionGross;
  final num line5bPensionTaxable;
  final num line6aSsGross;
  final num line6bSsTaxable;
  final num line7CapitalGain;
  final num line8AdditionalIncome;
  final num line25aW2Withheld;
  final num line25b1099Withheld;
  final num necCompensation;
  final num unemployment;
  final num stateTaxRefund;
}

Form1040IncomeSummary summarizeForm1040Income(Map<String, dynamic> data) {
  final rolled = applyIncomeRollups(data);
  final s1 = Map<String, dynamic>.from((rolled['schedule1'] as Map?) ?? const {});
  return Form1040IncomeSummary(
    line1aWages: incomeNum(rolled['wages']),
    line2bInterest: incomeNum(rolled['interestIncome']),
    line3aQualifiedDividends: incomeNum(rolled['qualifiedDividends']),
    line3bOrdinaryDividends: incomeNum(rolled['dividendIncome']),
    line4aIraGross: incomeNum(rolled['iraDistributionsGross']),
    line4bIraTaxable: incomeNum(rolled['iraDistributions']),
    line5aPensionGross: incomeNum(rolled['pensionAnnuitiesGross']),
    line5bPensionTaxable: incomeNum(rolled['pensionAnnuities']),
    line6aSsGross: incomeNum(rolled['socialSecurityGross']),
    line6bSsTaxable: incomeNum(rolled['socialSecurityBenefits']),
    line7CapitalGain: incomeNum(rolled['capitalGains']),
    line8AdditionalIncome: incomeNum(s1['totalAdditionalIncome']) > 0
        ? incomeNum(s1['totalAdditionalIncome'])
        : incomeNum(rolled['otherIncome']) +
            incomeNum(rolled['unemploymentComp']) +
            incomeNum(rolled['stateTaxRefund']) +
            incomeNum(rolled['businessIncome']),
    line25aW2Withheld: incomeNum(rolled['taxWithheldW2']),
    line25b1099Withheld: incomeNum(rolled['taxWithheld1099']),
    necCompensation: incomeNum(rolled['necCompensation']),
    unemployment: incomeNum(rolled['unemploymentComp']),
    stateTaxRefund: incomeNum(rolled['stateTaxRefund']),
  );
}

/// Apply W-2 / 1099 list totals onto Form 1040 root scalars and Schedule 1.
Map<String, dynamic> applyIncomeRollups(Map<String, dynamic> data) {
  final next = Map<String, dynamic>.from(data);
  final schedule1 = Map<String, dynamic>.from((next['schedule1'] as Map?) ?? const {});

  final w2 = sumW2(incomeList(next, 'w2Forms'));
  final nec = sum1099Nec(incomeList(next, 'form1099NEC'));
  final kForms = sum1099K(incomeList(next, 'form1099K'));
  final ints = incomeList(next, 'form1099INT');
  final divs = incomeList(next, 'form1099DIV');
  final interestFrom1099 = sum1099Int(ints);
  final div = sum1099Div(divs);
  final r = sum1099R(incomeList(next, 'form1099R'));
  final ssa = sumSsa1099(incomeList(next, 'formSSA1099'));
  final g = sum1099G(incomeList(next, 'form1099G'));
  final brokerGain = sumBrokerGainLoss(incomeList(next, 'form1099B')) +
      sumBrokerGainLoss(incomeList(next, 'form1099DA'));

  // Schedule B payers still supported — prefer 1099 arrays when present.
  final scheduleB = Map<String, dynamic>.from((next['scheduleB'] as Map?) ?? const {});
  final interestPayers = [
    for (final e in (scheduleB['interestPayers'] as List?) ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];
  final dividendPayers = [
    for (final e in (scheduleB['dividendPayers'] as List?) ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];
  final interestFromSchB = interestPayers.fold<num>(0, (s, p) => s + incomeNum(p['amount']));
  final divFromSchB = dividendPayers.fold<num>(0, (s, p) => s + incomeNum(p['ordinaryDividends']));
  final qualFromSchB = dividendPayers.fold<num>(0, (s, p) => s + incomeNum(p['qualifiedDividends']));

  if (w2.wages > 0 || incomeList(next, 'w2Forms').isNotEmpty) {
    next['wages'] = w2.wages;
  }
  next['taxWithheldW2'] = w2.fedWithheld;

  if (ints.isNotEmpty) {
    next['interestIncome'] = interestFrom1099;
  } else if (interestPayers.isNotEmpty) {
    next['interestIncome'] = interestFromSchB;
  }

  if (divs.isNotEmpty) {
    next['dividendIncome'] = div.ordinary;
    next['qualifiedDividends'] = div.qualified;
  } else if (dividendPayers.isNotEmpty) {
    next['dividendIncome'] = divFromSchB;
    next['qualifiedDividends'] = qualFromSchB;
  }

  if (incomeList(next, 'form1099R').isNotEmpty) {
    next['iraDistributionsGross'] = r.iraGross;
    next['iraDistributions'] = r.iraTaxable;
    next['pensionAnnuitiesGross'] = r.pensionGross;
    next['pensionAnnuities'] = r.pensionTaxable;
  }

  if (incomeList(next, 'formSSA1099').isNotEmpty) {
    next['socialSecurityGross'] = ssa.gross;
    next['socialSecurityBenefits'] = ssa.taxable;
  }

  if (incomeList(next, 'form1099G').isNotEmpty) {
    next['unemploymentComp'] = g.unemployment;
    next['stateTaxRefund'] = g.stateRefund;
    schedule1['unemployment'] = g.unemployment;
    schedule1['stateTaxRefund'] = g.stateRefund;
  }

  if (incomeList(next, 'form1099NEC').isNotEmpty || incomeList(next, 'form1099K').isNotEmpty) {
    next['necCompensation'] = nec;
    next['form1099KGross'] = kForms;
    // Marketplace + NEC feed Schedule C / business income intake.
    next['businessIncome'] = nec + kForms;
  }

  if (incomeList(next, 'form1099B').isNotEmpty || incomeList(next, 'form1099DA').isNotEmpty) {
    next['capitalGains'] = brokerGain;
  }

  final withheld1099 = _sumFedWithholding1099(next);
  next['taxWithheld1099'] = withheld1099;
  next['taxWithheld'] = w2.fedWithheld + withheld1099;

  // Schedule 1 Part I additional income highlights → Form 1040 Line 8.
  schedule1['totalAdditionalIncome'] = incomeNum(schedule1['unemployment']) +
      incomeNum(schedule1['stateTaxRefund']) +
      incomeNum(schedule1['alimonyReceived']) +
      incomeNum(schedule1['otherIncome']) +
      incomeNum(next['businessIncome']);

  next['schedule1'] = schedule1;
  return next;
}
