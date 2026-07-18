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
  if (step == 'Filing Info') return 'Choose personal, business, or entity filing';
  if (step == 'Personal Info') return 'Name, SSN, address, dependents';
  if (step == 'Income (1040)') return 'W-2 wages and Form 1040 income lines';
  if (step == 'Schedule B') return 'Interest and dividend payers';
  if (step == 'Schedule C') return 'Sole prop / gig profit & loss';
  if (step == 'Schedule D') return 'Capital gains and transactions';
  if (step == 'Schedule E') return 'Rental and royalty properties';
  if (step == 'Schedule F') return 'Farm income and expenses';
  if (step == 'Credits & Deductions') return 'Federal credits, Schedule A, Forms 8863/5695/8962';
  if (step == 'Form 1040-X') return 'Amended federal return (IRS Form 1040-X)';
  if (step == 'State Tax Returns' || step == 'CA 540 State Tax') {
    return 'All states intake + California 540 / 540X suite';
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
    return n(data['wages']) > 0 ||
        hasW2 ||
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
    return data['itemizeDeductions'] == true ||
        data['hasEIC'] == true ||
        n(data['educatorExpenses']) > 0 ||
        n(data['studentLoanInterest']) > 0 ||
        n(data['iraDeduction']) > 0 ||
        n(data['educationCredits']) > 0 ||
        n(data['childTaxCreditChildren']) > 0 ||
        n(data['residentialEnergyCredit']) > 0 ||
        n(data['dependentCareExpenses']) > 0 ||
        nested(f8863, 'studentName').isNotEmpty ||
        n(f5695['solarElectric']) > 0 ||
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

/// Minimal W-2 form matching mkgtaxconsultants.com `defaultW2Data` keys used on mobile.
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
      'box10_dependentCareBenefits': 0,
      'box11_nonqualifiedPlans': 0,
      'box12a_code': '',
      'box12a_amount': 0,
      'box13_statutory': false,
      'box13_retirementPlan': false,
      'box13_thirdPartySickPay': false,
      'box14_other': '',
      'box15_state': '',
      'box15_stateId': '',
      'box16_stateWages': 0,
      'box17_stateTax': 0,
      'box18_localWages': 0,
      'box19_localTax': 0,
      'box20_localityName': '',
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
      'Direct Deposit',
      'Review & Sign',
    ];
  }
  return List<String>.from(personalOrganizerSteps);
}

bool showScheduleCStep(Map<String, dynamic> data) {
  final prep = '${data['prepType'] ?? 'personal'}';
  final businessIncome = _asNum(data['businessIncome']);
  return prep == 'business' || businessIncome > 0;
}

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
