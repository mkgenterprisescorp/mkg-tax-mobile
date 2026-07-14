import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/auth/app_roles.dart';

void main() {
  test('client role maps to consumer edition', () {
    final caps = capabilitiesFor('client');
    expect(caps.edition, AppEdition.consumer);
    expect(caps.canManageClients, isFalse);
    expect(caps.canManageAllReturns, isFalse);
    expect(caps.canUseIeroTools, isFalse);
  });

  test('tax preparer maps to professional edition', () {
    final caps = capabilitiesFor('tax_preparer');
    expect(caps.edition, AppEdition.professional);
    expect(caps.canManageClients, isTrue);
    expect(caps.canManageAllReturns, isTrue);
    expect(caps.canUseIeroTools, isTrue);
  });

  test('admin is professional + admin', () {
    final caps = capabilitiesFor('super_user');
    expect(caps.isProfessional, isTrue);
    expect(caps.isAdmin, isTrue);
  });
}
