/// Approved bilingual tax glossary (Layer 2). IRS form numbers stay English.
class TaxGlossary {
  TaxGlossary._();

  static const Map<String, Map<String, String>> terms = {
    'filing_status': {
      'en-US': 'Filing status',
      'es-US': 'Estado civil para efectos de la declaración',
    },
    'adjusted_gross_income': {
      'en-US': 'Adjusted gross income',
      'es-US': 'Ingreso bruto ajustado',
    },
    'withholding': {
      'en-US': 'Federal income tax withheld',
      'es-US': 'Impuesto federal sobre los ingresos retenidos',
    },
    'form_w2': {
      'en-US': 'Form W-2 — Wage and Tax Statement',
      'es-US': 'Form W-2 — Declaración de salarios e impuestos',
    },
    'form_1099_nec': {
      'en-US': 'Form 1099-NEC — Nonemployee Compensation',
      'es-US': 'Form 1099-NEC — Compensación a no empleados',
    },
    'organizer': {
      'en-US': 'Tax Organizer',
      'es-US': 'Organizador de impuestos',
    },
    'escalate_human': {
      'en-US': 'Speak with an MKG tax professional',
      'es-US': 'Hablar con un profesional de impuestos de MKG',
    },
  };

  static String term(String key, String locale) {
    final map = terms[key];
    if (map == null) return key;
    return map[locale] ?? map['en-US'] ?? key;
  }

  /// Returns violation messages when Form/Schedule or $ amounts are dropped.
  static List<String> validatePreservedTokens(String source, String translated) {
    final violations = <String>[];
    final formRe = RegExp(r'\b(?:Form|Schedule)\s+[A-Z0-9][A-Z0-9\-]*', caseSensitive: false);
    for (final m in formRe.allMatches(source)) {
      final token = m.group(0)!;
      if (!translated.toLowerCase().contains(token.toLowerCase())) {
        violations.add('Missing preserved token: $token');
      }
    }
    final moneyRe = RegExp(r'\$[\d,]+(?:\.\d{2})?');
    for (final m in moneyRe.allMatches(source)) {
      final token = m.group(0)!;
      if (!translated.contains(token)) {
        violations.add('Missing monetary token: $token');
      }
    }
    return violations;
  }
}
