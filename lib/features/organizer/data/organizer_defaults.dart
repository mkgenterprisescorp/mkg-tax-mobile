import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Web-parity step labels (financemkgtaxpro Organizer.tsx).
const personalOrganizerSteps = <String>[
  'Filing Info',
  'Personal Info',
  'Income (1040)',
  'Credits & Deductions',
  'Schedule C',
  'CA 540 State Tax',
  'Direct Deposit',
  'Review & Sign',
];

/// Icon + short cue for each walkthrough section (hub tiles).
IconData iconForOrganizerStep(String step) {
  if (step == 'Filing Info') return Icons.flag_outlined;
  if (step == 'Personal Info') return Icons.person_outline;
  if (step == 'Income (1040)') return Icons.payments_outlined;
  if (step == 'Credits & Deductions') return Icons.savings_outlined;
  if (step == 'Schedule C') return Icons.storefront_outlined;
  if (step == 'CA 540 State Tax') return Icons.map_outlined;
  if (step == 'Direct Deposit') return Icons.account_balance_outlined;
  if (step == 'Review & Sign') return Icons.draw_outlined;
  if (step.contains('1120-S') || step.contains('1120')) return Icons.apartment_outlined;
  if (step.contains('1065')) return Icons.groups_outlined;
  if (step.contains('1041')) return Icons.account_balance_outlined;
  if (step.contains('990')) return Icons.volunteer_activism_outlined;
  return Icons.description_outlined;
}

String cueForOrganizerStep(String step) {
  if (step == 'Filing Info') return 'Choose personal or business filing';
  if (step == 'Personal Info') return 'Name, SSN, address, dependents';
  if (step == 'Income (1040)') return 'Wages, interest, Schedule E rentals';
  if (step == 'Credits & Deductions') return 'Credits and Schedule A';
  if (step == 'Schedule C') return 'Sole prop / gig profit & loss';
  if (step == 'CA 540 State Tax') return 'California Form 540';
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
    final rentals = (m('scheduleE')['rentalProperties'] as List?) ?? const [];
    final w2s = (data['w2Forms'] as List?) ?? const [];
    final hasW2 = w2s.any((e) {
      if (e is! Map) return false;
      return n(e['box1_wagesTips']) > 0 || '${e['employerName'] ?? ''}'.trim().isNotEmpty;
    });
    return n(data['wages']) > 0 ||
        hasW2 ||
        n(data['interestIncome']) > 0 ||
        n(data['businessIncome']) > 0 ||
        n(data['otherIncome']) > 0 ||
        rentals.isNotEmpty;
  }
  if (step == 'Credits & Deductions') {
    return data['itemizeDeductions'] == true ||
        n(data['educatorExpenses']) > 0 ||
        n(data['studentLoanInterest']) > 0 ||
        n(data['iraDeduction']) > 0;
  }
  if (step == 'Schedule C') {
    final sc = m('scheduleC');
    return nested(sc, 'businessName').isNotEmpty || n(sc['grossReceipts']) > 0;
  }
  if (step == 'CA 540 State Tax') {
    final ca = m('ca540');
    return ca.isNotEmpty && (n(ca['caWages']) > 0 || nested(ca, 'residencyStatus').isNotEmpty);
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
          '${form['corporationName'] ?? form['partnershipName'] ?? form['organizationName'] ?? form['trustName'] ?? ''}'
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

/// Web Organizer dependent row: `{ name, ssn, ssnType, relationship, dob }`.
Map<String, dynamic> emptyDependent() => {
      'name': '',
      'ssn': '',
      'ssnType': 'ssn',
      'relationship': '',
      'dob': '',
    };

/// Minimal W-2 form matching financemkgtaxpro `defaultW2Data` keys used on mobile.
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
