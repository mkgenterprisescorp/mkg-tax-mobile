import 'us_states.dart';

/// Shared dropdown option lists for Tax Organizer free-text → enum fields.
/// Stored values stay snake_case / IRS codes for web + Laravel parity.

const hsaCoverageOptions = <(String, String)>[
  ('self', 'Self-only'),
  ('family', 'Family'),
];

const accountingMethodOptions = <(String, String)>[
  ('cash', 'Cash'),
  ('accrual', 'Accrual'),
];

const scheduleCBusinessTypeOptions = <(String, String)>[
  ('', '— Select —'),
  ('sole_proprietorship', 'Sole proprietorship'),
  ('single_member_llc', 'Single-member LLC'),
  ('independent_contractor', 'Independent contractor'),
  ('freelancer', 'Freelancer / gig'),
  ('other', 'Other'),
];

const scheduleRFilingStatusOptions = <(String, String)>[
  ('single_under65', 'Single — under 65'),
  ('single_65_or_older', 'Single — 65 or older'),
  ('mfj_both_under65', 'Married filing jointly — both under 65'),
  ('mfj_one_65_or_older', 'Married filing jointly — one 65 or older'),
  ('mfj_both_65_or_older', 'Married filing jointly — both 65 or older'),
  ('mfs_65_or_older', 'Married filing separately — 65+ lived apart'),
  ('qss_65_or_older', 'Qualifying surviving spouse — 65 or older'),
];

const taxYearTypeOptions = <(String, String)>[
  ('calendar', 'Calendar year'),
  ('fiscal', 'Fiscal year'),
];

const form1041EntityTypeOptions = <(String, String)>[
  ('simple_trust', 'Simple trust'),
  ('complex_trust', 'Complex trust'),
  ('decedents_estate', "Decedent's estate"),
  ('estate', 'Estate'),
  ('grantor_trust', 'Grantor trust'),
  ('other', 'Other'),
];

/// CA Form 199 / nonprofit org type (status codes).
const caOrgTypeOptions = <(String, String)>[
  ('', '— Select —'),
  ('501c3', '501(c)(3)'),
  ('501c4', '501(c)(4)'),
  ('501c6', '501(c)(6)'),
  ('501c7', '501(c)(7)'),
  ('527', '527'),
  ('other', 'Other'),
];

/// CalEITC / FTB 3514 filing status (mirrors Form 1040 statuses).
const calEitcFilingStatusOptions = <(String, String)>[
  ('', '— Select —'),
  ('single', 'Single'),
  ('married_joint', 'Married Filing Jointly'),
  ('married_separate', 'Married Filing Separately'),
  ('head_household', 'Head of Household'),
  ('qualifying_widow', 'Qualifying Surviving Spouse'),
];

const partnershipTypeOptions = <(String, String)>[
  ('general', 'General partnership'),
  ('limited', 'Limited partnership'),
  ('llp', 'LLP'),
  ('llc', 'LLC taxed as partnership'),
];

const taxExemptStatusOptions = <(String, String)>[
  ('501c3', '501(c)(3)'),
  ('501c4', '501(c)(4)'),
  ('501c6', '501(c)(6)'),
  ('501c7', '501(c)(7)'),
  ('527', '527'),
  ('other', 'Other'),
];

const nonprofitOrgTypeOptions = <(String, String)>[
  ('corporation', 'Corporation'),
  ('trust', 'Trust'),
  ('association', 'Association'),
  ('other', 'Other'),
];

const yesNoOptions = <(String, String)>[
  ('no', 'No'),
  ('yes', 'Yes'),
];

const bankAccountTypeOptions = <(String, String)>[
  ('checking', 'Checking'),
  ('savings', 'Savings'),
];

const caPaymentMethodOptions = <(String, String)>[
  ('web_pay', 'FTB Web Pay'),
  ('check', 'Check / voucher'),
  ('direct_debit', 'Bank debit'),
  ('electronic', 'Electronic'),
  ('other', 'Other'),
];

const federalPaymentMethodOptions = <(String, String)>[
  ('electronic', 'Electronic / IRS Direct Pay'),
  ('check', 'Check / voucher'),
  ('eftps', 'EFTPS'),
  ('other', 'Other'),
];

const digitalAssetProceedsTypeOptions = <(String, String)>[
  ('cash', 'Cash'),
  ('digital_asset', 'Digital asset'),
  ('other', 'Other'),
];

/// Common IRS Form W-2 Box 12 codes (TY2025).
const w2Box12CodeOptions = <(String, String)>[
  ('', '— None —'),
  ('A', 'A — Uncollected SS or RRTA on tips'),
  ('B', 'B — Uncollected Medicare on tips'),
  ('C', 'C — Taxable cost of group-term life'),
  ('D', 'D — Elective deferrals 401(k)'),
  ('E', 'E — Elective deferrals 403(b)'),
  ('F', 'F — Elective deferrals 408(k)(6) SEP'),
  ('G', 'G — Elective deferrals 457(b)'),
  ('H', 'H — Elective deferrals 501(c)(18)(D)'),
  ('J', 'J — Nontaxable sick pay'),
  ('K', 'K — 20% excise tax on golden parachute'),
  ('L', 'L — Substantiated employee business expense'),
  ('M', 'M — Uncollected SS/RRTA on life insurance'),
  ('N', 'N — Uncollected Medicare on life insurance'),
  ('P', 'P — Excludable moving expense reimbursements'),
  ('Q', 'Q — Nontaxable combat pay'),
  ('R', 'R — Employer contributions to MSA'),
  ('S', 'S — Employee salary reduction SIMPLE'),
  ('T', 'T — Adoption benefits'),
  ('V', 'V — Income from nonstatutory stock options'),
  ('W', 'W — Employer HSA contributions'),
  ('Y', 'Y — Deferrals under 409A'),
  ('Z', 'Z — Income under 409A nonqualified plan'),
  ('AA', 'AA — Designated Roth 401(k)'),
  ('BB', 'BB — Designated Roth 403(b)'),
  ('DD', 'DD — Cost of employer-sponsored health coverage'),
  ('EE', 'EE — Designated Roth 457(b)'),
  ('FF', 'FF — Permitted benefits under QSEHRA'),
  ('GG', 'GG — Income from qualified equity grants'),
  ('HH', 'HH — Aggregate deferrals under 83(i)'),
];

/// Common IRS Form 1099-R Box 7 distribution codes.
const form1099RDistributionCodeOptions = <(String, String)>[
  ('', '— Select —'),
  ('1', '1 — Early distribution, no known exception'),
  ('2', '2 — Early distribution, exception applies'),
  ('3', '3 — Disability'),
  ('4', '4 — Death'),
  ('7', '7 — Normal distribution'),
  ('B', 'B — Designated Roth account distribution'),
  ('G', 'G — Direct rollover'),
  ('H', 'H — Direct rollover to Roth IRA'),
  ('J', 'J — Early Roth distribution, no known exception'),
  ('Q', 'Q — Qualified Roth distribution'),
  ('T', 'T — Roth distribution, exception applies'),
  ('U', 'U — Dividend distribution from ESOP'),
  ('other', 'Other / multiple codes'),
];

/// Normalize a stored enum to a known option key, else [fallback].
String normalizeEnumValue(
  dynamic raw,
  List<(String, String)> options, {
  String fallback = '',
}) {
  if (raw == null) {
    if (options.any((o) => o.$1.isEmpty)) return '';
    return fallback;
  }
  final v = '$raw'.trim().toLowerCase();
  if (v.isEmpty || v == 'null') {
    // Prefer an explicit empty option when present (e.g. W-2 “None”).
    if (options.any((o) => o.$1.isEmpty)) return '';
    return fallback;
  }
  for (final opt in options) {
    if (opt.$1.toLowerCase() == v) return opt.$1;
  }
  // Loose match on labels / longer keys only (avoid IRS single-letter codes).
  if (v.length >= 3) {
    for (final opt in options) {
      if (opt.$1.isEmpty || opt.$1.length <= 2) continue;
      final key = opt.$1.toLowerCase();
      final label = opt.$2.toLowerCase();
      if (v.contains(key) || key.contains(v) || label.contains(v)) {
        return opt.$1;
      }
    }
  }
  return fallback.isNotEmpty
      ? fallback
      : (options.any((o) => o.$1.isEmpty) ? '' : (options.isNotEmpty ? options.first.$1 : ''));
}

/// US state options for incorporation / formation (includes empty).
List<(String, String)> get stateOfIncorporationOptions => [
      ('', '— Select state —'),
      ...usStateOptions,
    ];
