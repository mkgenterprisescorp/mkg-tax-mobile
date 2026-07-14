import 'dart:convert';

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
