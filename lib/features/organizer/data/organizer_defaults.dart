import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Personal / Schedule C walkthrough — 1040 + federal schedules + CA 540.
const personalOrganizerSteps = <String>[
  'Filing Info',
  'Personal Info',
  'Income (1040)',
  'Schedule B',
  'Schedule C',
  'Schedule D',
  'Schedule E',
  'Schedule F',
  'Credits & Deductions',
  'Form 1040-X',
  'State Tax Returns',
  'Direct Deposit',
  'Review & Sign',
];

/// Icon + short cue for each walkthrough section (hub tiles).
IconData iconForOrganizerStep(String step) {
  if (step == 'Filing Info') return Icons.flag_outlined;
  if (step == 'Personal Info') return Icons.person_outline;
  if (step == 'Income (1040)') return Icons.payments_outlined;
  if (step == 'Schedule B') return Icons.account_balance_wallet_outlined;
  if (step == 'Schedule C') return Icons.storefront_outlined;
  if (step == 'Schedule D') return Icons.show_chart_outlined;
  if (step == 'Schedule E') return Icons.home_work_outlined;
  if (step == 'Schedule F') return Icons.agriculture_outlined;
  if (step == 'Credits & Deductions') return Icons.savings_outlined;
  if (step == 'Form 1040-X') return Icons.edit_note;
  if (step == 'State Tax Returns' || step == 'CA 540 State Tax') return Icons.map_outlined;
  if (step == 'Direct Deposit') return Icons.account_balance_outlined;
  if (step == 'Review & Sign') return Icons.draw_outlined;
  if (step.contains('1120-S') || step.contains('1120')) return Icons.apartment_outlined;
  if (step.contains('1065')) return Icons.groups_outlined;
  if (step.contains('1041')) return Icons.account_balance_outlined;
  if (step.contains('990')) return Icons.volunteer_activism_outlined;
  return Icons.description_outlined;
}

String cueForOrganizerStep(String step) {
  if (step == 'Filing Info') {
    return 'Personal, Schedule C, 1120 / 1120-S, or other entity filing';
  }
  if (step == 'Personal Info') return 'Name, SSN, address, dependents';
  if (step == 'Income (1040)') {
    return 'Form 1040 Lines 1–8 / 25: W-2, 1099-NEC/R/DA/G, SSA-1099, INT/DIV/B/K';
  }
  if (step == 'Schedule B') return 'Interest and dividend payers';
  if (step == 'Schedule C') return 'Sole prop / gig profit & loss';
  if (step == 'Schedule D') return 'Capital gains and transactions';
  if (step == 'Schedule E') return 'Rental and royalty properties';
  if (step == 'Schedule F') return 'Farm income and expenses';
  if (step == 'Credits & Deductions') {
    return 'Form 1040 Lines 10–31: Sch. 1/A/SE/8812/2/3, Forms 8889/8863/5695/8995/8839';
  }
  if (step == 'Form 1040-X') return 'Amended federal return (IRS Form 1040-X)';
  if (step == 'State Tax Returns' || step == 'CA 540 State Tax') {
    return 'Nationwide personal + business state forms + California 540 suite';
  }
  if (step == 'Direct Deposit') return 'Bank routing & account';
  if (step == 'Review & Sign') return 'Consent and submit';
  if (step.startsWith('Form ')) return 'Entity return details';
  return 'Complete this section';
}

/// Lightweight completion heuristics for hub checkmarks.
bool isOrganizerStepComplete(String step, Map<String, dynamic> data) {
  String root(String k) => '${data[k] ?? ''}'.trim();
  String nested(Map<String, dynamic> map, String k) => '${map[k] ?? ''}'.trim();
  num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  Map<String, dynamic> m(String k) => Map<String, dynamic>.from((data[k] as Map?) ?? {});

  if (step == 'Filing Info') {
    return root('prepType').isNotEmpty && root('filingStatus').isNotEmpty;
  }
  if (step == 'Personal Info') {
    return root('firstName').isNotEmpty && root('lastName').isNotEmpty;
  }
  if (step == 'Income (1040)') {
    final w2s = (data['w2Forms'] as List?) ?? const [];
    final hasW2 = w2s.any((e) {
      if (e is! Map) return false;
      return n(e['box1_wagesTips']) > 0 || '${e['employerName'] ?? ''}'.trim().isNotEmpty;
    });
    bool hasForms(String key) {
      final list = (data[key] as List?) ?? const [];
      return list.any((e) => e is Map && e.values.any((v) => v is num ? v != 0 : '$v'.trim().isNotEmpty));
    }
    return n(data['wages']) > 0 ||
        hasW2 ||
        hasForms('form1099NEC') ||
        hasForms('form1099R') ||
        hasForms('form1099DA') ||
        hasForms('formSSA1099') ||
        hasForms('form1099G') ||
        hasForms('form1099INT') ||
        hasForms('form1099DIV') ||
        n(data['unemploymentComp']) > 0 ||
        n(data['socialSecurityBenefits']) > 0 ||
        n(data['otherIncome']) > 0;
  }
  if (step == 'Schedule B') {
    final sb = m('scheduleB');
    final interest = (sb['interestPayers'] as List?) ?? const [];
    final dividends = (sb['dividendPayers'] as List?) ?? const [];
    return interest.isNotEmpty ||
        dividends.isNotEmpty ||
        n(data['interestIncome']) > 0 ||
        n(data['dividendIncome']) > 0;
  }
  if (step == 'Schedule C') {
    final sc = m('scheduleC');
    return nested(sc, 'businessName').isNotEmpty || n(sc['grossReceipts']) > 0;
  }
  if (step == 'Schedule D') {
    final sd = m('scheduleD');
    final txs = (sd['transactions'] as List?) ?? const [];
    return n(sd['shortTermGains']) != 0 ||
        n(sd['longTermGains']) != 0 ||
        n(data['capitalGains']) != 0 ||
        txs.isNotEmpty;
  }
  if (step == 'Schedule E') {
    final rentals = (m('scheduleE')['rentalProperties'] as List?) ?? const [];
    return rentals.isNotEmpty || n(data['rentalIncome']) > 0;
  }
  if (step == 'Schedule F') {
    final sf = m('scheduleF');
    return nested(sf, 'farmName').isNotEmpty ||
        n(sf['grossFarmIncome']) > 0 ||
        n(data['farmIncome']) > 0;
  }
  if (step == 'Credits & Deductions') {
    final f8863 = m('form8863');
    final f5695 = m('form5695');
    final s1 = m('schedule1');
    final s8812 = m('schedule8812');
    final f8995 = m('form8995');
    return data['itemizeDeductions'] == true ||
        data['hasEIC'] == true ||
        n(data['educatorExpenses']) > 0 ||
        n(s1['educatorExpenses']) > 0 ||
        n(s1['hsaDeduction']) > 0 ||
        n(data['studentLoanInterest']) > 0 ||
        n(data['iraDeduction']) > 0 ||
        n(data['educationCredits']) > 0 ||
        n(data['childTaxCreditChildren']) > 0 ||
        n(s8812['qualifyingChildren']) > 0 ||
        n(data['residentialEnergyCredit']) > 0 ||
        n(data['dependentCareExpenses']) > 0 ||
        n(data['qbiDeduction']) > 0 ||
        n(f8995['qbiDeduction']) > 0 ||
        n(data['adoptionCredit']) > 0 ||
        nested(f8863, 'studentName').isNotEmpty ||
        n(f5695['solarElectric']) > 0 ||
        n(m('form8889')['hsaDeduction']) > 0 ||
        n(m('form8962')['premiumTaxCreditAllowed']) > 0;
  }
  if (step == 'Form 1040-X') {
    final x = m('form1040x');
    return x['isAmended'] == true &&
        (nested(x, 'explanation').isNotEmpty || nested(x, 'amendedReason').isNotEmpty);
  }
  if (step == 'State Tax Returns' || step == 'CA 540 State Tax') {
    final ca = m('ca540');
    final extra = (data['additionalStateReturns'] as List?) ?? const [];
    return extra.isNotEmpty ||
        (ca.isNotEmpty &&
            (n(ca['stateWages']) > 0 ||
                n(ca['caWithholding']) > 0 ||
                nested(ca, 'residencyStatus').isNotEmpty)) ||
        nested(m('scheduleCA'), 'wagesSubtraction').isNotEmpty ||
        n(m('ftb3514')['calEITCAmount']) > 0;
  }
  if (step == 'Direct Deposit') {
    return root('routingNumber').isNotEmpty && root('accountNumber').isNotEmpty;
  }
  if (step == 'Review & Sign') {
    return data['consentPerjury'] == true &&
        data['consentToEFile'] == true &&
        (root('typedSignature').isNotEmpty || root('printedName').isNotEmpty);
  }
  for (final prep in businessEntityTypes) {
    if (step == (businessFormLabels[prep] ?? '')) {
      final form = m(prep);
      final name =
          '${form['corporationName'] ?? form['partnershipName'] ?? form['organizationName'] ?? form['entityName'] ?? form['fiduciaryName'] ?? form['trustName'] ?? ''}'
              .trim();
      return name.isNotEmpty;
    }
  }
  return false;
}

const businessEntityTypes = <String>[
  'form1041',
  'form1065',
  'form1120S',
  'form1120',
  'form990',
  'form990EZ',
];

const businessFormLabels = <String, String>{
  'form1041': 'Form 1041 - Trust / Estate',
  'form1065': 'Form 1065 - Partnership / LLC',
  'form1120S': 'Form 1120-S - S-Corporation',
  'form1120': 'Form 1120 - C-Corporation',
  'form990': 'Form 990 - Nonprofit',
  'form990EZ': 'Form 990-EZ - Nonprofit',
};

const prepTypeOptions = <(String, String)>[
  ('personal', 'Personal Tax Prep (1040)'),
  ('business', 'Business Tax Prep (Schedule C)'),
  ('form1041', 'Trust / Estate (Form 1041)'),
  ('form1065', 'Partnership / LLC (Form 1065)'),
  ('form1120S', 'S-Corporation (Form 1120-S)'),
  ('form1120', 'C-Corporation (Form 1120)'),
  ('form990', 'Nonprofit Organization (Form 990)'),
  ('form990EZ', 'Nonprofit Organization (Form 990-EZ)'),
];

const filingStatusOptions = <(String, String)>[
  ('single', 'Single'),
  ('married_joint', 'Married Filing Jointly'),
  ('married_separate', 'Married Filing Separately'),
  ('head_household', 'Head of Household'),
  ('qualifying_widow', 'Qualifying Surviving Spouse'),
];

/// Last [count] filing years ending at [currentYear] (inclusive), newest first.
/// Defaults to the prior calendar year as the current filing season (e.g. 2025).
List<(int, String)> filingYearOptions({int? currentYear, int count = 10}) {
  final current = currentYear ?? DateTime.now().year - 1;
  return [
    for (var y = current; y > current - count; y--)
      (y, y == current ? '$y — Current Filing Season' : '$y'),
  ];
}

/// Empty Schedule E rental property matching Organizer inline schema.
Map<String, dynamic> emptyRentalProperty() => {
      'address': '',
      'rentReceived': 0,
      'advertising': 0,
      'insurance': 0,
      'repairs': 0,
      'taxes': 0,
      'utilities': 0,
      'depreciation': 0,
      'mortgage': 0,
      'otherExpenses': 0,
    };

Map<String, dynamic> emptyInterestPayer() => {
      'payerName': '',
      'amount': 0,
      'taxExempt': false,
    };

Map<String, dynamic> emptyDividendPayer() => {
      'payerName': '',
      'ordinaryDividends': 0,
      'qualifiedDividends': 0,
    };

Map<String, dynamic> emptyCapitalTransaction() => {
      'description': '',
      'dateAcquired': '',
      'dateSold': '',
      'proceeds': 0,
      'costBasis': 0,
      'gainOrLoss': 0,
      'term': 'long',
    };

/// Web Organizer dependent row: `{ name, ssn, ssnType, relationship, dob }`.
Map<String, dynamic> emptyDependent() => {
      'name': '',
      'ssn': '',
      'ssnType': 'ssn',
      'relationship': '',
      'dob': '',
    };

/// Full W-2 form matching mkgtaxconsultants.com `defaultW2Data` / Form W-2 boxes.
Map<String, dynamic> emptyW2Form({
  String employeeSSN = '',
  String employeeFirstName = '',
  String employeeLastName = '',
  String employeeAddress = '',
  String employeeCity = '',
  String employeeState = '',
  String employeeZip = '',
}) =>
    {
      'employeeSSN': employeeSSN,
      'employerEIN': '',
      'employerName': '',
      'employerAddress': '',
      'employerCity': '',
      'employerState': '',
      'employerZip': '',
      'controlNumber': '',
      'employeeFirstName': employeeFirstName,
      'employeeMiddleInitial': '',
      'employeeLastName': employeeLastName,
      'employeeSuffix': '',
      'employeeAddress': employeeAddress,
      'employeeCity': employeeCity,
      'employeeState': employeeState,
      'employeeZip': employeeZip,
      'box1_wagesTips': 0,
      'box2_fedTaxWithheld': 0,
      'box3_ssWages': 0,
      'box4_ssTaxWithheld': 0,
      'box5_medicareWages': 0,
      'box6_medicareTaxWithheld': 0,
      'box7_ssTips': 0,
      'box8_allocatedTips': 0,
      'box9_blank': '',
      'box10_dependentCareBenefits': 0,
      'box11_nonqualifiedPlans': 0,
      'box12a_code': '',
      'box12a_amount': 0,
      'box12b_code': '',
      'box12b_amount': 0,
      'box12c_code': '',
      'box12c_amount': 0,
      'box12d_code': '',
      'box12d_amount': 0,
      'box13_statutory': false,
      'box13_retirementPlan': false,
      'box13_thirdPartySickPay': false,
      'box14_other': '',
      'box14b_tippedOccupationCode': '',
      'box15_state': '',
      'box15_stateId': '',
      'box16_stateWages': 0,
      'box17_stateTax': 0,
      'box18_localWages': 0,
      'box19_localTax': 0,
      'box20_localityName': '',
      'regularPay': 0,
      'overtimePay': 0,
    };

/// Form 1099-NEC — Box 1 → Schedule C / Form 1040 Line 8 path.
Map<String, dynamic> emptyForm1099Nec() => {
      'payerName': '',
      'payerTIN': '',
      'payerAddress': '',
      'payerCity': '',
      'payerState': '',
      'payerZip': '',
      'accountNumber': '',
      'box1_nonemployeeComp': 0,
      'box2_directSales5000': false,
      'box4_fedTaxWithheld': 0,
      'box5_stateTaxWithheld': 0,
      'box6_stateIncome': 0,
      'box7_state': '',
    };

/// Form 1099-R — Boxes 1/2a → Form 1040 Lines 4a–5b.
Map<String, dynamic> emptyForm1099R() => {
      'payerName': '',
      'payerTIN': '',
      'payerAddress': '',
      'payerCity': '',
      'payerState': '',
      'payerZip': '',
      'accountNumber': '',
      'recipientTIN': '',
      'box1_grossDistribution': 0,
      'box2a_taxableAmount': 0,
      'box2b_taxableAmountNotDetermined': false,
      'box2b_totalDistribution': false,
      'box3_capitalGain': 0,
      'box4_fedTaxWithheld': 0,
      'box5_employeeContributions': 0,
      'box6_unrealizedNetApprec': 0,
      'box7_distributionCode': '',
      'box7_iraSepSimple': false,
      'box8_other': 0,
      'box9a_percentTotalDist': 0,
      'box10_amountAllocableIRR': 0,
      'box14_stateTaxWithheld': 0,
      'box15_state': '',
      'box16_stateDistribution': 0,
    };

/// Form 1099-DA — digital asset proceeds → Form 1040 Line 7 / Schedule D.
Map<String, dynamic> emptyForm1099Da() => {
      'exchangeName': '',
      'payerTIN': '',
      'accountNumber': '',
      'digitalAssetName': '',
      'quantity': 0,
      'dateAcquired': '',
      'dateSold': '',
      'proceeds': 0,
      'costBasis': 0,
      'gainLoss': 0,
      'box4_fedTaxWithheld': 0,
      'proceedsType': 'cash',
    };

/// SSA-1099 — Box 5 → Form 1040 Line 6a; taxable estimate → Line 6b.
Map<String, dynamic> emptyFormSsa1099() => {
      'beneficiaryName': '',
      'claimNumber': '',
      'box3_benefitsPaid': 0,
      'box4_benefitsRepaid': 0,
      'box5_netBenefits': 0,
      'box6_voluntaryTaxWithheld': 0,
      'taxableBenefits': 0,
      'medicarePartB': 0,
      'medicarePrescriptionDrug': 0,
    };

/// Form 1099-G — Box 1 unemployment (Sch. 1); Box 2 state refund (Sch. 1).
Map<String, dynamic> emptyForm1099G() => {
      'payerName': '',
      'payerTIN': '',
      'box1_unemployment': 0,
      'box2_stateLocalRefund': 0,
      'box3_box2TaxYear': '',
      'box4_fedTaxWithheld': 0,
      'box5_rttaPayments': 0,
      'box6_taxableGrants': 0,
      'box7_agriculturePayments': 0,
      'box10a_state': '',
      'box10b_stateId': '',
      'box11_stateIncome': 0,
    };

Map<String, dynamic> emptyForm1099Int() => {
      'payerName': '',
      'payerTIN': '',
      'box1_interestIncome': 0,
      'box2_earlyWithdrawalPenalty': 0,
      'box3_usBondInterest': 0,
      'box4_fedTaxWithheld': 0,
      'box8_taxExemptInterest': 0,
      'box17_state': '',
    };

Map<String, dynamic> emptyForm1099Div() => {
      'payerName': '',
      'payerTIN': '',
      'box1a_ordinaryDividends': 0,
      'box1b_qualifiedDividends': 0,
      'box2a_capitalGainDist': 0,
      'box4_fedTaxWithheld': 0,
      'box5_section199A': 0,
      'box12_exemptInterestDividends': 0,
    };

Map<String, dynamic> emptyForm1099B() => {
      'brokerageName': '',
      'payerTIN': '',
      'description': '',
      'dateAcquired': '',
      'dateSold': '',
      'proceeds': 0,
      'costBasis': 0,
      'gainLoss': 0,
      'shortOrLong': 'long',
      'box4_fedTaxWithheld': 0,
      'washSaleLossDisallowed': 0,
      'reportedToIrs': true,
    };

Map<String, dynamic> emptyForm1099K() => {
      'payerName': '',
      'payerTIN': '',
      'box1a_grossAmount': 0,
      'box1b_cardNotPresent': 0,
      'box2_merchantCategory': '',
      'box3_numberOfTransactions': 0,
      'box4_fedTaxWithheld': 0,
      'box5_state': '',
      'box6_stateId': '',
      'box7_stateIncome': 0,
    };

const dependentRelationshipOptions = <(String, String)>[
  ('son', 'Son'),
  ('daughter', 'Daughter'),
  ('stepson', 'Stepson'),
  ('stepdaughter', 'Stepdaughter'),
  ('foster_child', 'Foster child'),
  ('brother', 'Brother'),
  ('sister', 'Sister'),
  ('parent', 'Parent'),
  ('grandchild', 'Grandchild'),
  ('other', 'Other qualifying relative'),
];

List<String> stepsForPrepType(String prepType) {
  if (businessEntityTypes.contains(prepType)) {
    return [
      'Filing Info',
      businessFormLabels[prepType] ?? 'Entity Form',
      'State Tax Returns',
      'Direct Deposit',
      'Review & Sign',
    ];
  }
  return List<String>.from(personalOrganizerSteps);
}

bool showScheduleCStep(Map<String, dynamic> data) {
  final prep = '${data['prepType'] ?? 'personal'}';
  if (prep == 'business') return true;
  if (data['includeScheduleC'] == true) return true;
  final businessIncome = _asNum(data['businessIncome']);
  return businessIncome > 0;
}

/// Short labels for the Filing Info "Business Tax Filing" chooser.
const businessTaxFilingChoices = <(String, String, String)>[
  ('business', 'Schedule C', 'Sole prop / gig · Form 1040 Schedule C'),
  ('form1120S', 'Form 1120-S', 'S-Corporation income tax return'),
  ('form1120', 'Form 1120', 'C-Corporation income tax return'),
  ('form1065', 'Form 1065', 'Partnership / multi-member LLC'),
];

const otherEntityFilingChoices = <(String, String, String)>[
  ('form1041', 'Form 1041', 'Trust / estate income tax return'),
  ('form990', 'Form 990', 'Tax-exempt organization'),
  ('form990EZ', 'Form 990-EZ', 'Smaller tax-exempt organization'),
];

num _asNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

/// Deep-merge [loaded] onto [defaults] (objects merge; arrays replace when non-empty).
Map<String, dynamic> deepMergeOrganizer(
  Map<String, dynamic> defaults,
  Map<String, dynamic>? loaded,
) {
  if (loaded == null || loaded.isEmpty) {
    return Map<String, dynamic>.from(defaults);
  }
  final out = Map<String, dynamic>.from(defaults);
  for (final entry in loaded.entries) {
    final key = entry.key;
    final lv = entry.value;
    final dv = out[key];
    if (lv is Map && dv is Map) {
      out[key] = deepMergeOrganizer(
        Map<String, dynamic>.from(dv),
        Map<String, dynamic>.from(lv),
      );
    } else if (lv is List) {
      out[key] = lv.isNotEmpty ? List<dynamic>.from(lv) : (dv is List ? List<dynamic>.from(dv) : lv);
    } else if (lv != null) {
      out[key] = lv;
    }
  }
  return out;
}

class OrganizerDefaults {
  OrganizerDefaults._();

  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return Map<String, dynamic>.from(_cache!);
    final raw = await rootBundle.loadString('assets/organizer/default_form_data.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('default_form_data.json must be an object');
    }
    _cache = Map<String, dynamic>.from(decoded);
    return Map<String, dynamic>.from(_cache!);
  }
}
