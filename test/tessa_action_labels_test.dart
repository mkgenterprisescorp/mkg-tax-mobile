import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/features/tessa/presentation/tessa_action_labels.dart';

void main() {
  test('titles are human-readable and never raw snake_case chips', () {
    expect(
      TessaActionLabels.title({'type': 'run_federal_1040_preview'}),
      'Preview Form 1040',
    );
    expect(
      TessaActionLabels.title({'type': 'run_federal_tax_estimate'}),
      'Federal tax estimate',
    );
    expect(
      TessaActionLabels.title({'type': 'run_ca540_estimate', 'form_id': 'CA_Form540'}),
      'Preview CA Form 540',
    );
    expect(
      TessaActionLabels.title({'type': 'analyze_form_completeness'}),
      'Analyze form completeness',
    );
  });

  test('userPrompt does not double-prefix run_', () {
    final prompt = TessaActionLabels.userPrompt({'type': 'run_federal_tax_estimate'});
    expect(prompt, 'Run: Federal tax estimate');
    expect(prompt.contains('run_run_'), isFalse);
    expect(prompt.contains('Run run_'), isFalse);
  });
}
