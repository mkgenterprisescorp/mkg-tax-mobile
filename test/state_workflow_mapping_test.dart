import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/organizer/data/us_states.dart';
import 'package:mkg_tax_mobile/features/states/data/state_workflow_repository.dart';

void main() {
  test('prepType maps to nationwide return families', () {
    expect(returnFamilyForPrepType('personal'), 'individual');
    expect(returnFamilyForPrepType('form1120'), 'corporation');
    expect(returnFamilyForPrepType('form1120S'), 's_corporation');
    expect(returnFamilyForPrepType('form1065'), 'partnership');
    expect(returnFamilyForPrepType('form1041'), 'fiduciary');
    expect(returnFamilyForPrepType('form990'), 'exempt_organization');
    expect(returnFamilyForPrepType('form990EZ'), 'exempt_organization_ez');
  });

  test('residency maps to engine filing types', () {
    expect(filingTypeForResidency('resident'), 'resident');
    expect(filingTypeForResidency('part_year'), 'part_year');
    expect(filingTypeForResidency('nonresident'), 'nonresident');
  });

  test('business state return scaffold excludes CA defaults', () {
    final row = emptyBusinessStateReturn(stateCode: 'TX', returnFamily: 'corporation');
    expect(row['stateCode'], 'TX');
    expect(row['returnFamily'], 'corporation');
    expect(row['workflowAnswers'], isA<Map>());
  });
}
