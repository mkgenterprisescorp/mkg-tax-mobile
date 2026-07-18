import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../address/presentation/address_autofill_fields.dart';
import '../data/official_form_links.dart';
import '../data/organizer_defaults.dart';
import '../data/organizer_income_math.dart';
import '../data/us_states.dart';
import 'organizer_fields.dart';

/// Form 1040 Income step: W-2 + 1099 schemas wired to TY2025 line rollups.
/// IRS Free File line-by-line:
/// https://www.irs.gov/e-file-providers/line-by-line-instructions-free-file-fillable-forms
class OrganizerIncomeFormsStep extends StatelessWidget {
  const OrganizerIncomeFormsStep({
    super.key,
    required this.data,
    required this.onRoot,
    required this.onNested,
    required this.onPatch,
  });

  final Map<String, dynamic> data;
  final void Function(String key, dynamic value) onRoot;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;
  final void Function(Map<String, dynamic> patch) onPatch;

  List<Map<String, dynamic>> _list(String key) => incomeList(data, key);

  void _setListAndRollup(String key, List<Map<String, dynamic>> rows) {
    final next = Map<String, dynamic>.from(data)..[key] = rows;
    onPatch(applyIncomeRollups(next));
  }

  void _patchRow(String listKey, int index, String field, dynamic value) {
    final rows = _list(listKey);
    if (index < 0 || index >= rows.length) return;
    final next = List<Map<String, dynamic>>.from(rows);
    next[index] = Map<String, dynamic>.from(next[index])..[field] = value;
    _setListAndRollup(listKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final schedule1 = Map<String, dynamic>.from((data['schedule1'] as Map?) ?? {});

    return Column(
      children: [
        OfficialFormLinksCard(
          title: 'Official income form references',
          subtitle: 'Enter paper forms box-by-box. Totals roll into Form 1040 lines.',
          links: const [
            ('Form 1040 line-by-line (Free File)', OfficialFormLinks.form1040LineByLine),
            ('Form W-2', OfficialFormLinks.formW2Pdf),
            ('Form 1099-NEC', OfficialFormLinks.form1099NecPdf),
            ('Form 1099-R', OfficialFormLinks.form1099RPdf),
            ('Form 1099-G', OfficialFormLinks.form1099GPdf),
            ('SSA-1099', OfficialFormLinks.ssa1099About),
          ],
        ),
        const SizedBox(height: 18),
        _w2Section(),
        _necSection(),
        _form1099RSection(),
        _ssaSection(),
        _form1099GSection(),
        _form1099DaSection(),
        _form1099IntSection(),
        _form1099DivSection(),
        _form1099BSection(),
        _form1099KSection(),
        OrganizerSection(
          title: 'Form 1040 income summary',
          subtitle: 'Auto-filled from forms above. Edit only to override.',
          child: Column(
            children: [
              OrganizerMoneyField(label: '1a — Wages (W-2 total)', value: data['wages'], onChanged: (v) => onRoot('wages', v)),
              OrganizerMoneyField(label: '2b — Taxable interest', value: data['interestIncome'], onChanged: (v) => onRoot('interestIncome', v)),
              OrganizerMoneyField(label: '3a — Qualified dividends', value: data['qualifiedDividends'], onChanged: (v) => onRoot('qualifiedDividends', v)),
              OrganizerMoneyField(label: '3b — Ordinary dividends', value: data['dividendIncome'], onChanged: (v) => onRoot('dividendIncome', v)),
              OrganizerMoneyField(label: '4a — IRA distributions (gross)', value: data['iraDistributionsGross'], onChanged: (v) => onRoot('iraDistributionsGross', v)),
              OrganizerMoneyField(label: '4b — IRA taxable', value: data['iraDistributions'], onChanged: (v) => onRoot('iraDistributions', v)),
              OrganizerMoneyField(label: '5a — Pensions/annuities (gross)', value: data['pensionAnnuitiesGross'], onChanged: (v) => onRoot('pensionAnnuitiesGross', v)),
              OrganizerMoneyField(label: '5b — Pensions taxable', value: data['pensionAnnuities'], onChanged: (v) => onRoot('pensionAnnuities', v)),
              OrganizerMoneyField(label: '6a — Social Security (gross)', value: data['socialSecurityGross'], onChanged: (v) => onRoot('socialSecurityGross', v)),
              OrganizerMoneyField(label: '6b — Social Security taxable', value: data['socialSecurityBenefits'], onChanged: (v) => onRoot('socialSecurityBenefits', v)),
              OrganizerMoneyField(label: '7 — Capital gain (Sch. D / 1099-B/DA)', value: data['capitalGains'], onChanged: (v) => onRoot('capitalGains', v)),
              OrganizerMoneyField(label: 'Business income (Sch. C / 1099-NEC/K)', value: data['businessIncome'], onChanged: (v) => onRoot('businessIncome', v)),
              OrganizerMoneyField(label: 'Unemployment (1099-G / Sch. 1)', value: data['unemploymentComp'], onChanged: (v) => onRoot('unemploymentComp', v)),
              OrganizerMoneyField(label: 'State tax refund (1099-G Box 2)', value: data['stateTaxRefund'], onChanged: (v) => onRoot('stateTaxRefund', v)),
              OrganizerMoneyField(label: '25a — W-2 federal withheld', value: data['taxWithheldW2'], onChanged: (v) => onRoot('taxWithheldW2', v)),
              OrganizerMoneyField(label: '25b — 1099 federal withheld', value: data['taxWithheld1099'], onChanged: (v) => onRoot('taxWithheld1099', v)),
              OrganizerMoneyField(label: 'Total federal withheld', value: data['taxWithheld'], onChanged: (v) => onRoot('taxWithheld', v)),
              OrganizerMoneyField(label: 'Alimony received', value: data['alimonyReceived'], onChanged: (v) => onRoot('alimonyReceived', v)),
              OrganizerMoneyField(label: 'Other income', value: data['otherIncome'], onChanged: (v) => onRoot('otherIncome', v)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Schedule 1 — Additional income highlights',
          subtitle: 'Form 1040 Line 8 ← Schedule 1, line 10.',
          child: NestedMapEditor(
            data: schedule1,
            onlyKeys: const [
              'stateTaxRefund',
              'unemployment',
              'alimonyReceived',
              'otherIncome',
              'otherIncomeType',
              'totalAdditionalIncome',
            ],
            labels: const {
              'stateTaxRefund': 'State/local tax refund (1099-G Box 2 → Sch. 1 line 1)',
              'unemployment': 'Unemployment (1099-G Box 1 → Sch. 1 line 7)',
              'alimonyReceived': 'Alimony received (Sch. 1)',
              'otherIncome': 'Other income (Sch. 1)',
              'otherIncomeType': 'Other income type',
              'totalAdditionalIncome': 'Additional income total → Form 1040 Line 8',
            },
            onChanged: (m) => onNested('schedule1', m),
          ),
        ),
        const MkgCard(
          child: Text(
            'Totals update from the forms you enter. Your tax professional reviews everything before filing.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _formHeader(String title, int index, String listKey, List<Map<String, dynamic>> rows) {
    return Row(
      children: [
        Expanded(child: Text('$title #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(
          onPressed: () {
            final next = List<Map<String, dynamic>>.from(rows)..removeAt(index);
            _setListAndRollup(listKey, next);
          },
          icon: const Icon(Icons.delete_outline, color: MkgColors.red),
        ),
      ],
    );
  }

  Widget _addButton(String label, String listKey, Map<String, dynamic> Function() empty) {
    return OutlinedButton.icon(
      onPressed: () => _setListAndRollup(listKey, [..._list(listKey), empty()]),
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }

  Widget _stateField(String listKey, int i, String field, Map row) {
    return OrganizerDropdown<String>(
      label: 'State',
      value: usStateOptions.any((e) => e.$1 == '${row[field] ?? ''}') ? '${row[field]}' : '',
      items: [
        ('', 'Select state'),
        for (final opt in usStateOptions) (opt.$1, opt.$1),
      ],
      onChanged: (v) => _patchRow(listKey, i, field, v ?? ''),
    );
  }

  Widget _w2Section() {
    const key = 'w2Forms';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form W-2 — Wage and Tax Statement',
      subtitle: 'Box 1 → Form 1040 Line 1a. Box 2 → Line 25a. Enter as on paper W-2.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formHeader('W-2', i, key, rows),
                  OrganizerTextField(label: 'b — Employer EIN', value: '${rows[i]['employerEIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'employerEIN', v)),
                  OrganizerTextField(label: 'c — Employer name', value: '${rows[i]['employerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'employerName', v)),
                  const SizedBox(height: 8),
                  Text(
                    'c — Employer address (street map)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: MkgColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  AddressAutofillFields(
                    data: rows[i],
                    onChanged: (field, value) => _patchRow(key, i, field, value),
                    streetKey: 'employerAddress',
                    cityKey: 'employerCity',
                    stateKey: 'employerState',
                    zipKey: 'employerZip',
                    showApartment: false,
                    streetLabel: 'Employer street',
                    helperText: 'Search the map to fill employer city, state, and ZIP',
                  ),
                  OrganizerTextField(label: 'Control number', value: '${rows[i]['controlNumber'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'controlNumber', v)),
                  OrganizerTextField(label: 'e — Employee first name', value: '${rows[i]['employeeFirstName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'employeeFirstName', v)),
                  OrganizerTextField(label: 'Employee last name', value: '${rows[i]['employeeLastName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'employeeLastName', v)),
                  OrganizerTextField(label: 'Employee SSN', value: '${rows[i]['employeeSSN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'employeeSSN', v)),
                  const SizedBox(height: 8),
                  Text(
                    'f — Employee address (street map)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: MkgColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  AddressAutofillFields(
                    data: rows[i],
                    onChanged: (field, value) => _patchRow(key, i, field, value),
                    streetKey: 'employeeAddress',
                    cityKey: 'employeeCity',
                    stateKey: 'employeeState',
                    zipKey: 'employeeZip',
                    showApartment: false,
                    streetLabel: 'Employee street',
                    helperText: 'Search the map to fill employee city, state, and ZIP',
                  ),
                  OrganizerMoneyField(label: '1 — Wages, tips, other compensation → Line 1a', value: rows[i]['box1_wagesTips'], onChanged: (v) => _patchRow(key, i, 'box1_wagesTips', v)),
                  OrganizerMoneyField(label: '2 — Federal income tax withheld → Line 25a', value: rows[i]['box2_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box2_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '3 — Social Security wages', value: rows[i]['box3_ssWages'], onChanged: (v) => _patchRow(key, i, 'box3_ssWages', v)),
                  OrganizerMoneyField(label: '4 — Social Security tax withheld', value: rows[i]['box4_ssTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_ssTaxWithheld', v)),
                  OrganizerMoneyField(label: '5 — Medicare wages and tips', value: rows[i]['box5_medicareWages'], onChanged: (v) => _patchRow(key, i, 'box5_medicareWages', v)),
                  OrganizerMoneyField(label: '6 — Medicare tax withheld', value: rows[i]['box6_medicareTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box6_medicareTaxWithheld', v)),
                  OrganizerMoneyField(label: '7 — Social Security tips', value: rows[i]['box7_ssTips'], onChanged: (v) => _patchRow(key, i, 'box7_ssTips', v)),
                  OrganizerMoneyField(label: '8 — Allocated tips', value: rows[i]['box8_allocatedTips'], onChanged: (v) => _patchRow(key, i, 'box8_allocatedTips', v)),
                  OrganizerMoneyField(label: '10 — Dependent care benefits', value: rows[i]['box10_dependentCareBenefits'], onChanged: (v) => _patchRow(key, i, 'box10_dependentCareBenefits', v)),
                  OrganizerMoneyField(label: '11 — Nonqualified plans', value: rows[i]['box11_nonqualifiedPlans'], onChanged: (v) => _patchRow(key, i, 'box11_nonqualifiedPlans', v)),
                  for (final code in const ['a', 'b', 'c', 'd']) ...[
                    OrganizerTextField(label: '12$code code', value: '${rows[i]['box12${code}_code'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box12${code}_code', v)),
                    OrganizerMoneyField(label: '12$code amount', value: rows[i]['box12${code}_amount'], onChanged: (v) => _patchRow(key, i, 'box12${code}_amount', v)),
                  ],
                  OrganizerCheckbox(label: '13 — Statutory employee', value: rows[i]['box13_statutory'] == true, onChanged: (v) => _patchRow(key, i, 'box13_statutory', v)),
                  OrganizerCheckbox(label: '13 — Retirement plan', value: rows[i]['box13_retirementPlan'] == true, onChanged: (v) => _patchRow(key, i, 'box13_retirementPlan', v)),
                  OrganizerCheckbox(label: '13 — Third-party sick pay', value: rows[i]['box13_thirdPartySickPay'] == true, onChanged: (v) => _patchRow(key, i, 'box13_thirdPartySickPay', v)),
                  OrganizerTextField(label: '14 — Other', value: '${rows[i]['box14_other'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box14_other', v)),
                  _stateField(key, i, 'box15_state', rows[i]),
                  OrganizerTextField(label: '15 — Employer state ID', value: '${rows[i]['box15_stateId'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box15_stateId', v)),
                  OrganizerMoneyField(label: '16 — State wages', value: rows[i]['box16_stateWages'], onChanged: (v) => _patchRow(key, i, 'box16_stateWages', v)),
                  OrganizerMoneyField(label: '17 — State income tax', value: rows[i]['box17_stateTax'], onChanged: (v) => _patchRow(key, i, 'box17_stateTax', v)),
                  OrganizerMoneyField(label: '18 — Local wages', value: rows[i]['box18_localWages'], onChanged: (v) => _patchRow(key, i, 'box18_localWages', v)),
                  OrganizerMoneyField(label: '19 — Local income tax', value: rows[i]['box19_localTax'], onChanged: (v) => _patchRow(key, i, 'box19_localTax', v)),
                  OrganizerTextField(label: '20 — Locality name', value: '${rows[i]['box20_localityName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box20_localityName', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton(
            'Add W-2',
            key,
            () => emptyW2Form(
              employeeSSN: '${data['ssn'] ?? ''}',
              employeeFirstName: '${data['firstName'] ?? ''}',
              employeeLastName: '${data['lastName'] ?? ''}',
              employeeAddress: '${data['address'] ?? ''}',
              employeeCity: '${data['city'] ?? ''}',
              employeeState: '${data['state'] ?? ''}',
              employeeZip: '${data['zip'] ?? ''}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _necSection() {
    const key = 'form1099NEC';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-NEC — Nonemployee compensation',
      subtitle: 'Box 1 → Schedule C / business income → Form 1040 Line 8 path.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-NEC', i, key, rows),
                  OrganizerTextField(label: 'Payer name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerTextField(label: 'Payer TIN', value: '${rows[i]['payerTIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerTIN', v)),
                  const SizedBox(height: 8),
                  Text(
                    'Payer address (street map)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: MkgColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  AddressAutofillFields(
                    data: rows[i],
                    onChanged: (field, value) => _patchRow(key, i, field, value),
                    streetKey: 'payerAddress',
                    cityKey: 'payerCity',
                    stateKey: 'payerState',
                    zipKey: 'payerZip',
                    showApartment: false,
                    streetLabel: 'Payer street',
                    helperText: 'Search the map to fill payer city, state, and ZIP',
                  ),
                  OrganizerTextField(label: 'Account number', value: '${rows[i]['accountNumber'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'accountNumber', v)),
                  OrganizerMoneyField(label: '1 — Nonemployee compensation', value: rows[i]['box1_nonemployeeComp'], onChanged: (v) => _patchRow(key, i, 'box1_nonemployeeComp', v)),
                  OrganizerCheckbox(label: '2 — Payer made direct sales of \$5,000+', value: rows[i]['box2_directSales5000'] == true, onChanged: (v) => _patchRow(key, i, 'box2_directSales5000', v)),
                  OrganizerMoneyField(label: '4 — Federal income tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '5 — State tax withheld', value: rows[i]['box5_stateTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box5_stateTaxWithheld', v)),
                  OrganizerMoneyField(label: '6 — State income', value: rows[i]['box6_stateIncome'], onChanged: (v) => _patchRow(key, i, 'box6_stateIncome', v)),
                  _stateField(key, i, 'box7_state', rows[i]),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-NEC', key, emptyForm1099Nec),
        ],
      ),
    );
  }

  Widget _form1099RSection() {
    const key = 'form1099R';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-R — Distributions from pensions, annuities, retirement',
      subtitle: 'Box 1/2a → Form 1040 Lines 4a–4b (IRA) or 5a–5b (pension). Check IRA/SEP/SIMPLE for Line 4.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-R', i, key, rows),
                  OrganizerTextField(label: 'Payer name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerTextField(label: 'Payer TIN', value: '${rows[i]['payerTIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerTIN', v)),
                  const SizedBox(height: 8),
                  Text(
                    'Payer address (street map)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: MkgColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  AddressAutofillFields(
                    data: rows[i],
                    onChanged: (field, value) => _patchRow(key, i, field, value),
                    streetKey: 'payerAddress',
                    cityKey: 'payerCity',
                    stateKey: 'payerState',
                    zipKey: 'payerZip',
                    showApartment: false,
                    streetLabel: 'Payer street',
                    helperText: 'Search the map to fill payer city, state, and ZIP',
                  ),
                  OrganizerTextField(label: 'Account number', value: '${rows[i]['accountNumber'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'accountNumber', v)),
                  OrganizerMoneyField(label: '1 — Gross distribution → Line 4a/5a', value: rows[i]['box1_grossDistribution'], onChanged: (v) => _patchRow(key, i, 'box1_grossDistribution', v)),
                  OrganizerMoneyField(label: '2a — Taxable amount → Line 4b/5b', value: rows[i]['box2a_taxableAmount'], onChanged: (v) => _patchRow(key, i, 'box2a_taxableAmount', v)),
                  OrganizerCheckbox(label: '2b — Taxable amount not determined', value: rows[i]['box2b_taxableAmountNotDetermined'] == true, onChanged: (v) => _patchRow(key, i, 'box2b_taxableAmountNotDetermined', v)),
                  OrganizerCheckbox(label: '2b — Total distribution', value: rows[i]['box2b_totalDistribution'] == true, onChanged: (v) => _patchRow(key, i, 'box2b_totalDistribution', v)),
                  OrganizerMoneyField(label: '3 — Capital gain', value: rows[i]['box3_capitalGain'], onChanged: (v) => _patchRow(key, i, 'box3_capitalGain', v)),
                  OrganizerMoneyField(label: '4 — Federal income tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '5 — Employee contributions / designated Roth', value: rows[i]['box5_employeeContributions'], onChanged: (v) => _patchRow(key, i, 'box5_employeeContributions', v)),
                  OrganizerTextField(label: '7 — Distribution code(s)', value: '${rows[i]['box7_distributionCode'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box7_distributionCode', v)),
                  OrganizerCheckbox(label: 'IRA/SEP/SIMPLE → Form 1040 Line 4', value: rows[i]['box7_iraSepSimple'] == true, onChanged: (v) => _patchRow(key, i, 'box7_iraSepSimple', v)),
                  OrganizerMoneyField(label: '14 — State tax withheld', value: rows[i]['box14_stateTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box14_stateTaxWithheld', v)),
                  _stateField(key, i, 'box15_state', rows[i]),
                  OrganizerMoneyField(label: '16 — State distribution', value: rows[i]['box16_stateDistribution'], onChanged: (v) => _patchRow(key, i, 'box16_stateDistribution', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-R', key, emptyForm1099R),
        ],
      ),
    );
  }

  Widget _ssaSection() {
    const key = 'formSSA1099';
    final rows = _list(key);
    return OrganizerSection(
      title: 'SSA-1099 — Social Security Benefit Statement',
      subtitle: 'Box 5 → Form 1040 Line 6a. Taxable benefits → Line 6b (intake estimate if blank).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('SSA-1099', i, key, rows),
                  OrganizerTextField(label: 'Beneficiary name', value: '${rows[i]['beneficiaryName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'beneficiaryName', v)),
                  OrganizerTextField(label: 'Claim number', value: '${rows[i]['claimNumber'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'claimNumber', v)),
                  OrganizerMoneyField(label: '3 — Benefits paid', value: rows[i]['box3_benefitsPaid'], onChanged: (v) => _patchRow(key, i, 'box3_benefitsPaid', v)),
                  OrganizerMoneyField(label: '4 — Benefits repaid', value: rows[i]['box4_benefitsRepaid'], onChanged: (v) => _patchRow(key, i, 'box4_benefitsRepaid', v)),
                  OrganizerMoneyField(label: '5 — Net benefits → Form 1040 Line 6a', value: rows[i]['box5_netBenefits'], onChanged: (v) => _patchRow(key, i, 'box5_netBenefits', v)),
                  OrganizerMoneyField(label: '6 — Voluntary federal tax withheld → Line 25b', value: rows[i]['box6_voluntaryTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box6_voluntaryTaxWithheld', v)),
                  OrganizerMoneyField(label: 'Taxable benefits → Form 1040 Line 6b', value: rows[i]['taxableBenefits'], onChanged: (v) => _patchRow(key, i, 'taxableBenefits', v)),
                  OrganizerMoneyField(label: 'Medicare Part B premiums', value: rows[i]['medicarePartB'], onChanged: (v) => _patchRow(key, i, 'medicarePartB', v)),
                  OrganizerMoneyField(label: 'Prescription drug (Part D) premiums', value: rows[i]['medicarePrescriptionDrug'], onChanged: (v) => _patchRow(key, i, 'medicarePrescriptionDrug', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add SSA-1099', key, emptyFormSsa1099),
        ],
      ),
    );
  }

  Widget _form1099GSection() {
    const key = 'form1099G';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-G — Certain government payments',
      subtitle: 'Box 1 unemployment → Sch. 1 line 7. Box 2 state/local refund → Sch. 1 line 1 → Form 1040 Line 8.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-G', i, key, rows),
                  OrganizerTextField(label: 'Payer name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerTextField(label: 'Payer TIN', value: '${rows[i]['payerTIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerTIN', v)),
                  OrganizerMoneyField(label: '1 — Unemployment compensation', value: rows[i]['box1_unemployment'], onChanged: (v) => _patchRow(key, i, 'box1_unemployment', v)),
                  OrganizerMoneyField(label: '2 — State/local income tax refunds', value: rows[i]['box2_stateLocalRefund'], onChanged: (v) => _patchRow(key, i, 'box2_stateLocalRefund', v)),
                  OrganizerTextField(label: '3 — Box 2 tax year', value: '${rows[i]['box3_box2TaxYear'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box3_box2TaxYear', v)),
                  OrganizerMoneyField(label: '4 — Federal income tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '5 — RTAA payments', value: rows[i]['box5_rttaPayments'], onChanged: (v) => _patchRow(key, i, 'box5_rttaPayments', v)),
                  OrganizerMoneyField(label: '6 — Taxable grants', value: rows[i]['box6_taxableGrants'], onChanged: (v) => _patchRow(key, i, 'box6_taxableGrants', v)),
                  OrganizerMoneyField(label: '7 — Agriculture payments', value: rows[i]['box7_agriculturePayments'], onChanged: (v) => _patchRow(key, i, 'box7_agriculturePayments', v)),
                  _stateField(key, i, 'box10a_state', rows[i]),
                  OrganizerTextField(label: '10b — State identification no.', value: '${rows[i]['box10b_stateId'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'box10b_stateId', v)),
                  OrganizerMoneyField(label: '11 — State income', value: rows[i]['box11_stateIncome'], onChanged: (v) => _patchRow(key, i, 'box11_stateIncome', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-G', key, emptyForm1099G),
        ],
      ),
    );
  }

  Widget _form1099DaSection() {
    const key = 'form1099DA';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-DA — Digital asset proceeds',
      subtitle: 'Proceeds − basis → Form 1040 Line 7 / Schedule D. Answer the Form 1040 digital assets question in Filing Info.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-DA', i, key, rows),
                  OrganizerTextField(label: 'Exchange / broker name', value: '${rows[i]['exchangeName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'exchangeName', v)),
                  OrganizerTextField(label: 'Payer TIN', value: '${rows[i]['payerTIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerTIN', v)),
                  OrganizerTextField(label: 'Digital asset name', value: '${rows[i]['digitalAssetName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'digitalAssetName', v)),
                  OrganizerMoneyField(label: 'Quantity', value: rows[i]['quantity'], onChanged: (v) => _patchRow(key, i, 'quantity', v)),
                  OrganizerTextField(label: 'Date acquired', value: '${rows[i]['dateAcquired'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'dateAcquired', v)),
                  OrganizerTextField(label: 'Date sold', value: '${rows[i]['dateSold'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'dateSold', v)),
                  OrganizerMoneyField(label: 'Proceeds', value: rows[i]['proceeds'], onChanged: (v) => _patchRow(key, i, 'proceeds', v)),
                  OrganizerMoneyField(label: 'Cost basis', value: rows[i]['costBasis'], onChanged: (v) => _patchRow(key, i, 'costBasis', v)),
                  OrganizerMoneyField(label: 'Gain/loss → Form 1040 Line 7', value: rows[i]['gainLoss'], onChanged: (v) => _patchRow(key, i, 'gainLoss', v)),
                  OrganizerMoneyField(label: 'Federal tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-DA', key, emptyForm1099Da),
        ],
      ),
    );
  }

  Widget _form1099IntSection() {
    const key = 'form1099INT';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-INT — Interest income',
      subtitle: 'Box 1 → Form 1040 Line 2b (also Schedule B).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-INT', i, key, rows),
                  OrganizerTextField(label: 'Payer name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerMoneyField(label: '1 — Interest income → Line 2b', value: rows[i]['box1_interestIncome'], onChanged: (v) => _patchRow(key, i, 'box1_interestIncome', v)),
                  OrganizerMoneyField(label: '2 — Early withdrawal penalty', value: rows[i]['box2_earlyWithdrawalPenalty'], onChanged: (v) => _patchRow(key, i, 'box2_earlyWithdrawalPenalty', v)),
                  OrganizerMoneyField(label: '3 — Interest on U.S. savings bonds', value: rows[i]['box3_usBondInterest'], onChanged: (v) => _patchRow(key, i, 'box3_usBondInterest', v)),
                  OrganizerMoneyField(label: '4 — Federal tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '8 — Tax-exempt interest → Line 2a', value: rows[i]['box8_taxExemptInterest'], onChanged: (v) => _patchRow(key, i, 'box8_taxExemptInterest', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-INT', key, emptyForm1099Int),
        ],
      ),
    );
  }

  Widget _form1099DivSection() {
    const key = 'form1099DIV';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-DIV — Dividends and distributions',
      subtitle: 'Box 1a → Line 3b. Box 1b → Line 3a.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-DIV', i, key, rows),
                  OrganizerTextField(label: 'Payer name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerMoneyField(label: '1a — Ordinary dividends → Line 3b', value: rows[i]['box1a_ordinaryDividends'], onChanged: (v) => _patchRow(key, i, 'box1a_ordinaryDividends', v)),
                  OrganizerMoneyField(label: '1b — Qualified dividends → Line 3a', value: rows[i]['box1b_qualifiedDividends'], onChanged: (v) => _patchRow(key, i, 'box1b_qualifiedDividends', v)),
                  OrganizerMoneyField(label: '2a — Total capital gain distributions', value: rows[i]['box2a_capitalGainDist'], onChanged: (v) => _patchRow(key, i, 'box2a_capitalGainDist', v)),
                  OrganizerMoneyField(label: '4 — Federal tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  OrganizerMoneyField(label: '5 — Section 199A dividends', value: rows[i]['box5_section199A'], onChanged: (v) => _patchRow(key, i, 'box5_section199A', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-DIV', key, emptyForm1099Div),
        ],
      ),
    );
  }

  Widget _form1099BSection() {
    const key = 'form1099B';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-B — Proceeds from broker transactions',
      subtitle: 'Gain/loss → Form 1040 Line 7 / Schedule D / Form 8949.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-B', i, key, rows),
                  OrganizerTextField(label: 'Brokerage name', value: '${rows[i]['brokerageName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'brokerageName', v)),
                  OrganizerTextField(label: 'Description', value: '${rows[i]['description'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'description', v)),
                  OrganizerTextField(label: 'Date acquired', value: '${rows[i]['dateAcquired'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'dateAcquired', v)),
                  OrganizerTextField(label: 'Date sold', value: '${rows[i]['dateSold'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'dateSold', v)),
                  OrganizerMoneyField(label: 'Proceeds', value: rows[i]['proceeds'], onChanged: (v) => _patchRow(key, i, 'proceeds', v)),
                  OrganizerMoneyField(label: 'Cost basis', value: rows[i]['costBasis'], onChanged: (v) => _patchRow(key, i, 'costBasis', v)),
                  OrganizerMoneyField(label: 'Gain/loss → Line 7', value: rows[i]['gainLoss'], onChanged: (v) => _patchRow(key, i, 'gainLoss', v)),
                  OrganizerDropdown<String>(
                    label: 'Short or long term',
                    value: '${rows[i]['shortOrLong'] ?? 'long'}',
                    items: const [('short', 'Short-term'), ('long', 'Long-term')],
                    onChanged: (v) => _patchRow(key, i, 'shortOrLong', v ?? 'long'),
                  ),
                  OrganizerMoneyField(label: 'Federal tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-B', key, emptyForm1099B),
        ],
      ),
    );
  }

  Widget _form1099KSection() {
    const key = 'form1099K';
    final rows = _list(key);
    return OrganizerSection(
      title: 'Form 1099-K — Payment card and third party network',
      subtitle: 'Box 1a gross → business / marketplace income intake (Schedule C).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            MkgCard(
              child: Column(
                children: [
                  _formHeader('1099-K', i, key, rows),
                  OrganizerTextField(label: 'Payer / PSE name', value: '${rows[i]['payerName'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerName', v)),
                  OrganizerTextField(label: 'Payer TIN', value: '${rows[i]['payerTIN'] ?? ''}', onChanged: (v) => _patchRow(key, i, 'payerTIN', v)),
                  OrganizerMoneyField(label: '1a — Gross amount of payment transactions', value: rows[i]['box1a_grossAmount'], onChanged: (v) => _patchRow(key, i, 'box1a_grossAmount', v)),
                  OrganizerMoneyField(label: '1b — Card not present transactions', value: rows[i]['box1b_cardNotPresent'], onChanged: (v) => _patchRow(key, i, 'box1b_cardNotPresent', v)),
                  OrganizerMoneyField(label: '3 — Number of payment transactions', value: rows[i]['box3_numberOfTransactions'], onChanged: (v) => _patchRow(key, i, 'box3_numberOfTransactions', v)),
                  OrganizerMoneyField(label: '4 — Federal tax withheld → Line 25b', value: rows[i]['box4_fedTaxWithheld'], onChanged: (v) => _patchRow(key, i, 'box4_fedTaxWithheld', v)),
                  _stateField(key, i, 'box5_state', rows[i]),
                  OrganizerMoneyField(label: '7 — State income', value: rows[i]['box7_stateIncome'], onChanged: (v) => _patchRow(key, i, 'box7_stateIncome', v)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          _addButton('Add 1099-K', key, emptyForm1099K),
        ],
      ),
    );
  }
}
