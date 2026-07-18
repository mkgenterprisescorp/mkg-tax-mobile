/// Deterministic State Tax Regime Classifier (Dart mirror of Laravel / engine).
/// Authoritative: GET /api/v1/states/{code}/tax-profile

const noBroadPersonalIncomeTax = <String>{
  'AK', 'FL', 'NV', 'NH', 'SD', 'TN', 'TX', 'WA', 'WY',
};

const noCorporateIncomeTax = <String>{'NV', 'OH', 'SD', 'TX', 'WA', 'WY'};

const alternativeBusinessTax = <String, Map<String, String>>{
  'NV': {'kind': 'commerce_tax', 'name': 'Nevada Commerce Tax', 'loader': 'loadCommerceTax'},
  'OH': {'kind': 'commercial_activity_tax', 'name': 'Ohio Commercial Activity Tax (CAT)', 'loader': 'loadCommercialActivityTax'},
  'TX': {'kind': 'franchise_margin_tax', 'name': 'Texas Franchise (Margin) Tax', 'loader': 'loadTexasFranchiseTax'},
  'WA': {'kind': 'business_occupation_tax', 'name': 'Washington Business & Occupation (B&O) Tax', 'loader': 'loadBusinessOccupationTax'},
};

class StateTaxProfile {
  const StateTaxProfile({
    required this.state,
    required this.personalIncomeTax,
    required this.corporateIncomeTax,
    required this.franchiseTax,
    required this.capitalGainsTax,
    required this.salesTax,
    required this.commerceTax,
    required this.businessOccupationTax,
    required this.noCorpAndNoBroadGrt,
    required this.alternativeBusinessTaxName,
  });

  final String state;
  final bool personalIncomeTax;
  final bool corporateIncomeTax;
  final bool franchiseTax;
  final bool capitalGainsTax;
  final bool salesTax;
  final bool commerceTax;
  final bool businessOccupationTax;
  final bool noCorpAndNoBroadGrt;
  final String? alternativeBusinessTaxName;
}

StateTaxProfile buildStateTaxProfile(String code) {
  final state = code.toUpperCase();
  final alt = alternativeBusinessTax[state];
  final pit = !noBroadPersonalIncomeTax.contains(state);
  final cit = !noCorporateIncomeTax.contains(state);
  return StateTaxProfile(
    state: state,
    personalIncomeTax: pit,
    corporateIncomeTax: cit,
    franchiseTax: alt?['kind'] == 'franchise_margin_tax' || state == 'TN' || state == 'DE',
    capitalGainsTax: state == 'WA',
    salesTax: !const {'AK', 'DE', 'MT', 'NH', 'OR'}.contains(state),
    commerceTax: state == 'NV',
    businessOccupationTax: state == 'WA',
    noCorpAndNoBroadGrt: state == 'SD' || state == 'WY',
    alternativeBusinessTaxName: alt?['name'],
  );
}

bool shouldShowResidentPersonalWorkflow(String code) =>
    buildStateTaxProfile(code).personalIncomeTax;

List<String> workflowChipLabels(String code) {
  final p = buildStateTaxProfile(code);
  final chips = <String>['Federal Return'];
  if (p.personalIncomeTax) {
    chips.add('Personal Income Tax');
  } else {
    chips.add('No resident PIT');
  }
  if (p.capitalGainsTax) chips.add('Capital Gains Tax');
  if (p.corporateIncomeTax) {
    chips.add('Corporate Income Tax');
  } else if (p.alternativeBusinessTaxName != null) {
    chips.add(p.alternativeBusinessTaxName!);
  } else if (p.noCorpAndNoBroadGrt) {
    chips.add('Annual Reports / Entity');
  }
  if (p.salesTax) chips.add('Sales & Use Tax');
  chips.add('Employer Taxes');
  return chips;
}
