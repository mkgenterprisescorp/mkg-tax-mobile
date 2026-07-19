/// Client-side Form 1040 credits & deductions rollups (TY2025 line map).
/// Intake estimates for professional review — not a certified e-file engine.
library;

num creditsNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

int creditsInt(dynamic v) => int.tryParse('$v') ?? (v is num ? v.toInt() : 0);

Map<String, dynamic> _map(Map<String, dynamic> data, String key) =>
    Map<String, dynamic>.from((data[key] as Map?) ?? const {});

/// Schedule A itemized total → Form 1040 Line 12e (when itemizing).
num scheduleATotal(Map<String, dynamic> scheduleA) {
  const keys = [
    'medicalExpenses',
    'stateLocalTaxes',
    'realEstateTaxes',
    'personalPropertyTaxes',
    'mortgageInterest',
    'mortgageInsurancePremiums',
    'charitableCash',
    'charitableNonCash',
    'casualtyLosses',
    'otherItemized',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(scheduleA[k]));
}

/// Form 5695 residential energy costs/credits sum → Form 1040 Line 20 via Sch. 3.
num form5695Total(Map<String, dynamic> form5695) {
  const keys = [
    'solarElectric',
    'solarWaterHeat',
    'fuelCell',
    'smallWindEnergy',
    'geothermalHeatPump',
    'batteryStorage',
    'evCharger',
    'insulationWindows',
    'energyEfficientHVAC',
    'waterHeater',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(form5695[k]));
}

/// Form 8863 education credit estimate (AOTC / LLC).
({num total, num refundableAotc, num nonrefundable}) form8863Estimate(
  Map<String, dynamic> form8863,
) {
  final tuition = creditsNum(form8863['tuitionPaid']);
  final scholarships = creditsNum(form8863['scholarships']);
  // Keep finite — Dio/jsonEncode throws on Infinity/NaN and breaks autosave.
  final net = (tuition - scholarships).clamp(0, 1e12);
  final type = '${form8863['creditType'] ?? 'american_opportunity'}';
  if (type == 'lifetime_learning' || type == 'llc') {
    final llc = (net * 0.20).clamp(0, 2000);
    return (total: llc, refundableAotc: 0, nonrefundable: llc);
  }
  // American Opportunity: up to $2,500; 40% of credit refundable (max $1,000).
  final aotc = net >= 4000
      ? 2500
      : net >= 2000
          ? 2000 + (net - 2000) * 0.25
          : net * 1.0;
  final capped = aotc.clamp(0, 2500);
  final refundable = (capped * 0.40).clamp(0, 1000);
  final nonrefundable = capped - refundable;
  return (total: capped, refundableAotc: refundable, nonrefundable: nonrefundable);
}

/// Schedule 1 Part II adjustments → Form 1040 Line 10.
num schedule1AdjustmentsTotal(Map<String, dynamic> schedule1) {
  const keys = [
    'educatorExpenses',
    'hsaDeduction',
    'selfEmploymentTax',
    'sepSimpleQualifiedPlans',
    'selfEmployedHealthInsurance',
    'studentLoanInterest',
    'iraDeduction',
    'movingExpenses',
    'alimonyPaid',
    'otherAdjustments',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(schedule1[k]));
}

/// Schedule 1-A additional deductions → Form 1040 Line 13b.
num schedule1ATotal(Map<String, dynamic> schedule1A) {
  const keys = ['tipIncome', 'overtimeDeduction', 'autoLoanInterest', 'otherDeductions'];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(schedule1A[k]));
}

/// Rough Schedule SE (short method): net * 92.35% * 15.3%.
({num netEarnings, num selfEmploymentTax, num deductiblePart}) scheduleSeEstimate({
  required num netProfitScheduleC,
  required num netProfitPartnership,
  required num farmIncome,
  required num churchEmployeeIncome,
  num maxSeEarnings = 176100,
}) {
  final total = netProfitScheduleC +
      netProfitPartnership +
      farmIncome +
      churchEmployeeIncome;
  if (total <= 0) {
    return (netEarnings: 0, selfEmploymentTax: 0, deductiblePart: 0);
  }
  final netEarnings = (total * 0.9235).clamp(0, maxSeEarnings);
  final seTax = (netEarnings * 0.153);
  final deductible = seTax / 2;
  return (
    netEarnings: _round2(netEarnings),
    selfEmploymentTax: _round2(seTax),
    deductiblePart: _round2(deductible),
  );
}

/// Schedule 8812 CTC / ODC / ACTC intake estimates → Lines 19 / 28.
({num childTaxCredit, num otherDependentsCredit, num additionalChildTaxCredit})
    schedule8812Estimate({
  required int qualifyingChildren,
  required int otherDependents,
  num childCreditPer = 2200,
  num otherDependentCreditPer = 500,
}) {
  final ctc = qualifyingChildren * childCreditPer;
  final odc = otherDependents * otherDependentCreditPer;
  // Simplified ACTC: up to $1,700 per qualifying child (TY2025-style ceiling).
  final actc = qualifyingChildren * 1700;
  return (
    childTaxCredit: ctc,
    otherDependentsCredit: odc,
    additionalChildTaxCredit: actc,
  );
}

/// Form 8995 QBI deduction (simplified 20%) → Form 1040 Line 13a.
num qbiDeductionEstimate(num qualifiedBusinessIncome) {
  if (qualifiedBusinessIncome <= 0) return 0;
  return _round2(qualifiedBusinessIncome * 0.20);
}

num schedule2AdditionalTaxesTotal(Map<String, dynamic> schedule2) {
  const keys = [
    'altMinimumTax',
    'excessPremiumTaxCreditRepayment',
    'selfEmploymentTax',
    'unreportedSSTax',
    'additionalTaxIRA',
    'householdEmploymentTax',
    'firstTimeHomebuyerRepayment',
    'netInvestmentIncomeTax',
    'additionalMedicareTax',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(schedule2[k]));
}

num schedule3NonrefundableTotal(Map<String, dynamic> schedule3) {
  const keys = [
    'foreignTaxCredit',
    'childDependentCareCredit',
    'educationCredits',
    'retirementSavingsCredit',
    'residentialEnergyCredit',
    'otherCredits',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(schedule3[k]));
}

num schedule3OtherPaymentsTotal(Map<String, dynamic> schedule3) {
  const keys = [
    'estimatedTaxPayments',
    'extensionPayment',
    'excessSocialSecurityWithheld',
    'otherPayments',
  ];
  return keys.fold<num>(0, (sum, k) => sum + creditsNum(schedule3[k]));
}

num _round2(num v) => (v * 100).round() / 100;

/// Apply rollup totals across nested credit/deduction schemas and root Form 1040 fields.
/// Returns a shallow-copied [data] with updated maps/scalars.
Map<String, dynamic> applyCreditsRollups(Map<String, dynamic> data) {
  final next = Map<String, dynamic>.from(data);

  var schedule1 = _map(next, 'schedule1');
  var schedule1A = _map(next, 'schedule1A');
  var scheduleA = _map(next, 'scheduleA');
  var schedule2 = _map(next, 'schedule2');
  var schedule3 = _map(next, 'schedule3');
  var scheduleSE = _map(next, 'scheduleSE');
  var schedule8812 = _map(next, 'schedule8812');
  var form5695 = _map(next, 'form5695');
  var form8863 = _map(next, 'form8863');
  var form8889 = _map(next, 'form8889');
  var form8995 = _map(next, 'form8995');
  var form8839 = _map(next, 'form8839');
  var form2441 = _map(next, 'form2441');

  // Prefer Form 8889 HSA deduction → Schedule 1 / Line 10.
  final hsa = creditsNum(form8889['hsaDeduction']) > 0
      ? creditsNum(form8889['hsaDeduction'])
      : creditsNum(schedule1['hsaDeduction']);
  if (hsa > 0) {
    schedule1['hsaDeduction'] = hsa;
    form8889['hsaDeduction'] = hsa;
  }

  // Sync common ATL root mirrors ↔ Schedule 1.
  void syncAtl(String rootKey, String sch1Key) {
    final rootVal = creditsNum(next[rootKey]);
    final schVal = creditsNum(schedule1[sch1Key]);
    final best = schVal > 0 ? schVal : rootVal;
    if (best > 0 || rootVal > 0 || schVal > 0) {
      schedule1[sch1Key] = best;
      next[rootKey] = best;
    }
  }

  syncAtl('educatorExpenses', 'educatorExpenses');
  syncAtl('studentLoanInterest', 'studentLoanInterest');
  syncAtl('iraDeduction', 'iraDeduction');
  syncAtl('movingExpenses', 'movingExpenses');
  syncAtl('alimonyPaid', 'alimonyPaid');

  // Schedule SE → Sch. 2 Line 4 / Sch. 1 deductible half / Form 1040 Line 23.
  final seInputC = creditsNum(scheduleSE['netProfitScheduleC']) > 0
      ? creditsNum(scheduleSE['netProfitScheduleC'])
      : creditsNum(next['businessIncome']);
  final se = scheduleSeEstimate(
    netProfitScheduleC: seInputC,
    netProfitPartnership: creditsNum(scheduleSE['netProfitPartnership']),
    farmIncome: creditsNum(scheduleSE['farmIncome']) > 0
        ? creditsNum(scheduleSE['farmIncome'])
        : creditsNum(next['farmIncome']),
    churchEmployeeIncome: creditsNum(scheduleSE['churchEmployeeIncome']),
    maxSeEarnings: creditsNum(scheduleSE['maxSEEarnings']) > 0
        ? creditsNum(scheduleSE['maxSEEarnings'])
        : 176100,
  );
  if (se.selfEmploymentTax > 0 || seInputC > 0) {
    scheduleSE['netProfitScheduleC'] = seInputC;
    scheduleSE['totalSEIncome'] = seInputC +
        creditsNum(scheduleSE['netProfitPartnership']) +
        creditsNum(scheduleSE['farmIncome']) +
        creditsNum(scheduleSE['churchEmployeeIncome']);
    scheduleSE['netEarnings'] = se.netEarnings;
    scheduleSE['selfEmploymentTax'] = se.selfEmploymentTax;
    scheduleSE['deductiblePart'] = se.deductiblePart;
    schedule2['selfEmploymentTax'] = se.selfEmploymentTax;
    schedule1['selfEmploymentTax'] = se.deductiblePart;
    next['selfEmploymentTax'] = se.deductiblePart;
  }

  schedule1['totalAdjustments'] = schedule1AdjustmentsTotal(schedule1);
  schedule1A['totalAdditionalDeductions'] = schedule1ATotal(schedule1A);

  // Schedule A → Line 12e.
  final aTotal = scheduleATotal(scheduleA);
  scheduleA['totalItemized'] = aTotal;
  if (next['itemizeDeductions'] == true) {
    next['itemizedDeductions'] = aTotal;
    next['medicalExpenses'] = creditsNum(scheduleA['medicalExpenses']);
    next['stateLocalTaxes'] = creditsNum(scheduleA['stateLocalTaxes']) +
        creditsNum(scheduleA['realEstateTaxes']) +
        creditsNum(scheduleA['personalPropertyTaxes']);
    next['mortgageInterest'] = creditsNum(scheduleA['mortgageInterest']);
    next['charitableContributions'] = creditsNum(scheduleA['charitableCash']) +
        creditsNum(scheduleA['charitableNonCash']);
    next['propertyTaxes'] = creditsNum(scheduleA['realEstateTaxes']);
  }

  // Form 5695 → residential energy (Sch. 3 / Line 20).
  final energy = form5695Total(form5695);
  form5695['totalCredit'] = energy;
  if (energy > 0) {
    next['residentialEnergyCredit'] = energy;
    schedule3['residentialEnergyCredit'] = energy;
  }

  // Form 8863 → education credits (Sch. 3 Line 3 / Line 29 refundable AOTC).
  final edu = form8863Estimate(form8863);
  form8863['americanOpportunityCredit'] = edu.total;
  form8863['refundableAotc'] = edu.refundableAotc;
  form8863['nonrefundableCredit'] = edu.nonrefundable;
  if (edu.total > 0 || creditsNum(form8863['tuitionPaid']) > 0) {
    next['educationCredits'] = edu.total;
    schedule3['educationCredits'] = edu.nonrefundable;
  }

  // Form 2441 dependent care → Sch. 3.
  final careExpenses = creditsNum(form2441['qualifiedExpenses']) > 0
      ? creditsNum(form2441['qualifiedExpenses'])
      : creditsNum(next['dependentCareExpenses']);
  if (careExpenses > 0) {
    form2441['qualifiedExpenses'] = careExpenses;
    next['dependentCareExpenses'] = careExpenses;
    final careCredit = creditsNum(form2441['creditAmount']) > 0
        ? creditsNum(form2441['creditAmount'])
        : (careExpenses * 0.20).clamp(0, 1050);
    form2441['creditAmount'] = careCredit;
    schedule3['childDependentCareCredit'] = careCredit;
  }

  // Schedule 8812 → Lines 19 / 28.
  final kids = creditsInt(schedule8812['qualifyingChildren']) > 0
      ? creditsInt(schedule8812['qualifyingChildren'])
      : creditsInt(next['childTaxCreditChildren']);
  final otherDeps = creditsInt(schedule8812['otherDependents']) > 0
      ? creditsInt(schedule8812['otherDependents'])
      : creditsInt(next['otherDependentsCreditCount']);
  final s8812 = schedule8812Estimate(
    qualifyingChildren: kids,
    otherDependents: otherDeps,
  );
  schedule8812['qualifyingChildren'] = kids;
  schedule8812['otherDependents'] = otherDeps;
  schedule8812['childTaxCredit'] = s8812.childTaxCredit;
  schedule8812['otherDependentsCredit'] = s8812.otherDependentsCredit;
  schedule8812['additionalChildTaxCredit'] = s8812.additionalChildTaxCredit;
  schedule8812['totalCreditLine19'] =
      s8812.childTaxCredit + s8812.otherDependentsCredit;
  next['childTaxCreditChildren'] = kids;
  next['otherDependentsCreditCount'] = otherDeps;
  next['childTaxCredit'] = s8812.childTaxCredit;
  next['additionalChildTaxCredit'] = s8812.additionalChildTaxCredit;
  next['otherDependentsCredit'] = s8812.otherDependentsCredit;

  // Form 8995 QBI → Line 13a.
  final qbiIncome = creditsNum(form8995['qualifiedBusinessIncome']) > 0
      ? creditsNum(form8995['qualifiedBusinessIncome'])
      : creditsNum(next['businessIncome']);
  final qbiDed = creditsNum(form8995['qbiDeduction']) > 0
      ? creditsNum(form8995['qbiDeduction'])
      : qbiDeductionEstimate(qbiIncome);
  form8995['qualifiedBusinessIncome'] = qbiIncome;
  form8995['qbiDeduction'] = qbiDed;
  next['qbiDeduction'] = qbiDed;

  // Form 8839 adoption → Line 30.
  final adoption = creditsNum(form8839['refundableAdoptionCredit']) > 0
      ? creditsNum(form8839['refundableAdoptionCredit'])
      : creditsNum(form8839['adoptionCredit']);
  if (adoption > 0 || creditsNum(form8839['qualifiedAdoptionExpenses']) > 0) {
    form8839['adoptionCredit'] = adoption > 0
        ? adoption
        : creditsNum(form8839['qualifiedAdoptionExpenses']);
    form8839['refundableAdoptionCredit'] = form8839['adoptionCredit'];
    next['adoptionCredit'] = form8839['adoptionCredit'];
  }

  // Schedule 2 / 3 rollup lines (Form 1040 Lines 17/23 and 20/31).
  schedule2['totalAdditionalTaxes'] = schedule2AdditionalTaxesTotal(schedule2);
  schedule3['totalNonrefundableCredits'] = schedule3NonrefundableTotal(schedule3);
  schedule3['totalOtherPayments'] = schedule3OtherPaymentsTotal(schedule3);

  next['schedule1'] = schedule1;
  next['schedule1A'] = schedule1A;
  next['scheduleA'] = scheduleA;
  next['schedule2'] = schedule2;
  next['schedule3'] = schedule3;
  next['scheduleSE'] = scheduleSE;
  next['schedule8812'] = schedule8812;
  next['form5695'] = form5695;
  next['form8863'] = form8863;
  next['form8889'] = form8889;
  next['form8995'] = form8995;
  next['form8839'] = form8839;
  next['form2441'] = form2441;

  return next;
}

/// Compact Form 1040 line summary for the Credits & Deductions step header.
class Form1040CreditsSummary {
  const Form1040CreditsSummary({
    required this.line10Adjustments,
    required this.line12eItemized,
    required this.line13aQbi,
    required this.line13bSchedule1A,
    required this.line19CtcOdc,
    required this.line20Schedule3,
    required this.line23OtherTaxes,
    required this.line27aEicClaimed,
    required this.line28Actc,
    required this.line29Aotc,
    required this.line30Adoption,
  });

  final num line10Adjustments;
  final num line12eItemized;
  final num line13aQbi;
  final num line13bSchedule1A;
  final num line19CtcOdc;
  final num line20Schedule3;
  final num line23OtherTaxes;
  final bool line27aEicClaimed;
  final num line28Actc;
  final num line29Aotc;
  final num line30Adoption;
}

Form1040CreditsSummary summarizeForm1040Credits(Map<String, dynamic> data) {
  final rolled = applyCreditsRollups(data);
  final s1 = _map(rolled, 'schedule1');
  final s1a = _map(rolled, 'schedule1A');
  final sA = _map(rolled, 'scheduleA');
  final s2 = _map(rolled, 'schedule2');
  final s3 = _map(rolled, 'schedule3');
  final s8812 = _map(rolled, 'schedule8812');
  final f8863 = _map(rolled, 'form8863');
  return Form1040CreditsSummary(
    line10Adjustments: creditsNum(s1['totalAdjustments']),
    line12eItemized: rolled['itemizeDeductions'] == true ? creditsNum(sA['totalItemized']) : 0,
    line13aQbi: creditsNum(rolled['qbiDeduction']),
    line13bSchedule1A: creditsNum(s1a['totalAdditionalDeductions']),
    line19CtcOdc: creditsNum(s8812['totalCreditLine19']),
    line20Schedule3: creditsNum(s3['totalNonrefundableCredits']),
    line23OtherTaxes: creditsNum(s2['totalAdditionalTaxes']),
    line27aEicClaimed: rolled['hasEIC'] == true,
    line28Actc: creditsNum(s8812['additionalChildTaxCredit']),
    line29Aotc: creditsNum(f8863['refundableAotc']),
    line30Adoption: creditsNum(rolled['adoptionCredit']),
  );
}
