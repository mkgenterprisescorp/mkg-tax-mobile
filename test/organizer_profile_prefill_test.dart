import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/organizer_profile_prefill.dart';

void main() {
  test('applyTo fills empty organizer fields without overwriting typed values', () {
    const prefill = OrganizerProfilePrefill(
      firstName: 'MKG',
      lastName: 'DoNotReply',
      email: 'mkgtaxdonotreply@gmail.com',
      phone: '559-309-3260',
      address: '4021 North Fresno Street',
      city: 'Fresno',
      state: 'CA',
      zip: '93726',
    );

    final filled = prefill.applyTo({
      'firstName': '',
      'lastName': 'KeepMe',
      'email': '',
      'city': 'Clovis',
    });
    expect(filled['firstName'], 'MKG');
    expect(filled['lastName'], 'KeepMe');
    expect(filled['email'], 'mkgtaxdonotreply@gmail.com');
    expect(filled['city'], 'Clovis');
    expect(filled['state'], 'CA');
    expect(filled['zip'], '93726');

    final overwritten = prefill.applyTo({
      'firstName': 'Old',
      'city': 'Clovis',
    }, overwrite: true);
    expect(overwritten['firstName'], 'MKG');
    expect(overwritten['city'], 'Fresno');
  });
}
