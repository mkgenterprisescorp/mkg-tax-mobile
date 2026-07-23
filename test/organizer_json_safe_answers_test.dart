import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/laravel_organizer_repository.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_section_mapper.dart';

void main() {
  test('jsonSafeAnswers drops nulls and coerces non-finite numbers', () {
    final safe = jsonSafeAnswers({
      'tuitionPaid': 2500,
      'scholarships': null,
      'bad': double.infinity,
      'nan': double.nan,
      'form8863': {
        'creditType': 'american_opportunity',
        'tuitionPaid': 2500,
        'skip': null,
      },
      'list': [1, null, double.negativeInfinity],
    });

    expect(safe.containsKey('scholarships'), isFalse);
    expect(safe['bad'], 0);
    expect(safe['nan'], 0);
    expect(safe['form8863'], isA<Map>());
    expect((safe['form8863'] as Map).containsKey('skip'), isFalse);
    expect(safe['list'], [1, 0]);
    expect(() => jsonEncode(safe), returnsNormally);
  });

  test('schedule_e address-only answers stay non-empty after scrub', () {
    final answers = OrganizerSectionMapper.answersForSection('schedule_e', {
      'scheduleE': {
        'rentalProperties': [
          {
            'address': '1234 Easy Street',
            'rentReceived': 0,
            'mortgage': 0,
          },
        ],
      },
      'rentalIncome': 0,
    });
    final safe = jsonSafeAnswers(answers);
    expect(safe, isNotEmpty);
    final scheduleE = safe['scheduleE'] as Map<String, dynamic>;
    final props = scheduleE['rentalProperties'] as List<dynamic>;
    expect((props.first as Map)['address'], '1234 Easy Street');
  });

  test('blank direct_deposit scrub collapses to empty map', () {
    final answers = OrganizerSectionMapper.answersForSection('direct_deposit', {});
    final safe = jsonSafeAnswers(answers);
    expect(safe, isEmpty);
  });
}
