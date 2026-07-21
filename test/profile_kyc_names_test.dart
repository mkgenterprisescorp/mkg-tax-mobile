import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

void main() {
  test('fromLaravelProfile maps first_name and last_name', () {
    final user = PortalUser.fromLaravelProfile({
      'external_user_id': 'u1',
      'email': 'ada@example.com',
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'preferred_name': 'Ada',
      'name': 'Ada Lovelace',
      'phone': '555',
      'mailing_address': {
        'line1': '1 Main',
        'city': 'Clovis',
        'state': 'CA',
        'postal_code': '93611',
      },
      'approval_status': 'pending',
      'verification': {'email': true, 'phone': false},
      'kyc_status': 'submitted',
    });
    expect(user.firstName, 'Ada');
    expect(user.lastName, 'Lovelace');
    expect(user.displayName, 'Ada Lovelace');
    expect(user.kycStatus, 'submitted');
  });
}
