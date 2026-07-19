import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';

void main() {
  test('fromLaravelProfile maps mailing address and soft-gate KYC status', () {
    final user = PortalUser.fromLaravelProfile({
      'external_user_id': 'user-1',
      'email': 'a@example.com',
      'name': 'Ada Lovelace',
      'phone': '5551112222',
      'approval_status': 'approved',
      'mailing_address': {
        'line1': '4021 North Fresno Street',
        'line2': '107',
        'city': 'Fresno',
        'state': 'CA',
        'postal_code': '93726',
      },
      'verification': {'email': true, 'phone': false},
      'version': 3,
    });

    expect(user.email, 'a@example.com');
    expect(user.phone, '5551112222');
    expect(user.address, '4021 North Fresno Street');
    expect(user.city, 'Fresno');
    expect(user.state, 'CA');
    expect(user.zipCode, '93726');
    expect(user.approvalStatus, 'approved');
    expect(user.kycStatus, 'approved');
  });

  test('fromLaravelProfile marks submitted when address present and not approved', () {
    final user = PortalUser.fromLaravelProfile({
      'external_user_id': 'user-2',
      'email': 'b@example.com',
      'name': 'Grace Hopper',
      'approval_status': 'pending',
      'mailing_address': {
        'line1': '1 Main St',
        'city': 'Oakland',
        'state': 'CA',
        'postal_code': '94607',
      },
    });
    expect(user.kycStatus, 'submitted');
    expect(user.approvalStatus, 'pending');
  });
}
