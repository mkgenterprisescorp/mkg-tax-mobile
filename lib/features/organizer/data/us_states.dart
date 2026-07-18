/// US states + DC for multi-state organizer intake (parity with web Organizer).
const usStateOptions = <(String, String)>[
  ('AL', 'Alabama'),
  ('AK', 'Alaska'),
  ('AZ', 'Arizona'),
  ('AR', 'Arkansas'),
  ('CA', 'California'),
  ('CO', 'Colorado'),
  ('CT', 'Connecticut'),
  ('DE', 'Delaware'),
  ('DC', 'District of Columbia'),
  ('FL', 'Florida'),
  ('GA', 'Georgia'),
  ('HI', 'Hawaii'),
  ('ID', 'Idaho'),
  ('IL', 'Illinois'),
  ('IN', 'Indiana'),
  ('IA', 'Iowa'),
  ('KS', 'Kansas'),
  ('KY', 'Kentucky'),
  ('LA', 'Louisiana'),
  ('ME', 'Maine'),
  ('MD', 'Maryland'),
  ('MA', 'Massachusetts'),
  ('MI', 'Michigan'),
  ('MN', 'Minnesota'),
  ('MS', 'Mississippi'),
  ('MO', 'Missouri'),
  ('MT', 'Montana'),
  ('NE', 'Nebraska'),
  ('NV', 'Nevada'),
  ('NH', 'New Hampshire'),
  ('NJ', 'New Jersey'),
  ('NM', 'New Mexico'),
  ('NY', 'New York'),
  ('NC', 'North Carolina'),
  ('ND', 'North Dakota'),
  ('OH', 'Ohio'),
  ('OK', 'Oklahoma'),
  ('OR', 'Oregon'),
  ('PA', 'Pennsylvania'),
  ('RI', 'Rhode Island'),
  ('SC', 'South Carolina'),
  ('SD', 'South Dakota'),
  ('TN', 'Tennessee'),
  ('TX', 'Texas'),
  ('UT', 'Utah'),
  ('VT', 'Vermont'),
  ('VA', 'Virginia'),
  ('WA', 'Washington'),
  ('WV', 'West Virginia'),
  ('WI', 'Wisconsin'),
  ('WY', 'Wyoming'),
];

/// States/DC with a personal income tax (web Organizer `STATES_WITH_INCOME_TAX`).
/// Count: 41 states + DC = 42 jurisdictions.
const statesWithIncomeTax = <String>{
  'AL', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY',
  'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH',
  'OK', 'OR', 'PA', 'RI', 'SC', 'UT', 'VT', 'VA', 'WV', 'WI',
};

/// Income-tax jurisdictions as dropdown options (sorted by name).
List<(String, String)> get incomeTaxStateOptions => [
      for (final opt in usStateOptions)
        if (statesWithIncomeTax.contains(opt.$1)) opt,
    ];

const residencyTypeOptions = <(String, String)>[
  ('resident', 'Full-year resident'),
  ('part_year', 'Part-year resident'),
  ('nonresident', 'Nonresident'),
];

String displayNameForState(String code) {
  for (final opt in usStateOptions) {
    if (opt.$1 == code) return opt.$2;
  }
  return code;
}

Map<String, dynamic> emptyAdditionalStateReturn({
  String stateCode = 'NY',
  String residencyType = 'nonresident',
}) =>
    {
      'stateCode': stateCode,
      'residencyType': residencyType,
      'reason': '',
      'wages': 0,
      'withholding': 0,
      'estimatedPayments': 0,
      'filingRequired': statesWithIncomeTax.contains(stateCode),
      'professionalReview': stateCode != 'CA',
      'hasPersonalIncomeTax': statesWithIncomeTax.contains(stateCode),
    };
