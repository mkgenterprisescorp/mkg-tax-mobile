/// Maps verified extraction fields into canonical organizer keys.
/// Never silently applies SSN/ITIN values — those stay review-only.
class DocumentExtractionMapper {
  const DocumentExtractionMapper();

  static const _ssnKeys = {
    'ssn',
    'employeessn',
    'taxpayerssn',
    'itin',
    'socialsecurity',
    'socialsecuritynumber',
  };

  /// Returns organizer patch data plus skipped sensitive keys.
  Map<String, dynamic> applyToOrganizer({
    required Map<String, dynamic> organizer,
    required String documentType,
    required Map<String, dynamic> fields,
    bool applySensitive = false,
  }) {
    final next = Map<String, dynamic>.from(organizer);
    final skipped = <String>[];
    final normalizedType = documentType.toUpperCase().replaceAll(' ', '');

    if (normalizedType.contains('W-2') || normalizedType == 'W2') {
      final forms = List<Map<String, dynamic>>.from(
        (next['w2Forms'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)) ??
            const <Map<String, dynamic>>[],
      );
      final target = forms.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(forms.first);
      _copyMapped(fields, target, _w2FieldMap, applySensitive: applySensitive, skipped: skipped);
      if (forms.isEmpty) {
        forms.add(target);
      } else {
        forms[0] = target;
      }
      next['w2Forms'] = forms;
      _syncWages(next, forms);
    } else if (normalizedType.contains('1040')) {
      _copyMapped(fields, next, _form1040FieldMap, applySensitive: applySensitive, skipped: skipped);
    } else {
      // Best-effort: copy known aliases into root when present.
      _copyMapped(fields, next, _form1040FieldMap, applySensitive: applySensitive, skipped: skipped);
      final forms = List<Map<String, dynamic>>.from(
        (next['w2Forms'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)) ??
            const <Map<String, dynamic>>[],
      );
      if (forms.isNotEmpty || fields.keys.any((k) => _w2FieldMap.containsKey(_norm(k)))) {
        final target = forms.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(forms.first);
        _copyMapped(fields, target, _w2FieldMap, applySensitive: applySensitive, skipped: skipped);
        if (forms.isEmpty) {
          forms.add(target);
        } else {
          forms[0] = target;
        }
        next['w2Forms'] = forms;
        _syncWages(next, forms);
      }
    }

    next['_extractionApplyMeta'] = {
      'skippedSensitiveKeys': skipped,
      'appliedAt': DateTime.now().toIso8601String(),
      'documentType': documentType,
    };
    return next;
  }

  List<Map<String, dynamic>> reviewRows(Map<String, dynamic> fields) {
    return fields.entries.map((e) {
      final sensitive = _isSensitive(e.key);
      return {
        'key': e.key,
        'label': _labelFor(e.key),
        'value': e.value?.toString() ?? '',
        'sensitive': sensitive,
        'accepted': !sensitive,
      };
    }).toList();
  }

  void _syncWages(Map<String, dynamic> organizer, List<Map<String, dynamic>> forms) {
    double wages = 0;
    double withheld = 0;
    for (final form in forms) {
      wages += _num(form['box1_wagesTips']);
      withheld += _num(form['box2_fedTaxWithheld']);
    }
    if (wages > 0) organizer['wages'] = wages.toStringAsFixed(2);
    if (withheld > 0) organizer['taxWithheld'] = withheld.toStringAsFixed(2);
  }

  void _copyMapped(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
    Map<String, String> map, {
    required bool applySensitive,
    required List<String> skipped,
  }) {
    for (final entry in source.entries) {
      final key = _norm(entry.key);
      if (_isSensitive(entry.key)) {
        if (!applySensitive) {
          skipped.add(entry.key);
          continue;
        }
      }
      final dest = map[key] ?? (map.values.contains(entry.key) ? entry.key : null);
      if (dest == null) continue;
      final value = entry.value;
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      target[dest] = text;
    }
  }

  static String _norm(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool _isSensitive(String key) {
    final n = _norm(key);
    return _ssnKeys.any((s) => n.contains(s));
  }

  static String _labelFor(String key) {
    return key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
  }

  static const _w2FieldMap = {
    'employername': 'employerName',
    'employerein': 'employerEIN',
    'ein': 'employerEIN',
    'employeraddress': 'employerAddress',
    'box1': 'box1_wagesTips',
    'box1wages': 'box1_wagesTips',
    'box1wagestips': 'box1_wagesTips',
    'wages': 'box1_wagesTips',
    'box2': 'box2_fedTaxWithheld',
    'box2fedtaxwithheld': 'box2_fedTaxWithheld',
    'federaltaxwithheld': 'box2_fedTaxWithheld',
    'box3': 'box3_ssWages',
    'box3sswages': 'box3_ssWages',
    'box4': 'box4_ssTaxWithheld',
    'box4sstaxwithheld': 'box4_ssTaxWithheld',
    'box5': 'box5_medicareWages',
    'box5medicarewages': 'box5_medicareWages',
    'box6': 'box6_medicareTaxWithheld',
    'box6medicaretaxwithheld': 'box6_medicareTaxWithheld',
    'box7': 'box7_ssTips',
    'box10': 'box10_dependentCareBenefits',
    'box12a': 'box12a_amount',
    'box12acode': 'box12a_code',
    'box12aamount': 'box12a_amount',
    'box13retirementplan': 'box13_retirementPlan',
    'box14': 'box14_other',
    'box14other': 'box14_other',
    'box15': 'box15_state',
    'box15state': 'box15_state',
    'box16': 'box16_stateWages',
    'box16statewages': 'box16_stateWages',
    'box17': 'box17_stateTax',
    'box17statetax': 'box17_stateTax',
  };

  static const _form1040FieldMap = {
    'firstname': 'firstName',
    'lastname': 'lastName',
    'middleinitial': 'middleInitial',
    'dateofbirth': 'dateOfBirth',
    'phone': 'phone',
    'email': 'email',
    'address': 'address',
    'city': 'city',
    'state': 'state',
    'zip': 'zip',
    'zipcode': 'zip',
    'wages': 'wages',
    'taxwithheld': 'taxWithheld',
    'federalwithholding': 'taxWithheld',
    'interestincome': 'interestIncome',
    'dividends': 'dividendIncome',
    'dividendincome': 'dividendIncome',
    'capitalgains': 'capitalGains',
    'otherincome': 'otherIncome',
    'businessincome': 'businessIncome',
    'rentalincome': 'rentalIncome',
    'spousefirstname': 'spouseFirstName',
    'spouselastname': 'spouseLastName',
  };
}
