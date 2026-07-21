import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_business_autofill.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_defaults.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ownerFromPersonalInfo copies identity onto owner row', () {
    final owner = ownerFromPersonalInfo(
      {
        'firstName': 'Pat',
        'middleInitial': 'Q',
        'lastName': 'Lee',
        'ssn': '123-45-6789',
        'address': '1 Main St',
        'apartment': '2B',
        'city': 'Oakland',
        'state': 'CA',
        'zip': '94612',
        'phone': '510-555-0100',
        'email': 'pat@example.com',
      },
      role: 'partner',
    );
    expect(owner['name'], 'Pat Q Lee');
    expect(owner['tin'], '123-45-6789');
    expect(owner['address'], '1 Main St 2B');
    expect(owner['city'], 'Oakland');
    expect(owner['state'], 'CA');
    expect(owner['zip'], '94612');
    expect(owner['role'], 'partner');
    expect(owner['isPrimary'], isTrue);
    expect(owner['ownershipPercentage'], 100);
  });

  test('addBusinessWithOwnerAutofill seeds 1120-S owner, K-1, and Schedule E Part II', () {
    final data = addBusinessWithOwnerAutofill(
      {
        'prepType': 'personal',
        'firstName': 'Alex',
        'lastName': 'Rivera',
        'ssn': '111-22-3333',
        'address': '9 Market',
        'city': 'San Jose',
        'state': 'CA',
        'zip': '95113',
        'scheduleE': {'rentalProperties': <dynamic>[], 'partII': <dynamic>[]},
        'federalK1Forms': <dynamic>[],
      },
      'form1120S',
      entityDefaults: {
        'form1120S': {
          'corporationName': 'Rivera Labs Inc',
          'ein': '98-7654321',
          'numberOfShareholders': 0,
          'owners': <dynamic>[],
          'scheduleK_ordinaryBusinessIncome': 20000,
          'scheduleK_netRentalIncome': 1000,
        },
      },
      switchPrepType: false,
    );

    expect(data['prepType'], 'personal');
    final form = data['form1120S'] as Map;
    final owners = form['owners'] as List;
    expect(owners, isNotEmpty);
    expect(owners.first['name'], 'Alex Rivera');
    expect(owners.first['tin'], '111-22-3333');
    expect(form['numberOfShareholders'], 1);

    final k1s = data['federalK1Forms'] as List;
    expect(k1s, hasLength(1));
    expect(k1s.first['sourceForm'], 'form1120S');
    expect(k1s.first['entityName'], 'Rivera Labs Inc');
    expect(k1s.first['partnerOrShareholderName'], 'Alex Rivera');
    expect(k1s.first['ordinaryIncome'], 20000);
    expect(k1s.first['netRentalRealEstate'], 1000);

    final partII = (data['scheduleE'] as Map)['partII'] as List;
    expect(partII, hasLength(1));
    expect(partII.first['entityType'], 's_corporation');
    expect(partII.first['ordinaryIncome'], 20000);
    expect(partII.first['sourceK1Id'], k1s.first['id']);
    expect(data['rentalIncome'], 21000);
  });

  test('addBusinessWithOwnerAutofill for 1065 keeps 1040 and links partnership Part II', () {
    final data = addBusinessWithOwnerAutofill(
      {
        'prepType': 'personal',
        'firstName': 'Sam',
        'lastName': 'Nguyen',
        'ssn': '222-33-4444',
      },
      'form1065',
      entityDefaults: {
        'form1065': {
          'partnershipName': 'Nguyen Partners',
          'ein': '12-3456789',
          'owners': <dynamic>[],
          'scheduleK_ordinaryBusinessIncome': 5000,
        },
      },
    );
    expect(data['prepType'], 'personal');
    expect((data['form1065'] as Map)['owners'], isNotEmpty);
    expect((data['federalK1Forms'] as List).first['sourceForm'], 'form1065');
    expect(
      ((data['scheduleE'] as Map)['partII'] as List).first['entityType'],
      'partnership',
    );
  });

  test('1120 autofills owner but does not create Schedule E Part II K-1', () {
    final data = addBusinessWithOwnerAutofill(
      {
        'prepType': 'personal',
        'firstName': 'Chris',
        'lastName': 'Park',
        'ssn': '333-44-5555',
        'scheduleE': {'rentalProperties': <dynamic>[], 'partII': <dynamic>[]},
        'federalK1Forms': <dynamic>[],
      },
      'form1120',
      entityDefaults: {
        'form1120': {'corporationName': 'Park Corp', 'owners': <dynamic>[]},
      },
    );
    expect((data['form1120'] as Map)['owners'].first['name'], 'Chris Park');
    expect(data['federalK1Forms'], isEmpty);
    expect((data['scheduleE'] as Map)['partII'], isEmpty);
  });

  test('syncK1ToScheduleEPartII updates linked Part II when K-1 amounts change', () {
    final seeded = addBusinessWithOwnerAutofill(
      {
        'firstName': 'Dana',
        'lastName': 'Kim',
        'ssn': '444-55-6666',
      },
      'form1065',
      entityDefaults: {
        'form1065': {
          'partnershipName': 'Kim LLC',
          'ein': '11-1111111',
          'owners': <dynamic>[],
        },
      },
    );
    final k1s = List<Map<String, dynamic>>.from(
      (seeded['federalK1Forms'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    k1s[0]['ordinaryIncome'] = 7500;
    k1s[0]['guaranteedPayments'] = 2500;
    final synced = syncK1ToScheduleEPartII({
      ...seeded,
      'federalK1Forms': k1s,
    });
    final partII = (synced['scheduleE'] as Map)['partII'] as List;
    expect(partII.first['ordinaryIncome'], 7500);
    expect(partII.first['guaranteedPayments'], 2500);
    expect(synced['rentalIncome'], 10000);
  });

  test('defaults include scheduleE.partII, federalK1Forms, and entity owners', () async {
    final data = await OrganizerDefaults.load();
    expect(data['scheduleE']['partII'], isA<List>());
    expect(data['federalK1Forms'], isA<List>());
    expect(data['form1065']['owners'], isA<List>());
    expect(data['form1120S']['owners'], isA<List>());
    expect(data['form1120']['owners'], isA<List>());
    expect(data['form1041']['owners'], isA<List>());
  });
}
