import 'computed_field_policy.dart';
import 'organizer_credits_math.dart';
import 'organizer_income_math.dart';

/// Workflow estimate of Form 1040 Line 11 (AGI) from organizer income + adjustments.
///
/// Line 9 total income ≈ wages + interest + dividends + IRA/pension taxable +
/// SS taxable + capital gains + Sch.1 additional income.
/// Line 11 AGI ≈ Line 9 − Sch.1 adjustments (Line 10).
num estimateFederalAgi(Map<String, dynamic> organizer) {
  final rolled = applyIncomeRollups(Map<String, dynamic>.from(organizer));
  final credits = applyCreditsRollups(rolled);
  final s1 = Map<String, dynamic>.from((credits['schedule1'] as Map?) ?? const {});

  final line9 = incomeNum(credits['wages']) +
      incomeNum(credits['interestIncome']) +
      incomeNum(credits['dividendIncome']) +
      incomeNum(credits['iraDistributions']) +
      incomeNum(credits['pensionAnnuities']) +
      incomeNum(credits['socialSecurityBenefits']) +
      incomeNum(credits['capitalGains']) +
      incomeNum(s1['totalAdditionalIncome']).clamp(0, double.infinity);

  final adjustments = incomeNum(s1['totalAdjustments']);
  final agi = line9 - adjustments;
  return agi < 0 ? 0 : (agi * 100).round() / 100;
}

/// Sync computed federal AGI into root + `ca540` unless overridden.
Map<String, dynamic> syncFederalAgi(Map<String, dynamic> organizer) {
  final next = Map<String, dynamic>.from(organizer);
  final agi = estimateFederalAgi(next);
  ComputedFieldPolicy.assignUnlessOverridden(next, 'federalAGI', agi);

  final ca = Map<String, dynamic>.from((next['ca540'] as Map?) ?? const {});
  final caOverridesParent = {
    'computedOverrides': {
      ...ComputedFieldPolicy.overridesOf(next),
      ...ComputedFieldPolicy.overridesOf(ca),
    },
  };
  if (!ComputedFieldPolicy.isOverridden(caOverridesParent, 'federalAGI') &&
      !ComputedFieldPolicy.isOverridden(ca, 'federalAGI')) {
    ca['federalAGI'] = agi;
  }

  // CA withholding from W-2 Box 17 when blank / not overridden.
  if (!ComputedFieldPolicy.isOverridden(ca, 'caWithholding') &&
      incomeNum(ca['caWithholding']) <= 0) {
    num caWh = 0;
    num caWages = 0;
    for (final w2 in incomeList(next, 'w2Forms')) {
      final state = '${w2['box15_state'] ?? ''}'.toUpperCase();
      if (state.isEmpty || state == 'CA') {
        caWh += incomeNum(w2['box17_stateTax']);
        caWages += incomeNum(w2['box16_stateWages']);
      }
    }
    if (caWh > 0) ca['caWithholding'] = caWh;
    if (incomeNum(ca['stateWages']) <= 0 && caWages > 0) {
      ca['stateWages'] = caWages;
    }
  }

  next['ca540'] = ca;
  return next;
}
