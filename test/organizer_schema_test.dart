import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_defaults.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_section_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default form data includes Schedule A–F and entity forms', () async {
    final raw = await rootBundle.loadString('assets/organizer/default_form_data.json');
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);

    expect(data['prepType'], 'personal');
    expect(data['scheduleA'], isA<Map>());
    expect(data['scheduleB']['interestPayers'], isA<List>());
    expect(data['scheduleC']['businessName'], '');
    expect(data['scheduleD']['transactions'], isA<List>());
    expect(data['scheduleE']['rentalProperties'], isA<List>());
    expect(data['scheduleF']['farmName'], '');
    expect(data['dependents'], isA<List>());
    expect(data['w2Forms'], isA<List>());
    expect(data['w2Forms'], isNotEmpty);
    expect(data['w2Forms'][0]['box1_wagesTips'], 0);
    expect(data['form1120'], isA<Map>());
    expect(data['form1120S'], isA<Map>());
    expect(data['form1065'], isA<Map>());
    expect(data['form990EZ'], isA<Map>());
    expect(data['scheduleA']['medicalExpenses'], 0);
    expect(data['ca540']['stateWages'], isA<num>());
    expect(data['additionalStateReturns'], isA<List>());
    expect(data['form8863'], isA<Map>());
    expect(data['form5695'], isA<Map>());
    expect(data['form8962'], isA<Map>());
    expect(data['scheduleCA'], isA<Map>());
    expect(data['ftb3514'], isA<Map>());
    expect(data['schedule3'], isA<Map>());
  });

  test('empty dependent and w2 helpers match web keys', () {
    final dep = emptyDependent();
    expect(dep.keys, containsAll(['name', 'ssn', 'ssnType', 'relationship', 'dob']));
    final w2 = emptyW2Form(employeeFirstName: 'Pat');
    expect(w2['employeeFirstName'], 'Pat');
    expect(w2['box1_wagesTips'], 0);
    expect(emptyInterestPayer()['payerName'], '');
    expect(emptyDividendPayer()['ordinaryDividends'], 0);
    expect(emptyCapitalTransaction()['term'], 'long');
  });

  test('income completion recognizes w2Forms', () {
    expect(
      isOrganizerStepComplete('Income (1040)', {
        'w2Forms': [
          {'employerName': 'Acme', 'box1_wagesTips': 100},
        ],
      }),
      isTrue,
    );
  });

  test('schedule step completion heuristics', () {
    expect(
      isOrganizerStepComplete('Schedule B', {
        'scheduleB': {
          'interestPayers': [
            {'payerName': 'Bank', 'amount': 50},
          ],
        },
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('Schedule D', {
        'scheduleD': {'shortTermGains': 10, 'longTermGains': 0, 'transactions': []},
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('Schedule F', {
        'scheduleF': {'farmName': 'Green Acres', 'grossFarmIncome': 0},
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('State Tax Returns', {
        'ca540': {'residencyStatus': 'resident', 'stateWages': 0},
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('State Tax Returns', {
        'additionalStateReturns': [
          {'stateCode': 'NY', 'wages': 1000},
        ],
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('Credits & Deductions', {
        'form8863': {'studentName': 'Alex', 'tuitionPaid': 5000},
      }),
      isTrue,
    );
    expect(
      isOrganizerStepComplete('Form 1041 - Trust / Estate', {
        'form1041': {'entityName': 'Smith Trust'},
      }),
      isTrue,
    );
  });

  test('prepType steps include 1040 and federal schedules', () {
    final personal = stepsForPrepType('personal');
    expect(personal, containsAll([
      'Income (1040)',
      'Schedule B',
      'Schedule C',
      'Schedule D',
      'Schedule E',
      'Schedule F',
      'Credits & Deductions',
      'Form 1040-X',
      'State Tax Returns',
    ]));
    expect(personal.length, 13);
    expect(personal, isNot(contains('CA 540 State Tax')));
    expect(stepsForPrepType('business').contains('Schedule C'), isTrue);
    expect(stepsForPrepType('form1120'), [
      'Filing Info',
      'Form 1120 - C-Corporation',
      'State Tax Returns',
      'Direct Deposit',
      'Review & Sign',
    ]);
    expect(stepsForPrepType('form1120S'), [
      'Filing Info',
      'Form 1120-S - S-Corporation',
      'State Tax Returns',
      'Direct Deposit',
      'Review & Sign',
    ]);
    expect(stepsForPrepType('form990EZ').length, 5);
  });

  test('showScheduleCStep respects business prep and includeScheduleC', () {
    expect(showScheduleCStep({'prepType': 'personal'}), isFalse);
    expect(showScheduleCStep({'prepType': 'business'}), isTrue);
    expect(
      showScheduleCStep({'prepType': 'personal', 'includeScheduleC': true}),
      isTrue,
    );
    expect(
      showScheduleCStep({'prepType': 'personal', 'businessIncome': 500}),
      isTrue,
    );
    expect(showScheduleCStep({'prepType': 'form1120'}), isFalse);
  });

  test('business tax filing choices cover Schedule C and corps', () {
    expect(
      businessTaxFilingChoices.map((e) => e.$1),
      containsAll(['business', 'form1120', 'form1120S', 'form1065']),
    );
    expect(
      otherEntityFilingChoices.map((e) => e.$1),
      containsAll(['form1041', 'form990', 'form990EZ']),
    );
  });

  test('deep merge preserves nested scheduleC fields', () {
    final merged = deepMergeOrganizer(
      {
        'prepType': 'personal',
        'scheduleC': {'businessName': '', 'grossReceipts': 0},
      },
      {
        'prepType': 'business',
        'scheduleC': {'businessName': 'Acme Gig', 'grossReceipts': 12000},
      },
    );
    expect(merged['prepType'], 'business');
    expect(merged['scheduleC']['businessName'], 'Acme Gig');
    expect(merged['scheduleC']['grossReceipts'], 12000);
  });

  test('section mapper hydrates and slices schedule answers', () {
    final defaults = {
      'prepType': 'personal',
      'filingStatus': 'single',
      'wages': 0,
      'scheduleB': {'interestPayers': <dynamic>[], 'dividendPayers': <dynamic>[]},
      'scheduleC': {'businessName': '', 'grossReceipts': 0},
      'scheduleD': {'shortTermGains': 0, 'longTermGains': 0, 'transactions': <dynamic>[]},
      'scheduleE': {'rentalProperties': <dynamic>[]},
      'scheduleF': {'farmName': ''},
      'scheduleA': {'medicalExpenses': 0},
      'ca540': {'stateWages': 0, 'residencyStatus': ''},
      'w2Forms': <dynamic>[],
    };
    final org = {
      'prep_type': 'business',
      'status': 'draft',
      'sections': {
        'answers': {
          'filing_info': {
            'answers': {'prepType': 'business', 'filingStatus': 'single', 'filingYear': 2025},
            'complete': true,
          },
          'income_1040': {
            'answers': {
              'wages': 52000,
              'w2Forms': [
                {'employerName': 'Acme', 'box1_wagesTips': 52000},
              ],
            },
          },
          'schedule_c': {
            'answers': {
              'scheduleC': {'businessName': 'Side Gig', 'grossReceipts': 8000},
              'businessIncome': 8000,
            },
          },
          'schedule_b': {
            'answers': {
              'scheduleB': {
                'interestPayers': [
                  {'payerName': 'Bank', 'amount': 120},
                ],
                'dividendPayers': <dynamic>[],
              },
              'interestIncome': 120,
            },
          },
        },
      },
    };
    final hydrated = OrganizerSectionMapper.hydrateFromServer(
      defaults: defaults,
      organizer: org,
      fallbackYear: 2025,
    );
    expect(hydrated['prepType'], 'business');
    expect(hydrated['wages'], 52000);
    expect(hydrated['scheduleC']['businessName'], 'Side Gig');
    expect(hydrated['interestIncome'], 120);
    expect(hydrated['scheduleB']['interestPayers'], isNotEmpty);

    final incomeSlice = OrganizerSectionMapper.answersForSection('income_1040', hydrated);
    expect(incomeSlice['wages'], 52000);
    expect(incomeSlice['w2Forms'], isA<List>());

    final personalSlice = OrganizerSectionMapper.answersForSection('personal_info', {
      ...hydrated,
      'firstName': 'Pat',
      'dependents': [
        {'name': 'Kid', 'ssn': '123-45-6789', 'relationship': 'son'},
      ],
    });
    expect(personalSlice.containsKey('ssn'), isFalse);
    expect((personalSlice['dependents'] as List).first.containsKey('ssn'), isFalse);

    expect(OrganizerSectionMapper.sectionKeysForPrep('business'), contains('schedule_c'));
    expect(OrganizerSectionMapper.sectionKeysForPrep('business'), contains('state_multistate'));
    expect(OrganizerSectionMapper.sectionKeysForPrep('form1065'), contains('entity_form'));
    expect(OrganizerSectionMapper.sectionKeysForPrep('form1065'), contains('state_ca_540'));

    final filingSlice = OrganizerSectionMapper.answersForSection('filing_info', {
      'prepType': 'personal',
      'filingStatus': 'single',
      'filingYear': 2025,
      'includeScheduleC': true,
    });
    expect(filingSlice['includeScheduleC'], isTrue);
    expect(filingSlice['prepType'], 'personal');

    final withIncludeFlag = OrganizerSectionMapper.hydrateFromServer(
      defaults: defaults,
      organizer: {
        'prep_type': 'personal',
        'status': 'draft',
        'sections': {
          'answers': {
            'filing_info': {
              'answers': {
                'prepType': 'personal',
                'filingStatus': 'single',
                'filingYear': 2025,
                'includeScheduleC': true,
              },
            },
          },
        },
      },
      fallbackYear: 2025,
    );
    expect(withIncludeFlag['includeScheduleC'], isTrue);

    final creditSlice = OrganizerSectionMapper.answersForSection('credits_deductions', {
      ...hydrated,
      'form8863': {'studentName': 'Pat', 'tuitionPaid': 1000},
      'schedule3': {'educationCredits': 1000},
    });
    expect(creditSlice['form8863']['studentName'], 'Pat');
    expect(creditSlice['schedule3']['educationCredits'], 1000);

    final multiSlice = OrganizerSectionMapper.answersForSection('state_multistate', {
      'additionalStateReturns': [
        {'stateCode': 'NY', 'wages': 2000},
      ],
    });
    expect(multiSlice['additionalStateReturns'], isNotEmpty);
  });

  test('hydrate ignores noop placeholder section stubs', () async {
    final defaults = await OrganizerDefaults.load();
    final org = {
      'prep_type': 'personal',
      'sections': {
        'answers': {
          'schedule_b': {
            'answers': {'noop': 1},
            'complete': false,
          },
          'income_1040': {
            'answers': {'wages': 41000},
            'complete': false,
          },
        },
      },
    };
    final hydrated = OrganizerSectionMapper.hydrateFromServer(
      defaults: defaults,
      organizer: org,
      fallbackYear: 2025,
    );
    expect(hydrated['wages'], 41000);
    // Defaults scheduleB should remain intact (not polluted with noop).
    expect(hydrated['scheduleB'], isA<Map>());
    expect(hydrated['scheduleB'].containsKey('noop'), isFalse);
  });
}
