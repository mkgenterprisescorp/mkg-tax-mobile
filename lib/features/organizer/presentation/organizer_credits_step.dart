import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import 'organizer_fields.dart';

/// Full federal credits & deductions intake from `default_form_data.json`.
class OrganizerCreditsStep extends StatelessWidget {
  const OrganizerCreditsStep({
    super.key,
    required this.data,
    required this.onRoot,
    required this.onNested,
  });

  final Map<String, dynamic> data;
  final void Function(String key, dynamic value) onRoot;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from((data[key] as Map?) ?? {});

  @override
  Widget build(BuildContext context) {
    final scheduleA = _map('scheduleA');
    final schedule1 = _map('schedule1');
    final schedule1A = _map('schedule1A');
    final schedule2 = _map('schedule2');
    final schedule3 = _map('schedule3');
    final scheduleH = _map('scheduleH');
    final scheduleR = _map('scheduleR');

    return Column(
      children: [
        OrganizerSection(
          title: 'Above-the-line deductions & adjustments',
          subtitle: 'Schedule 1 / Form 1040 adjustments.',
          child: Column(
            children: [
              OrganizerMoneyField(label: 'Educator expenses', value: data['educatorExpenses'], onChanged: (v) => onRoot('educatorExpenses', v)),
              OrganizerMoneyField(label: 'Student loan interest', value: data['studentLoanInterest'], onChanged: (v) => onRoot('studentLoanInterest', v)),
              OrganizerMoneyField(label: 'IRA deduction', value: data['iraDeduction'], onChanged: (v) => onRoot('iraDeduction', v)),
              OrganizerMoneyField(label: 'HSA deduction', value: data['healthInsurancePremiums'], onChanged: (v) => onRoot('healthInsurancePremiums', v)),
              OrganizerMoneyField(label: 'Moving expenses', value: data['movingExpenses'], onChanged: (v) => onRoot('movingExpenses', v)),
              OrganizerMoneyField(label: 'Alimony paid', value: data['alimonyPaid'], onChanged: (v) => onRoot('alimonyPaid', v)),
              OrganizerMoneyField(label: 'Self-employment tax (½ deductible)', value: data['selfEmploymentTax'], onChanged: (v) => onRoot('selfEmploymentTax', v)),
              OrganizerMoneyField(label: 'Retirement contributions', value: data['retirementContributions'], onChanged: (v) => onRoot('retirementContributions', v)),
              NestedMapEditor(
                data: schedule1,
                onlyKeys: const [
                  'educatorExpenses',
                  'hsaDeduction',
                  'selfEmploymentTax',
                  'studentLoanInterest',
                  'iraDeduction',
                  'movingExpenses',
                  'alimonyPaid',
                ],
                onChanged: (m) => onNested('schedule1', m),
              ),
              NestedMapEditor(
                data: schedule1A,
                onChanged: (m) => onNested('schedule1A', m),
              ),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Family & earned income credits',
          child: Column(
            children: [
              OrganizerCheckbox(label: 'Claim Earned Income Credit (EIC)', value: data['hasEIC'] == true, onChanged: (v) => onRoot('hasEIC', v)),
              if (data['hasEIC'] == true)
                OrganizerMoneyField(label: 'Number of EIC qualifying children', value: data['numEICChildren'], onChanged: (v) => onRoot('numEICChildren', v)),
              OrganizerMoneyField(label: 'Child tax credit — qualifying children', value: data['childTaxCreditChildren'], onChanged: (v) => onRoot('childTaxCreditChildren', v)),
              OrganizerMoneyField(label: 'Dependent care expenses', value: data['dependentCareExpenses'], onChanged: (v) => onRoot('dependentCareExpenses', v)),
              OrganizerTextField(label: 'Dependent care provider', value: '${data['dependentCareProvider'] ?? ''}', onChanged: (v) => onRoot('dependentCareProvider', v)),
              OrganizerTextField(label: 'Provider TIN', value: '${data['dependentCareProviderTIN'] ?? ''}', onChanged: (v) => onRoot('dependentCareProviderTIN', v)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Form 8863 — Education credits',
          subtitle: 'American Opportunity / Lifetime Learning (from 1098-T).',
          child: Column(
            children: [
              OrganizerMoneyField(label: 'Education credits (total)', value: data['educationCredits'], onChanged: (v) => onRoot('educationCredits', v)),
              NestedMapEditor(data: _map('form8863'), onChanged: (m) => onNested('form8863', m)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Form 5695 — Residential energy credits',
          child: Column(
            children: [
              OrganizerMoneyField(label: 'Residential energy credit (total)', value: data['residentialEnergyCredit'], onChanged: (v) => onRoot('residentialEnergyCredit', v)),
              NestedMapEditor(data: _map('form5695'), onChanged: (m) => onNested('form5695', m)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Form 8962 — Premium Tax Credit',
          subtitle: 'From Form 1095-A marketplace coverage.',
          child: NestedMapEditor(data: _map('form8962'), onChanged: (m) => onNested('form8962', m)),
        ),
        OrganizerSection(
          title: 'Form 8889 — Health Savings Account',
          child: NestedMapEditor(data: _map('form8889'), onChanged: (m) => onNested('form8889', m)),
        ),
        OrganizerSection(
          title: 'Form 8829 — Home office (Schedule C)',
          child: NestedMapEditor(data: _map('form8829'), onChanged: (m) => onNested('form8829', m)),
        ),
        OrganizerSection(
          title: 'Schedule 3 — Nonrefundable credits & payments',
          child: NestedMapEditor(data: schedule3, onChanged: (m) => onNested('schedule3', m)),
        ),
        OrganizerSection(
          title: 'Schedule 2 — Additional taxes',
          child: NestedMapEditor(data: schedule2, onChanged: (m) => onNested('schedule2', m)),
        ),
        OrganizerSection(
          title: 'Form 6251 — Alternative Minimum Tax',
          child: NestedMapEditor(data: _map('form6251'), onChanged: (m) => onNested('form6251', m)),
        ),
        OrganizerSection(
          title: 'Form 8959 — Additional Medicare Tax',
          child: NestedMapEditor(data: _map('form8959'), onChanged: (m) => onNested('form8959', m)),
        ),
        OrganizerSection(
          title: 'Form 8960 — Net Investment Income Tax',
          child: NestedMapEditor(data: _map('form8960'), onChanged: (m) => onNested('form8960', m)),
        ),
        OrganizerSection(
          title: 'Schedule H — Household employment',
          child: NestedMapEditor(data: scheduleH, onChanged: (m) => onNested('scheduleH', m)),
        ),
        OrganizerSection(
          title: 'Schedule R — Credit for the elderly or disabled',
          child: NestedMapEditor(data: scheduleR, onChanged: (m) => onNested('scheduleR', m)),
        ),
        OrganizerSection(
          title: 'Itemized deductions (Schedule A)',
          child: Column(
            children: [
              OrganizerCheckbox(
                label: 'Itemize deductions (Schedule A)',
                value: data['itemizeDeductions'] == true,
                onChanged: (v) => onRoot('itemizeDeductions', v),
              ),
              OrganizerMoneyField(label: 'Charitable contributions (summary)', value: data['charitableContributions'], onChanged: (v) => onRoot('charitableContributions', v)),
              OrganizerMoneyField(label: 'Mortgage interest (summary)', value: data['mortgageInterest'], onChanged: (v) => onRoot('mortgageInterest', v)),
              OrganizerMoneyField(label: 'Property taxes (summary)', value: data['propertyTaxes'], onChanged: (v) => onRoot('propertyTaxes', v)),
              OrganizerMoneyField(label: 'Medical expenses (summary)', value: data['medicalExpenses'], onChanged: (v) => onRoot('medicalExpenses', v)),
              OrganizerMoneyField(label: 'State & local taxes (summary)', value: data['stateLocalTaxes'], onChanged: (v) => onRoot('stateLocalTaxes', v)),
              if (data['itemizeDeductions'] == true) ...[
                const SizedBox(height: 8),
                const Text('Schedule A detail', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                NestedMapEditor(data: scheduleA, onChanged: (m) => onNested('scheduleA', m)),
              ],
            ],
          ),
        ),
        const MkgCard(
          child: Text(
            'These credit and deduction forms match the web portal schemas in default_form_data.json. Amounts are intake for professional review — not a certified e-file calculation.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}
