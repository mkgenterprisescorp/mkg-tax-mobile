import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_defaults.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default form data includes Schedule C/E and entity forms', () async {
    final raw = await rootBundle.loadString('assets/organizer/default_form_data.json');
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);

    expect(data['prepType'], 'personal');
    expect(data['scheduleC'], isA<Map>());
    expect(data['scheduleC']['businessName'], '');
    expect(data['scheduleE']['rentalProperties'], isA<List>());
    expect(data['form1120'], isA<Map>());
    expect(data['form1120S'], isA<Map>());
    expect(data['form1065'], isA<Map>());
    expect(data['form990EZ'], isA<Map>());
    expect(data['scheduleA']['medicalExpenses'], 0);
  });

  test('prepType steps match web Organizer', () {
    expect(stepsForPrepType('personal').length, 8);
    expect(stepsForPrepType('business').contains('Schedule C'), isTrue);
    expect(stepsForPrepType('form1120'), [
      'Filing Info',
      'Form 1120 - C-Corporation',
      'Direct Deposit',
      'Review & Sign',
    ]);
    expect(stepsForPrepType('form990EZ').length, 4);
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
}
