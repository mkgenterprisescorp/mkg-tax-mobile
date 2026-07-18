import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/documents/data/document_extraction_mapper.dart';

void main() {
  const mapper = DocumentExtractionMapper();

  test('applies W-2 wages and rolls up 1040 wages/withholding', () {
    final organizer = <String, dynamic>{
      'w2Forms': <Map<String, dynamic>>[{}],
      'wages': '',
      'taxWithheld': '',
    };
    final next = mapper.applyToOrganizer(
      organizer: organizer,
      documentType: 'W-2',
      fields: {
        'employerName': 'Acme Corp',
        'box1_wagesTips': '52410.37',
        'box2_fedTaxWithheld': '6120.00',
        'employeeSSN': '123-45-6789',
      },
    );
    expect(next['w2Forms'][0]['employerName'], 'Acme Corp');
    expect(next['w2Forms'][0]['box1_wagesTips'], '52410.37');
    expect(next['wages'], '52410.37');
    expect(next['taxWithheld'], '6120.00');
    expect(next['_extractionApplyMeta']['skippedSensitiveKeys'], contains('employeeSSN'));
    expect(next['w2Forms'][0].containsKey('employeeSSN'), isFalse);
  });

  test('applies 1040 identity fields without SSN autofill', () {
    final next = mapper.applyToOrganizer(
      organizer: {'firstName': '', 'lastName': '', 'wages': ''},
      documentType: '1040',
      fields: {
        'firstName': 'Alex',
        'lastName': 'Taxpayer',
        'wages': '50000',
        'ssn': '111-22-3333',
      },
    );
    expect(next['firstName'], 'Alex');
    expect(next['lastName'], 'Taxpayer');
    expect(next['wages'], '50000');
    expect(next.containsKey('ssn'), isFalse);
  });
}
