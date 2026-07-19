import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/official_form_links.dart';
import '../data/organizer_credits_math.dart';
import 'organizer_fields.dart';

/// Full federal credits & deductions intake aligned to Form 1040 (TY2025)
/// and `assets/organizer/default_form_data.json` schemas.
class OrganizerCreditsStep extends StatelessWidget {
  const OrganizerCreditsStep({
    super.key,
    required this.data,
    required this.onRoot,
    required this.onNested,
    required this.onPatch,
  });

  final Map<String, dynamic> data;
  final void Function(String key, dynamic value) onRoot;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;
  /// Merge multiple root/nested updates in one autosave cycle (with rollups).
  final void Function(Map<String, dynamic> patch) onPatch;

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from((data[key] as Map?) ?? {});

  void _setNestedAndRollup(String nestKey, Map<String, dynamic> value) {
    final next = Map<String, dynamic>.from(data)..[nestKey] = value;
    onPatch(applyCreditsRollups(next));
  }

  void _setRootAndRollup(String key, dynamic value) {
    final next = Map<String, dynamic>.from(data)..[key] = value;
    onPatch(applyCreditsRollups(next));
  }

  @override
  Widget build(BuildContext context) {
    final scheduleA = _map('scheduleA');
    final schedule1 = _map('schedule1');
    final schedule1A = _map('schedule1A');
    final schedule2 = _map('schedule2');
    final schedule3 = _map('schedule3');
    final scheduleSE = _map('scheduleSE');
    final schedule8812 = _map('schedule8812');
    final scheduleH = _map('scheduleH');
    final scheduleR = _map('scheduleR');
    final form8889 = _map('form8889');
    final form8863 = _map('form8863');
    final form5695 = _map('form5695');
    final form8995 = _map('form8995');
    final form8839 = _map('form8839');
    final form2441 = _map('form2441');

    return Column(
      children: [
        OfficialFormLinksCard(
          title: 'Official Form 1040 references',
          subtitle: 'Credits & deductions map to these IRS schedules and forms.',
          links: const [
            ('Form 1040', OfficialFormLinks.form1040Pdf),
            ('Schedule 1 (adjustments)', OfficialFormLinks.schedule1Pdf),
            ('Schedule A (itemized)', OfficialFormLinks.scheduleAPdf),
            ('Schedule 8812 (CTC/ACTC)', OfficialFormLinks.schedule8812Pdf),
            ('Schedule 3 (credits)', OfficialFormLinks.schedule3Pdf),
          ],
        ),
        const SizedBox(height: 18),
        OrganizerSection(
          title: 'Schedule 1 — Adjustments to income',
          subtitle: 'Form 1040 Line 10 ← Schedule 1, line 26. Enter above-the-line deductions here (not HSA on health insurance premiums).',
          child: Column(
            children: [
              NestedMapEditor(
                data: schedule1,
                onlyKeys: const [
                  'educatorExpenses',
                  'hsaDeduction',
                  'selfEmploymentTax',
                  'sepSimpleQualifiedPlans',
                  'selfEmployedHealthInsurance',
                  'studentLoanInterest',
                  'iraDeduction',
                  'movingExpenses',
                  'alimonyPaid',
                  'alimonyPaidRecipientSSN',
                  'otherAdjustments',
                  'totalAdjustments',
                ],
                labels: const {
                  'educatorExpenses': 'Educator expenses (Sch. 1 → Line 10)',
                  'hsaDeduction': 'HSA deduction (Form 8889 → Sch. 1 → Line 10)',
                  'selfEmploymentTax': '½ SE tax deductible (Sch. SE → Sch. 1 → Line 10)',
                  'sepSimpleQualifiedPlans': 'SEP/SIMPLE/qualified plans (Sch. 1 → Line 10)',
                  'selfEmployedHealthInsurance': 'Self-employed health insurance (Sch. 1 → Line 10)',
                  'studentLoanInterest': 'Student loan interest (Sch. 1 → Line 10)',
                  'iraDeduction': 'IRA deduction (Sch. 1 → Line 10)',
                  'movingExpenses': 'Moving expenses — Armed Forces (Sch. 1 → Line 10)',
                  'alimonyPaid': 'Alimony paid (Sch. 1 → Line 10)',
                  'otherAdjustments': 'Other adjustments (Sch. 1 → Line 10)',
                  'totalAdjustments': 'Total adjustments (Sch. 1 line 26 → Form 1040 Line 10)',
                },
                onChanged: (m) => _setNestedAndRollup('schedule1', m),
              ),
            ],
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8889 — Health Savings Account',
          subtitle: 'HSA deduction flows to Schedule 1, then Form 1040 Line 10. Do not use “health insurance premiums” for HSA.',
          builder: (_) => NestedMapEditor(
            data: form8889,
            onlyKeys: const [
              'hsaCoverage',
              'hsaContributions',
              'employerContributions',
              'hsaDeduction',
              'qualifiedDistributions',
              'totalDistributions',
              'excessContributions',
              'highDeductiblePlan',
            ],
            labels: const {
              'hsaCoverage': 'HSA coverage (self / family)',
              'hsaContributions': 'HSA contributions (Form 8889)',
              'employerContributions': 'Employer HSA contributions',
              'hsaDeduction': 'HSA deduction → Sch. 1 / Form 1040 Line 10',
              'qualifiedDistributions': 'Qualified medical distributions',
              'totalDistributions': 'Total HSA distributions',
              'excessContributions': 'Excess contributions',
              'highDeductiblePlan': 'Covered by HDHP',
            },
            onChanged: (m) => _setNestedAndRollup('form8889', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule SE — Self-employment tax',
          subtitle: 'SE tax → Form 1040 Line 23 (via Schedule 2). Deductible half → Schedule 1 / Line 10.',
          builder: (_) => NestedMapEditor(
            data: scheduleSE,
            onlyKeys: const [
              'netProfitScheduleC',
              'netProfitPartnership',
              'farmIncome',
              'churchEmployeeIncome',
              'netEarnings',
              'selfEmploymentTax',
              'deductiblePart',
              'shortSchedule',
            ],
            labels: const {
              'netProfitScheduleC': 'Net profit from Schedule C',
              'netProfitPartnership': 'Net profit from partnerships',
              'farmIncome': 'Farm income (Schedule F)',
              'churchEmployeeIncome': 'Church employee income',
              'netEarnings': 'Net earnings from SE (× 92.35%)',
              'selfEmploymentTax': 'SE tax → Sch. 2 / Form 1040 Line 23',
              'deductiblePart': 'Deductible part of SE tax → Sch. 1 / Line 10',
              'shortSchedule': 'Use short Schedule SE',
            },
            onChanged: (m) => _setNestedAndRollup('scheduleSE', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule 1-A — Additional deductions',
          subtitle: 'Form 1040 Line 13b ← Schedule 1-A, line 38.',
          builder: (_) => NestedMapEditor(
            data: schedule1A,
            labels: const {
              'tipIncome': 'Tip income deduction (Sch. 1-A → Line 13b)',
              'overtimeDeduction': 'Overtime deduction (Sch. 1-A → Line 13b)',
              'autoLoanInterest': 'Auto loan interest (Sch. 1-A → Line 13b)',
              'otherDeductions': 'Other Sch. 1-A deductions',
              'totalAdditionalDeductions': 'Total → Form 1040 Line 13b',
            },
            onChanged: (m) => _setNestedAndRollup('schedule1A', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8995 — Qualified business income (QBI)',
          subtitle: 'Form 1040 Line 13a ← Form 8995 / 8995-A.',
          builder: (_) => NestedMapEditor(
            data: form8995,
            onlyKeys: const [
              'qualifiedBusinessIncome',
              'qbiDeduction',
              'reitDividends',
              'ptpIncome',
            ],
            labels: const {
              'qualifiedBusinessIncome': 'Qualified business income',
              'qbiDeduction': 'QBI deduction → Form 1040 Line 13a',
              'reitDividends': 'REIT dividends',
              'ptpIncome': 'Publicly traded partnership income',
            },
            onChanged: (m) => _setNestedAndRollup('form8995', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule A — Itemized deductions',
          subtitle: 'Form 1040 Line 12e when itemizing (instead of standard deduction).',
          builder: (_) => Column(
            children: [
              OrganizerCheckbox(
                label: 'Itemize deductions (Schedule A → Form 1040 Line 12e)',
                value: data['itemizeDeductions'] == true,
                onChanged: (v) => _setRootAndRollup('itemizeDeductions', v),
              ),
              if (data['itemizeDeductions'] == true) ...[
                NestedMapEditor(
                  data: scheduleA,
                  labels: const {
                    'medicalExpenses': 'Medical & dental (Sch. A)',
                    'stateLocalTaxes': 'State & local income/sales taxes (SALT)',
                    'realEstateTaxes': 'Real estate taxes',
                    'personalPropertyTaxes': 'Personal property taxes',
                    'mortgageInterest': 'Home mortgage interest',
                    'mortgageInsurancePremiums': 'Mortgage insurance premiums',
                    'charitableCash': 'Charitable — cash',
                    'charitableNonCash': 'Charitable — noncash',
                    'casualtyLosses': 'Casualty & theft losses',
                    'otherItemized': 'Other itemized deductions',
                    'totalItemized': 'Total itemized → Form 1040 Line 12e',
                  },
                  onChanged: (m) => _setNestedAndRollup('scheduleA', m),
                ),
              ] else ...[
                OrganizerMoneyField(
                  label: 'Charitable contributions (summary)',
                  value: data['charitableContributions'],
                  onChanged: (v) => onRoot('charitableContributions', v),
                ),
                OrganizerMoneyField(
                  label: 'Mortgage interest (summary)',
                  value: data['mortgageInterest'],
                  onChanged: (v) => onRoot('mortgageInterest', v),
                ),
                OrganizerMoneyField(
                  label: 'Property taxes (summary)',
                  value: data['propertyTaxes'],
                  onChanged: (v) => onRoot('propertyTaxes', v),
                ),
              ],
            ],
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule 8812 — Child tax credit & other dependents',
          subtitle: 'Form 1040 Line 19 (CTC/ODC) and Line 28 (ACTC).',
          builder: (_) => NestedMapEditor(
            data: schedule8812,
            onlyKeys: const [
              'qualifyingChildren',
              'otherDependents',
              'childTaxCredit',
              'otherDependentsCredit',
              'additionalChildTaxCredit',
              'totalCreditLine19',
            ],
            labels: const {
              'qualifyingChildren': 'Qualifying children for CTC',
              'otherDependents': 'Other dependents (ODC)',
              'childTaxCredit': 'Child tax credit → Form 1040 Line 19',
              'otherDependentsCredit': 'Credit for other dependents → Line 19',
              'additionalChildTaxCredit': 'Additional child tax credit (ACTC) → Line 28',
              'totalCreditLine19': 'Total CTC + ODC → Form 1040 Line 19',
            },
            onChanged: (m) => _setNestedAndRollup('schedule8812', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Form 1040 Line 27a — Earned Income Credit',
          subtitle: 'Attach Schedule EIC when claiming with qualifying children.',
          builder: (_) => Column(
            children: [
              OrganizerCheckbox(
                label: 'Claim Earned Income Credit (EIC) — Form 1040 Line 27a',
                value: data['hasEIC'] == true,
                onChanged: (v) => _setRootAndRollup('hasEIC', v),
              ),
              if (data['hasEIC'] == true)
                OrganizerMoneyField(
                  label: 'Number of EIC qualifying children',
                  value: data['numEICChildren'],
                  onChanged: (v) => onRoot('numEICChildren', v),
                ),
            ],
          ),
        ),
        OrganizerLazySection(
          title: 'Form 2441 — Child & dependent care',
          subtitle: 'Nonrefundable credit → Schedule 3 → Form 1040 Line 20.',
          builder: (_) => Column(
            children: [
              NestedMapEditor(
                data: {
                  ...form2441,
                  if ('${form2441['providerName'] ?? ''}'.isEmpty)
                    'providerName': data['dependentCareProvider'] ?? '',
                  if ('${form2441['providerTIN'] ?? ''}'.isEmpty)
                    'providerTIN': data['dependentCareProviderTIN'] ?? '',
                  if (creditsNum(form2441['qualifiedExpenses']) == 0)
                    'qualifiedExpenses': data['dependentCareExpenses'] ?? 0,
                },
                onlyKeys: const [
                  'qualifiedExpenses',
                  'creditAmount',
                  'providerName',
                  'providerTIN',
                  'careForQualifyingPersons',
                ],
                labels: const {
                  'qualifiedExpenses': 'Qualified care expenses (Form 2441)',
                  'creditAmount': 'Dependent care credit → Sch. 3 / Line 20',
                  'providerName': 'Care provider name',
                  'providerTIN': 'Provider TIN / EIN',
                  'careForQualifyingPersons': 'Number of qualifying persons',
                },
                onChanged: (m) {
                  final patched = Map<String, dynamic>.from(data)
                    ..['form2441'] = m
                    ..['dependentCareExpenses'] = m['qualifiedExpenses']
                    ..['dependentCareProvider'] = m['providerName']
                    ..['dependentCareProviderTIN'] = m['providerTIN'];
                  onPatch(applyCreditsRollups(patched));
                },
              ),
            ],
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8863 — Education credits',
          subtitle: 'Nonrefundable portion → Sch. 3 / Line 20. Refundable AOTC → Form 1040 Line 29.',
          builder: (_) => Column(
            children: [
              NestedMapEditor(
                data: form8863,
                labels: const {
                  'studentName': 'Student name',
                  'institution': 'Institution (Form 1098-T)',
                  'tuitionPaid': 'Qualified tuition & fees paid',
                  'scholarships': 'Scholarships / grants',
                  'creditType': 'Credit type (american_opportunity / lifetime_learning)',
                  'americanOpportunityCredit': 'American Opportunity credit (total)',
                  'lifetimeLearningCredit': 'Lifetime Learning credit',
                  'refundableAotc': 'Refundable AOTC → Form 1040 Line 29',
                  'nonrefundableCredit': 'Nonrefundable education credit → Sch. 3 / Line 20',
                },
                onChanged: (m) => _setNestedAndRollup('form8863', m),
              ),
            ],
          ),
        ),
        OrganizerLazySection(
          title: 'Form 5695 — Residential energy credits',
          subtitle: '→ Schedule 3 → Form 1040 Line 20.',
          builder: (_) => NestedMapEditor(
            data: form5695,
            labels: const {
              'solarElectric': 'Solar electric',
              'solarWaterHeat': 'Solar water heating',
              'fuelCell': 'Fuel cell property',
              'smallWindEnergy': 'Small wind energy',
              'geothermalHeatPump': 'Geothermal heat pump',
              'batteryStorage': 'Battery storage',
              'evCharger': 'EV charger',
              'insulationWindows': 'Insulation / windows',
              'energyEfficientHVAC': 'Energy-efficient HVAC',
              'waterHeater': 'Water heater',
              'totalCredit': 'Total residential energy credit → Sch. 3 / Line 20',
            },
            onChanged: (m) => _setNestedAndRollup('form5695', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8839 — Adoption credit',
          subtitle: 'Refundable adoption credit → Form 1040 Line 30.',
          builder: (_) => NestedMapEditor(
            data: form8839,
            labels: const {
              'childName': 'Adopted child name',
              'qualifiedAdoptionExpenses': 'Qualified adoption expenses',
              'employerAdoptionBenefits': 'Employer adoption benefits',
              'adoptionCredit': 'Adoption credit',
              'refundableAdoptionCredit': 'Refundable adoption credit → Form 1040 Line 30',
            },
            onChanged: (m) => _setNestedAndRollup('form8839', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8962 — Premium Tax Credit',
          subtitle: 'Marketplace coverage (1095-A). Net PTC / repayment ties to Schedule 2 / Schedule 3 / Line 31.',
          builder: (_) => NestedMapEditor(
            data: _map('form8962'),
            onChanged: (m) => _setNestedAndRollup('form8962', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule 3 — Nonrefundable credits & other payments',
          subtitle: 'Line 8 → Form 1040 Line 20. Line 15 → Form 1040 Line 31.',
          builder: (_) => NestedMapEditor(
            data: schedule3,
            labels: const {
              'foreignTaxCredit': 'Foreign tax credit (Form 1116) → Sch. 3 / Line 20',
              'childDependentCareCredit': 'Child/dependent care (2441) → Sch. 3 / Line 20',
              'educationCredits': 'Education credits (8863 nonref.) → Sch. 3 / Line 20',
              'retirementSavingsCredit': 'Saver’s credit (Form 8880) → Sch. 3 / Line 20',
              'residentialEnergyCredit': 'Residential energy (5695) → Sch. 3 / Line 20',
              'otherCredits': 'Other nonrefundable credits → Sch. 3 / Line 20',
              'totalNonrefundableCredits': 'Total nonrefundable → Form 1040 Line 20',
              'estimatedTaxPayments': 'Estimated tax payments → Line 26 / Sch. 3',
              'extensionPayment': 'Amount paid with extension',
              'excessSocialSecurityWithheld': 'Excess Social Security withheld',
              'otherPayments': 'Other payments (incl. PTC) → Form 1040 Line 31',
              'totalOtherPayments': 'Total other payments → Form 1040 Line 31',
            },
            onChanged: (m) => _setNestedAndRollup('schedule3', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Schedule 2 — Additional taxes',
          subtitle: 'Sch. 2 line 3 → Form 1040 Line 17. Sch. 2 line 21 (incl. SE tax) → Line 23.',
          builder: (_) => NestedMapEditor(
            data: schedule2,
            labels: const {
              'altMinimumTax': 'Alternative minimum tax (Form 6251) → Line 17',
              'excessPremiumTaxCreditRepayment': 'Excess PTC repayment (8962) → Line 17',
              'selfEmploymentTax': 'Self-employment tax (Sch. SE) → Line 23',
              'unreportedSSTax': 'Unreported Social Security / Medicare tax',
              'additionalTaxIRA': 'Additional tax on IRAs / plans',
              'householdEmploymentTax': 'Household employment tax (Sch. H)',
              'firstTimeHomebuyerRepayment': 'First-time homebuyer credit repayment',
              'netInvestmentIncomeTax': 'Net investment income tax (8960)',
              'uncapturedSection1250Gain': 'Uncaptured section 1250 gain',
              'additionalMedicareTax': 'Additional Medicare Tax (8959)',
              'totalAdditionalTaxes': 'Total other taxes → Form 1040 Line 23',
            },
            onChanged: (m) => _setNestedAndRollup('schedule2', m),
          ),
        ),
        OrganizerLazySection(
          title: 'Form 8829 — Home office (Schedule C)',
          subtitle: 'Business use of home deduction supporting Schedule C (not a Form 1040 credit line).',
          builder: (_) => NestedMapEditor(data: _map('form8829'), onChanged: (m) => onNested('form8829', m)),
        ),
        OrganizerLazySection(
          title: 'Form 6251 — Alternative Minimum Tax',
          subtitle: 'AMT → Schedule 2 → Form 1040 Line 17.',
          builder: (_) => NestedMapEditor(data: _map('form6251'), onChanged: (m) => _setNestedAndRollup('form6251', m)),
        ),
        OrganizerLazySection(
          title: 'Form 8959 — Additional Medicare Tax',
          subtitle: '→ Schedule 2 → Form 1040 Line 23.',
          builder: (_) => NestedMapEditor(data: _map('form8959'), onChanged: (m) => _setNestedAndRollup('form8959', m)),
        ),
        OrganizerLazySection(
          title: 'Form 8960 — Net Investment Income Tax',
          subtitle: '→ Schedule 2 → Form 1040 Line 23.',
          builder: (_) => NestedMapEditor(data: _map('form8960'), onChanged: (m) => _setNestedAndRollup('form8960', m)),
        ),
        OrganizerLazySection(
          title: 'Schedule H — Household employment',
          subtitle: 'Household employment tax → Schedule 2 → Form 1040 Line 23.',
          builder: (_) => NestedMapEditor(data: scheduleH, onChanged: (m) => _setNestedAndRollup('scheduleH', m)),
        ),
        OrganizerLazySection(
          title: 'Schedule R — Credit for the elderly or disabled',
          subtitle: 'Nonrefundable credit → Schedule 3 → Form 1040 Line 20.',
          builder: (_) => NestedMapEditor(data: scheduleR, onChanged: (m) => _setNestedAndRollup('scheduleR', m)),
        ),
        const MkgCard(
          child: Text(
            'Credit and deduction totals update as you enter forms. Your tax professional reviews everything before filing.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}
