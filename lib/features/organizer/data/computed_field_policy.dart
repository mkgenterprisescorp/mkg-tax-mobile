import '../data/official_form_links.dart';

/// Who may unlock a computed field for manual entry.
enum ComputedLockLevel {
  /// Consumers may override after an explicit warning; pros may unlock freely.
  consumerOverrideAllowed,

  /// Only tax professionals may unlock (due-diligence / knowledge-base guidance).
  professionalOnly,
}

/// In-app due-diligence guidance (knowledge-base lite) for locked computed fields.
class ComputedFieldGuidance {
  const ComputedFieldGuidance({
    required this.title,
    required this.body,
    this.officialLabel,
    this.officialUrl,
    this.checklist = const [],
  });

  final String title;
  final String body;
  final String? officialLabel;
  final String? officialUrl;
  final List<String> checklist;
}

/// Catalog of workflow-computed Form 1040 / CA 540 fields.
class ComputedFieldPolicy {
  const ComputedFieldPolicy({
    required this.key,
    required this.label,
    required this.lockLevel,
    required this.guidance,
    this.formLine,
  });

  final String key;
  final String label;
  final ComputedLockLevel lockLevel;
  final ComputedFieldGuidance guidance;
  final String? formLine;

  static const federalAgi = ComputedFieldPolicy(
    key: 'federalAGI',
    label: 'Federal AGI',
    formLine: 'Form 1040 Line 11 / CA 540 Line 13',
    lockLevel: ComputedLockLevel.professionalOnly,
    guidance: ComputedFieldGuidance(
      title: 'Federal AGI due diligence',
      body:
          'Federal AGI is auto-calculated from W-2/1099 income minus Schedule 1 adjustments. '
          'Only a tax professional should override after reconciling Forms W-2, 1099, and Schedule 1.',
      officialLabel: 'IRS Form 1040 instructions',
      officialUrl: OfficialFormLinks.form1040Instructions,
      checklist: [
        'Confirm W-2 Box 1 wages and 1099 totals match the Income step',
        'Confirm Schedule 1 adjustments (HSA, SE tax, student loan, etc.)',
        'Document why the calculated AGI is incorrect before overriding',
      ],
    ),
  );

  static const wages = ComputedFieldPolicy(
    key: 'wages',
    label: 'Wages (Form 1040 Line 1a)',
    formLine: 'Form 1040 Line 1a',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override wages total?',
      body:
          'Wages are auto-filled from W-2 Box 1. Override only if a W-2 is missing from the list '
          'or a correction is needed. Prefer fixing the W-2 entry first.',
      officialLabel: 'IRS Form W-2',
      officialUrl: OfficialFormLinks.formW2,
      checklist: [
        'Add or correct the W-2 under Income before overriding',
        'Keep paper W-2 support for the preparer',
      ],
    ),
  );

  static const taxWithheld = ComputedFieldPolicy(
    key: 'taxWithheld',
    label: 'Total federal withheld',
    formLine: 'Form 1040 Lines 25a–25b',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override federal withholding?',
      body:
          'Withholding is auto-filled from W-2 Box 2 and 1099 federal tax withheld. '
          'Override only after checking each form.',
      officialLabel: 'IRS Form 1040',
      officialUrl: OfficialFormLinks.form1040,
      checklist: ['Match Box 2 / Box 4 withholding on each income form'],
    ),
  );

  static const interestIncome = ComputedFieldPolicy(
    key: 'interestIncome',
    label: 'Taxable interest',
    formLine: 'Form 1040 Line 2b',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override taxable interest?',
      body: 'Interest is auto-filled from Form 1099-INT / Schedule B payers.',
      officialLabel: 'IRS Form 1099-INT',
      officialUrl: OfficialFormLinks.form1099Int,
    ),
  );

  static const dividendIncome = ComputedFieldPolicy(
    key: 'dividendIncome',
    label: 'Ordinary dividends',
    formLine: 'Form 1040 Line 3b',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override ordinary dividends?',
      body: 'Dividends are auto-filled from Form 1099-DIV / Schedule B.',
      officialLabel: 'IRS Form 1099-DIV',
      officialUrl: OfficialFormLinks.form1099Div,
    ),
  );

  static const capitalGains = ComputedFieldPolicy(
    key: 'capitalGains',
    label: 'Capital gain or loss',
    formLine: 'Form 1040 Line 7',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override capital gain/loss?',
      body: 'Auto-filled from Forms 1099-B / 1099-DA. Prefer correcting broker rows first.',
      officialLabel: 'IRS Schedule D',
      officialUrl: OfficialFormLinks.scheduleD,
    ),
  );

  static const businessIncome = ComputedFieldPolicy(
    key: 'businessIncome',
    label: 'Business income',
    formLine: 'Schedule C / Form 1040 Sch. 1',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override business income?',
      body: 'Auto-filled from 1099-NEC / 1099-K when those forms are entered.',
      officialLabel: 'IRS Schedule C',
      officialUrl: OfficialFormLinks.scheduleC,
    ),
  );

  static const caWithholding = ComputedFieldPolicy(
    key: 'caWithholding',
    label: 'CA income tax withheld',
    formLine: 'CA Form 540 Line 71',
    lockLevel: ComputedLockLevel.consumerOverrideAllowed,
    guidance: ComputedFieldGuidance(
      title: 'Override CA withholding?',
      body: 'Auto-filled from W-2 Box 17 (CA) when available. Confirm each CA W-2 before overriding.',
      officialLabel: '2025 Form 540 booklet',
      officialUrl: OfficialFormLinks.ca540Booklet,
    ),
  );

  static const caTaxableIncome = ComputedFieldPolicy(
    key: 'taxableIncome',
    label: 'CA taxable income',
    formLine: 'CA Form 540 Line 19',
    lockLevel: ComputedLockLevel.professionalOnly,
    guidance: ComputedFieldGuidance(
      title: 'CA taxable income due diligence',
      body:
          'Taxable income is calculated from CA AGI minus the standard or itemized deduction. '
          'Professionals should unlock only after reviewing Schedule CA and deduction elections.',
      officialLabel: '2025 Form 540 instructions',
      officialUrl: OfficialFormLinks.ca540Instructions,
      checklist: [
        'Verify federal AGI and Schedule CA additions/subtractions',
        'Confirm standard vs itemized deduction election',
      ],
    ),
  );

  static const caTax = ComputedFieldPolicy(
    key: 'caTax',
    label: 'CA tax',
    formLine: 'CA Form 540 Line 31',
    lockLevel: ComputedLockLevel.professionalOnly,
    guidance: ComputedFieldGuidance(
      title: 'CA tax due diligence',
      body:
          'CA tax is calculated from the TY2025 rate schedule. Unlock only to enter a staff-reviewed figure '
          'from tax software or FTB worksheets.',
      officialLabel: '2025 Form 540 PDF',
      officialUrl: OfficialFormLinks.ca540Pdf,
      checklist: [
        'Reconcile taxable income before overriding tax',
        'Note the software/source used for the override',
      ],
    ),
  );

  static List<ComputedFieldPolicy> get federalIncomeRollups => const [
        wages,
        interestIncome,
        dividendIncome,
        capitalGains,
        businessIncome,
        taxWithheld,
      ];

  /// Read override map from organizer / nested form data.
  static Map<String, dynamic> overridesOf(Map<String, dynamic> data) =>
      Map<String, dynamic>.from((data['computedOverrides'] as Map?) ?? const {});

  static bool isOverridden(Map<String, dynamic> data, String key) {
    final entry = overridesOf(data)[key];
    if (entry is Map) return entry['manual'] == true;
    return entry == true;
  }

  static Map<String, dynamic> markOverridden(
    Map<String, dynamic> data,
    String key, {
    required bool byProfessional,
  }) {
    final next = Map<String, dynamic>.from(data);
    final overrides = overridesOf(next);
    overrides[key] = {
      'manual': true,
      'byProfessional': byProfessional,
      'at': DateTime.now().toIso8601String(),
    };
    next['computedOverrides'] = overrides;
    return next;
  }

  static Map<String, dynamic> clearOverride(Map<String, dynamic> data, String key) {
    final next = Map<String, dynamic>.from(data);
    final overrides = overridesOf(next)..remove(key);
    next['computedOverrides'] = overrides;
    return next;
  }

  /// Assign [value] to [key] unless the field was manually overridden.
  static void assignUnlessOverridden(Map<String, dynamic> data, String key, dynamic value) {
    if (isOverridden(data, key)) return;
    data[key] = value;
  }
}
