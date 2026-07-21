import 'organizer_defaults.dart';

/// Maps canonical web `tax_returns.data` keys ↔ Laravel workspace section answers.
///
/// Section keys match `OrganizerSectionCatalog` on mkg-tax-backend-2.
class OrganizerSectionMapper {
  OrganizerSectionMapper._();

  static const personalSectionKeys = <String>[
    'filing_info',
    'personal_info',
    'income_1040',
    'schedule_b',
    'schedule_c',
    'schedule_d',
    'schedule_e',
    'schedule_f',
    'credits_deductions',
    'form_1040x',
    'state_ca_540',
    'state_multistate',
    'state_business',
    'direct_deposit',
    'review_sign',
  ];

  static const entitySectionKeys = <String>[
    'filing_info',
    'entity_form',
    'state_ca_540',
    'state_multistate',
    'state_business',
    'direct_deposit',
    'review_sign',
  ];

  static const _creditFormKeys = <String>[
    'scheduleA',
    'schedule1',
    'schedule1A',
    'schedule2',
    'schedule3',
    'scheduleSE',
    'schedule8812',
    'scheduleH',
    'scheduleR',
    'form8863',
    'form5695',
    'form8962',
    'form8889',
    'form8995',
    'form8839',
    'form2441',
    'form8829',
    'form6251',
    'form8959',
    'form8960',
  ];

  static const _caFormKeys = <String>[
    'ca540',
    'scheduleCA',
    'ftb3514',
    'ftb3506',
    'scheduleP540',
    'scheduleS',
    'ca540x',
    'caDirectDeposit',
    'caPayment',
    'caForm100',
    'caForm100S',
    'caForm565',
    'caForm541',
    'caForm199',
    'caScheduleR',
    'caScheduleK1',
  ];

  static String stepToSectionKey(String step) {
    switch (step) {
      case 'Filing Info':
        return 'filing_info';
      case 'Personal Info':
        return 'personal_info';
      case 'Income (1040)':
        return 'income_1040';
      case 'Schedule B':
        return 'schedule_b';
      case 'Schedule C':
        return 'schedule_c';
      case 'Schedule D':
        return 'schedule_d';
      case 'Schedule E':
        return 'schedule_e';
      case 'Schedule F':
        return 'schedule_f';
      case 'Credits & Deductions':
        return 'credits_deductions';
      case 'Form 1040-X':
        return 'form_1040x';
      case 'State Tax Returns':
      case 'CA 540 State Tax':
        return 'state_ca_540';
      case 'Direct Deposit':
        return 'direct_deposit';
      case 'Review & Sign':
        return 'review_sign';
      default:
        if (step.startsWith('Form ')) return 'entity_form';
        return 'filing_info';
    }
  }

  /// Build canonical organizer data from Laravel `sections.answers` + defaults.
  static Map<String, dynamic> hydrateFromServer({
    required Map<String, dynamic> defaults,
    required Map<String, dynamic>? organizer,
    required int fallbackYear,
  }) {
    final base = Map<String, dynamic>.from(defaults);
    final prep = '${organizer?['prep_type'] ?? base['prepType'] ?? 'personal'}';
    base['prepType'] = prep;
    base['filingYear'] = base['filingYear'] ?? fallbackYear;

    final sections = organizer?['sections'] is Map
        ? Map<String, dynamic>.from(organizer!['sections'] as Map)
        : <String, dynamic>{};
    final answersRoot = sections['answers'] is Map
        ? Map<String, dynamic>.from(sections['answers'] as Map)
        : <String, dynamic>{};

    Map<String, dynamic> sectionAnswers(String key) {
      final block = answersRoot[key];
      Map<String, dynamic> raw;
      if (block is Map && block['answers'] is Map) {
        raw = Map<String, dynamic>.from(block['answers'] as Map);
      } else if (block is Map) {
        raw = Map<String, dynamic>.from(block);
      } else {
        return {};
      }
      // Server placeholder stubs (`{"noop": 1}`) are not real answers — treat empty.
      if (raw.length == 1 && raw.containsKey('noop')) {
        return {};
      }
      return raw;
    }

    void mergeRoot(Map<String, dynamic> src, Iterable<String> keys) {
      for (final k in keys) {
        if (src.containsKey(k) && src[k] != null) base[k] = src[k];
      }
    }

    final filing = sectionAnswers('filing_info');
    mergeRoot(filing, const ['prepType', 'filingStatus', 'filingYear', 'includeScheduleC']);

    final personal = sectionAnswers('personal_info');
    mergeRoot(personal, const [
      'firstName',
      'middleInitial',
      'lastName',
      'ssnType',
      'dateOfBirth',
      'phone',
      'email',
      'address',
      'apartment',
      'city',
      'state',
      'zip',
      'spouseFirstName',
      'spouseLastName',
      'numDependents',
      'dependents',
    ]);

    final income = sectionAnswers('income_1040');
    mergeRoot(income, const [
      'wages',
      'taxWithheld',
      'taxWithheldW2',
      'taxWithheld1099',
      'interestIncome',
      'dividendIncome',
      'qualifiedDividends',
      'businessIncome',
      'necCompensation',
      'form1099KGross',
      'capitalGains',
      'rentalIncome',
      'farmIncome',
      'unemploymentComp',
      'stateTaxRefund',
      'socialSecurityBenefits',
      'socialSecurityGross',
      'otherIncome',
      'iraDistributions',
      'iraDistributionsGross',
      'pensionAnnuities',
      'pensionAnnuitiesGross',
      'alimonyReceived',
      'w2Forms',
      'form1099NEC',
      'form1099R',
      'form1099DA',
      'formSSA1099',
      'form1099G',
      'form1099INT',
      'form1099DIV',
      'form1099B',
      'form1099K',
      'schedule1',
    ]);

    final sb = sectionAnswers('schedule_b');
    if (sb.isNotEmpty) {
      base['scheduleB'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['scheduleB'] as Map?) ?? {}),
        sb['scheduleB'] is Map ? Map<String, dynamic>.from(sb['scheduleB'] as Map) : sb,
      );
      if (sb['interestIncome'] != null) base['interestIncome'] = sb['interestIncome'];
      if (sb['dividendIncome'] != null) base['dividendIncome'] = sb['dividendIncome'];
    }

    final sc = sectionAnswers('schedule_c');
    if (sc.isNotEmpty) {
      base['scheduleC'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['scheduleC'] as Map?) ?? {}),
        sc['scheduleC'] is Map ? Map<String, dynamic>.from(sc['scheduleC'] as Map) : sc,
      );
      if (sc['businessIncome'] != null) base['businessIncome'] = sc['businessIncome'];
    }

    final sd = sectionAnswers('schedule_d');
    if (sd.isNotEmpty) {
      base['scheduleD'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['scheduleD'] as Map?) ?? {}),
        sd['scheduleD'] is Map ? Map<String, dynamic>.from(sd['scheduleD'] as Map) : sd,
      );
      if (sd['capitalGains'] != null) base['capitalGains'] = sd['capitalGains'];
    }

    final se = sectionAnswers('schedule_e');
    if (se.isNotEmpty) {
      base['scheduleE'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['scheduleE'] as Map?) ?? {}),
        se['scheduleE'] is Map ? Map<String, dynamic>.from(se['scheduleE'] as Map) : se,
      );
      if (se['rentalIncome'] != null) base['rentalIncome'] = se['rentalIncome'];
      if (se['federalK1Forms'] is List) {
        base['federalK1Forms'] = List<dynamic>.from(se['federalK1Forms'] as List);
      }
    }

    final sf = sectionAnswers('schedule_f');
    if (sf.isNotEmpty) {
      base['scheduleF'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['scheduleF'] as Map?) ?? {}),
        sf['scheduleF'] is Map ? Map<String, dynamic>.from(sf['scheduleF'] as Map) : sf,
      );
      if (sf['farmIncome'] != null) base['farmIncome'] = sf['farmIncome'];
    }

    final credits = sectionAnswers('credits_deductions');
    mergeRoot(credits, const [
      'educatorExpenses',
      'studentLoanInterest',
      'iraDeduction',
      'dependentCareExpenses',
      'dependentCareProvider',
      'dependentCareProviderTIN',
      'educationCredits',
      'childTaxCreditChildren',
      'itemizeDeductions',
      'charitableContributions',
      'hasEIC',
      'numEICChildren',
      'residentialEnergyCredit',
      'mortgageInterest',
      'propertyTaxes',
      'medicalExpenses',
      'stateLocalTaxes',
      'movingExpenses',
      'alimonyPaid',
      'selfEmploymentTax',
      'retirementContributions',
      'healthInsurancePremiums',
      'creditsGuidanceAcknowledged',
    ]);
    for (final key in _creditFormKeys) {
      if (credits[key] is Map) {
        base[key] = deepMergeOrganizer(
          Map<String, dynamic>.from((base[key] as Map?) ?? {}),
          Map<String, dynamic>.from(credits[key] as Map),
        );
      }
    }

    final form1040x = sectionAnswers('form_1040x');
    if (form1040x['form1040x'] is Map) {
      base['form1040x'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['form1040x'] as Map?) ?? {}),
        Map<String, dynamic>.from(form1040x['form1040x'] as Map),
      );
    } else if (form1040x.isNotEmpty) {
      base['form1040x'] = deepMergeOrganizer(
        Map<String, dynamic>.from((base['form1040x'] as Map?) ?? {}),
        form1040x,
      );
    }

    final ca = sectionAnswers('state_ca_540');
    if (ca.isNotEmpty) {
      for (final key in _caFormKeys) {
        if (ca[key] is Map) {
          base[key] = deepMergeOrganizer(
            Map<String, dynamic>.from((base[key] as Map?) ?? {}),
            Map<String, dynamic>.from(ca[key] as Map),
          );
        }
      }
      // Legacy payloads stored only ca540 map at the root of the section.
      if (ca['ca540'] == null && ca.containsKey('stateWages')) {
        base['ca540'] = deepMergeOrganizer(
          Map<String, dynamic>.from((base['ca540'] as Map?) ?? {}),
          Map<String, dynamic>.from(ca),
        );
      }
    }

    final multi = sectionAnswers('state_multistate');
    if (multi['additionalStateReturns'] is List) {
      base['additionalStateReturns'] = List<dynamic>.from(multi['additionalStateReturns'] as List);
    }

    final biz = sectionAnswers('state_business');
    if (biz['stateBusinessReturns'] is List) {
      base['stateBusinessReturns'] = List<dynamic>.from(biz['stateBusinessReturns'] as List);
    }

    final dd = sectionAnswers('direct_deposit');
    mergeRoot(dd, const ['bankName', 'routingNumber', 'accountNumber', 'accountType']);

    final review = sectionAnswers('review_sign');
    mergeRoot(review, const [
      'typedSignature',
      'printedName',
      'signatureType',
      'consentToEFile',
      'consentPerjury',
      'consent7216Use',
      'consent7216Disclosure',
      'consentToDisclosure',
      'consentEngagement',
      'consentBookkeeping',
    ]);

    final entity = sectionAnswers('entity_form');
    if (entity.isNotEmpty && businessEntityTypes.contains(prep)) {
      final formKey = entity['formKey']?.toString() ?? prep;
      final formData = entity['form'] is Map
          ? Map<String, dynamic>.from(entity['form'] as Map)
          : Map<String, dynamic>.from(entity);
      base[formKey] = deepMergeOrganizer(
        Map<String, dynamic>.from((base[formKey] as Map?) ?? {}),
        formData,
      );
    }

    base['serverCatalog'] = sections['catalog'];
    return base;
  }

  /// Slice canonical data into one Laravel section payload (SSN fields omitted).
  static Map<String, dynamic> answersForSection(String sectionKey, Map<String, dynamic> data) {
    final prep = '${data['prepType'] ?? 'personal'}';
    switch (sectionKey) {
      case 'filing_info':
        return {
          'prepType': prep,
          'filingStatus': data['filingStatus'] ?? 'single',
          'filingYear': data['filingYear'],
          'includeScheduleC': data['includeScheduleC'] == true,
        };
      case 'personal_info':
        return {
          'firstName': data['firstName'],
          'middleInitial': data['middleInitial'],
          'lastName': data['lastName'],
          'ssnType': data['ssnType'],
          // Never send SSN/ITIN — server also strips identifiers.
          'dateOfBirth': data['dateOfBirth'],
          'phone': data['phone'],
          'email': data['email'],
          'address': data['address'],
          'apartment': data['apartment'],
          'city': data['city'],
          'state': data['state'],
          'zip': data['zip'],
          'spouseFirstName': data['spouseFirstName'],
          'spouseLastName': data['spouseLastName'],
          'numDependents': data['numDependents'],
          'dependents': _scrubDependentList(data['dependents']),
        };
      case 'income_1040':
        return {
          'wages': data['wages'],
          'taxWithheld': data['taxWithheld'],
          'taxWithheldW2': data['taxWithheldW2'],
          'taxWithheld1099': data['taxWithheld1099'],
          'interestIncome': data['interestIncome'],
          'dividendIncome': data['dividendIncome'],
          'qualifiedDividends': data['qualifiedDividends'],
          'businessIncome': data['businessIncome'],
          'necCompensation': data['necCompensation'],
          'form1099KGross': data['form1099KGross'],
          'capitalGains': data['capitalGains'],
          'rentalIncome': data['rentalIncome'],
          'farmIncome': data['farmIncome'],
          'unemploymentComp': data['unemploymentComp'],
          'stateTaxRefund': data['stateTaxRefund'],
          'socialSecurityBenefits': data['socialSecurityBenefits'],
          'socialSecurityGross': data['socialSecurityGross'],
          'otherIncome': data['otherIncome'],
          'iraDistributions': data['iraDistributions'],
          'iraDistributionsGross': data['iraDistributionsGross'],
          'pensionAnnuities': data['pensionAnnuities'],
          'pensionAnnuitiesGross': data['pensionAnnuitiesGross'],
          'alimonyReceived': data['alimonyReceived'],
          'w2Forms': _scrubW2List(data['w2Forms']),
          'form1099NEC': data['form1099NEC'],
          'form1099R': data['form1099R'],
          'form1099DA': data['form1099DA'],
          'formSSA1099': data['formSSA1099'],
          'form1099G': data['form1099G'],
          'form1099INT': data['form1099INT'],
          'form1099DIV': data['form1099DIV'],
          'form1099B': data['form1099B'],
          'form1099K': data['form1099K'],
          'schedule1': data['schedule1'],
        };
      case 'schedule_b':
        return {
          'scheduleB': data['scheduleB'] ?? {'interestPayers': [], 'dividendPayers': []},
          'interestIncome': data['interestIncome'],
          'dividendIncome': data['dividendIncome'],
        };
      case 'schedule_c':
        return {
          'scheduleC': data['scheduleC'] ?? {},
          'businessIncome': data['businessIncome'],
        };
      case 'schedule_d':
        return {
          'scheduleD': data['scheduleD'] ?? {},
          'capitalGains': data['capitalGains'],
        };
      case 'schedule_e':
        return {
          'scheduleE': data['scheduleE'] ?? {'rentalProperties': [], 'partII': []},
          'rentalIncome': data['rentalIncome'],
          'federalK1Forms': data['federalK1Forms'] ?? const [],
        };
      case 'schedule_f':
        return {
          'scheduleF': data['scheduleF'] ?? {},
          'farmIncome': data['farmIncome'],
        };
      case 'credits_deductions':
        return {
          'educatorExpenses': data['educatorExpenses'],
          'studentLoanInterest': data['studentLoanInterest'],
          'iraDeduction': data['iraDeduction'],
          'dependentCareExpenses': data['dependentCareExpenses'],
          'dependentCareProvider': data['dependentCareProvider'],
          'dependentCareProviderTIN': data['dependentCareProviderTIN'],
          'educationCredits': data['educationCredits'],
          'childTaxCreditChildren': data['childTaxCreditChildren'],
          'itemizeDeductions': data['itemizeDeductions'],
          'charitableContributions': data['charitableContributions'],
          'hasEIC': data['hasEIC'],
          'numEICChildren': data['numEICChildren'],
          'residentialEnergyCredit': data['residentialEnergyCredit'],
          'mortgageInterest': data['mortgageInterest'],
          'propertyTaxes': data['propertyTaxes'],
          'medicalExpenses': data['medicalExpenses'],
          'stateLocalTaxes': data['stateLocalTaxes'],
          'movingExpenses': data['movingExpenses'],
          'alimonyPaid': data['alimonyPaid'],
          'selfEmploymentTax': data['selfEmploymentTax'],
          'retirementContributions': data['retirementContributions'],
          'healthInsurancePremiums': data['healthInsurancePremiums'],
          'creditsGuidanceAcknowledged': data['creditsGuidanceAcknowledged'],
          for (final key in _creditFormKeys) key: data[key] ?? {},
        };
      case 'form_1040x':
        return {
          'form1040x': data['form1040x'] ?? {},
        };
      case 'state_ca_540':
        return {
          for (final key in _caFormKeys) key: data[key] ?? {},
        };
      case 'state_multistate':
        return {
          'additionalStateReturns': data['additionalStateReturns'] ?? const [],
        };
      case 'state_business':
        return {
          'stateBusinessReturns': data['stateBusinessReturns'] ?? const [],
        };
      case 'direct_deposit':
        return {
          'bankName': data['bankName'],
          'routingNumber': data['routingNumber'],
          'accountNumber': data['accountNumber'],
          'accountType': data['accountType'],
        };
      case 'review_sign':
        return {
          'typedSignature': data['typedSignature'],
          'printedName': data['printedName'],
          'signatureType': data['signatureType'],
          'consentToEFile': data['consentToEFile'],
          'consentPerjury': data['consentPerjury'],
          'consent7216Use': data['consent7216Use'],
          'consent7216Disclosure': data['consent7216Disclosure'],
          'consentToDisclosure': data['consentToDisclosure'],
          'consentEngagement': data['consentEngagement'],
          'consentBookkeeping': data['consentBookkeeping'],
        };
      case 'entity_form':
        final form = Map<String, dynamic>.from((data[prep] as Map?) ?? {});
        return {'formKey': prep, 'form': form};
      default:
        return {};
    }
  }

  static List<String> sectionKeysForPrep(String prepType) {
    if (businessEntityTypes.contains(prepType)) return List<String>.from(entitySectionKeys);
    return List<String>.from(personalSectionKeys);
  }

  static List<dynamic> _scrubDependentList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          {
            'name': e['name'],
            'ssnType': e['ssnType'],
            'relationship': e['relationship'],
            'dob': e['dob'],
            // omit ssn
          },
    ];
  }

  static List<dynamic> _scrubW2List(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          () {
            final m = Map<String, dynamic>.from(e);
            m.remove('employeeSSN');
            return m;
          }(),
    ];
  }
}
