/// Human-readable labels for Tessa nextActions (never show raw snake_case types).
class TessaActionLabels {
  TessaActionLabels._();

  static const Map<String, String> _titles = {
    'analyze_form_completeness': 'Analyze form completeness',
    'run_federal_1040_preview': 'Preview Form 1040',
    'run_federal_tax_estimate': 'Federal tax estimate',
    'run_ca540_estimate': 'Preview CA Form 540',
    'run_ca_business_estimate': 'CA business estimate',
    'run_state_workflow_intake': 'State intake checklist',
  };

  /// Chip / button title. Never prefixes with "Run " (types already start with run_).
  static String title(Map<String, dynamic> action) {
    final type = '${action['type'] ?? 'action'}';
    final base = _titles[type] ?? _humanize(type);
    final form = action['form_id'] ?? action['jurisdiction'] ?? action['primary_form_id'];
    if (form != null && '$form'.trim().isNotEmpty && type != 'run_federal_1040_preview') {
      final f = '$form';
      // Suppress redundant suffixes (e.g. CA_Form540 vs "Preview CA Form 540").
      final compactBase = base.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
      final compactForm = f.toLowerCase().replaceAll(RegExp(r'[\s_]'), '');
      if (!compactBase.contains(compactForm) && !compactForm.contains(compactBase.replaceFirst('preview', ''))) {
        return '$base ($f)';
      }
    }
    return base;
  }

  /// User bubble when a chip is tapped.
  static String userPrompt(Map<String, dynamic> action) => 'Run: ${title(action)}';

  static String _humanize(String type) {
    return type
        .replaceFirst(RegExp(r'^run_'), '')
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }
}
