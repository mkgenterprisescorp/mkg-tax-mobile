import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/tessa/data/tessa_repository.dart';

void main() {
  test('TessaMessageResult carries nextActions for form automation', () {
    const result = TessaMessageResult(
      reply: 'Mapped Form1040 and CA_Form540',
      source: 'tessa_form_assist',
      nextActions: [
        {'type': 'run_federal_1040_preview'},
        {'type': 'run_ca540_estimate'},
      ],
      formPlan: {
        'required_forms': ['Form1040'],
        'state_returns': ['CA_Form540'],
      },
    );
    expect(result.nextActions.length, 2);
    expect(result.formPlan['required_forms'], contains('Form1040'));
    expect(result.source, 'tessa_form_assist');
  });
}
