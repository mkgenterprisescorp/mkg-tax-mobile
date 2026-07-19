import 'package:flutter/material.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/ca_business_estimate_math.dart';
import '../data/official_form_links.dart';
import '../data/organizer_enum_options.dart';
import 'organizer_fields.dart';

const _accountingMethods = accountingMethodOptions;

const _fiduciaryTypes = <(String, String)>[
  ('estate', 'Estate'),
  ('simple_trust', 'Simple Trust'),
  ('complex_trust', 'Complex Trust'),
  ('grantor_trust', 'Grantor Trust'),
];

const _k1RecipientTypes = <(String, String)>[
  ('individual', 'Individual'),
  ('corporation', 'Corporation'),
  ('partnership', 'Partnership'),
  ('trust', 'Trust / estate'),
  ('exempt', 'Exempt organization'),
];

/// Which CA business forms to show for a given prepType (web Organizer parity).
List<String> caBusinessFormKeysForPrep(String prepType) {
  switch (prepType) {
    case 'form1120':
      return const ['caForm100', 'caScheduleR', 'caScheduleK1'];
    case 'form1120S':
      return const ['caForm100S', 'caScheduleR', 'caScheduleK1'];
    case 'form1065':
      return const ['caForm565', 'caScheduleR', 'caScheduleK1'];
    case 'form1041':
      return const ['caForm541', 'caScheduleK1'];
    case 'form990':
    case 'form990EZ':
      return const ['caForm199'];
    case 'business':
      // Schedule C sole prop — show partnership/LLC + corp paths for CA nexus.
      return const ['caForm565', 'caForm100', 'caScheduleR'];
    default:
      // Personal: show all for optional CA business nexus.
      return const [
        'caForm100',
        'caForm100S',
        'caForm565',
        'caForm541',
        'caForm199',
        'caScheduleR',
        'caScheduleK1',
      ];
  }
}

/// Typed California business entity forms (web Organizer parity).
class OrganizerCaBusinessForms extends StatelessWidget {
  const OrganizerCaBusinessForms({
    super.key,
    required this.data,
    required this.onNested,
  });

  final Map<String, dynamic> data;
  final void Function(String nestKey, Map<String, dynamic> value) onNested;

  Map<String, dynamic> _map(String key) =>
      Map<String, dynamic>.from((data[key] as Map?) ?? {});

  @override
  Widget build(BuildContext context) {
    final prep = '${data['prepType'] ?? 'personal'}';
    final keys = caBusinessFormKeysForPrep(prep);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OfficialFormLinksCard(
          title: 'Official California business forms (FTB TY2025)',
          subtitle: 'Corporation, S-corp, partnership, fiduciary, exempt org, Schedule R.',
          links: [
            ('Form 100 PDF', OfficialFormLinks.ca100Pdf),
            ('Form 100S PDF', OfficialFormLinks.ca100sPdf),
            ('Form 565 PDF', OfficialFormLinks.ca565Pdf),
            ('Form 541 PDF', OfficialFormLinks.ca541Pdf),
            ('Form 199 PDF', OfficialFormLinks.ca199Pdf),
            ('Schedule R PDF', OfficialFormLinks.caScheduleRPdf),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          prep.startsWith('form')
              ? 'Showing CA forms for $prep'
              : 'Optional CA business entity forms — complete any that apply',
          style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final key in keys) ...[
          if (key == 'caForm100')
            _CaForm100(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caForm100S')
            _CaForm100S(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caForm565')
            _CaForm565(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caForm541')
            _CaForm541(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caForm199')
            _CaForm199(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caScheduleR')
            _CaScheduleR(data: _map(key), onChanged: (m) => onNested(key, m)),
          if (key == 'caScheduleK1')
            _CaScheduleK1(data: _map(key), onChanged: (m) => onNested(key, m)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EstimateBanner extends StatelessWidget {
  const _EstimateBanner({
    required this.lines,
    required this.onApply,
  });

  final List<(String, String)> lines;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return MkgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Live estimate rollup',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Estimate-only — confirm with FTB instructions and your preparer before filing.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(child: Text(line.$1)),
                  Text(line.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onApply,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Write estimate totals into form'),
          ),
        ],
      ),
    );
  }
}

String _money(num n) {
  final abs = n.abs();
  final whole = abs.round();
  final s = whole.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return n < 0 ? '-\$$s' : '\$$s';
}

class _CaForm100 extends StatelessWidget {
  const _CaForm100({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'corporationName', 'feinCA', 'caSecretaryOfStateNo', 'accountingMethod',
    'grossReceipts', 'returnsAllowances', 'costOfGoodsSold', 'grossProfit',
    'dividends', 'interest', 'rents', 'royalties', 'capitalGains', 'otherIncome',
    'totalIncome', 'compensation', 'salaries', 'repairs', 'badDebts', 'rentsExpense',
    'taxesLicenses', 'interestExpense', 'depreciation', 'depletion', 'advertising',
    'pensionPlans', 'employeeBenefits', 'otherDeductions', 'totalDeductions',
    'netIncome', 'netTaxableIncome', 'corporateTax', 'alternativeMinTax', 'totalTax',
    'estimatedPayments', 'withholdingPayments', 'totalPayments', 'taxDue',
    'overpayment', 'minimumFranchiseTax',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaForm100(data);
    final method = _accountingMethods.any((e) => e.$1 == '${data['accountingMethod']}')
        ? '${data['accountingMethod']}'
        : 'accrual';

    return OrganizerSection(
      title: 'CA Form 100 — Corporation Franchise or Income Tax Return',
      subtitle: 'Federal Form 1120 counterpart. Min franchise tax \$800. Estimate rate 8.84%.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('Gross profit', _money(summary['grossProfit']!)),
              ('Net income', _money(summary['netIncome']!)),
              ('Total tax (est.)', _money(summary['totalTax']!)),
              ('Tax due / (overpayment)', _money(summary['taxDue']! - summary['overpayment']!)),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          OrganizerTextField(
            label: 'Corporation name',
            value: '${data['corporationName'] ?? ''}',
            onChanged: (v) => _patch('corporationName', v),
          ),
          OrganizerTextField(
            label: 'CA FEIN',
            value: '${data['feinCA'] ?? ''}',
            onChanged: (v) => _patch('feinCA', v),
          ),
          OrganizerTextField(
            label: 'CA Secretary of State No.',
            value: '${data['caSecretaryOfStateNo'] ?? ''}',
            onChanged: (v) => _patch('caSecretaryOfStateNo', v),
          ),
          OrganizerDropdown<String>(
            label: 'Accounting method',
            value: method,
            items: _accountingMethods,
            onChanged: (v) => _patch('accountingMethod', v ?? 'accrual'),
          ),
          ..._moneyFields(const [
            ('Gross receipts', 'grossReceipts'),
            ('Returns & allowances', 'returnsAllowances'),
            ('Cost of goods sold', 'costOfGoodsSold'),
            ('Gross profit', 'grossProfit'),
            ('Dividends', 'dividends'),
            ('Interest', 'interest'),
            ('Rents', 'rents'),
            ('Royalties', 'royalties'),
            ('Capital gains', 'capitalGains'),
            ('Other income', 'otherIncome'),
            ('Total income', 'totalIncome'),
            ('Compensation of officers', 'compensation'),
            ('Salaries & wages', 'salaries'),
            ('Repairs', 'repairs'),
            ('Bad debts', 'badDebts'),
            ('Rents expense', 'rentsExpense'),
            ('Taxes & licenses', 'taxesLicenses'),
            ('Interest expense', 'interestExpense'),
            ('Depreciation', 'depreciation'),
            ('Depletion', 'depletion'),
            ('Advertising', 'advertising'),
            ('Pension plans', 'pensionPlans'),
            ('Employee benefits', 'employeeBenefits'),
            ('Other deductions', 'otherDeductions'),
            ('Total deductions', 'totalDeductions'),
            ('Net income', 'netIncome'),
            ('Net taxable income', 'netTaxableIncome'),
            ('Corporate tax', 'corporateTax'),
            ('Alternative minimum tax', 'alternativeMinTax'),
            ('Minimum franchise tax', 'minimumFranchiseTax'),
            ('Total tax', 'totalTax'),
            ('Estimated payments', 'estimatedPayments'),
            ('Withholding payments', 'withholdingPayments'),
            ('Total payments', 'totalPayments'),
            ('Tax due', 'taxDue'),
            ('Overpayment', 'overpayment'),
          ]),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }

  List<Widget> _moneyFields(List<(String, String)> fields) => [
        for (final f in fields)
          OrganizerMoneyField(
            label: f.$1,
            value: data[f.$2],
            onChanged: (v) => _patch(f.$2, v),
          ),
      ];
}

class _CaForm100S extends StatelessWidget {
  const _CaForm100S({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'corporationName', 'feinCA', 'caSecretaryOfStateNo', 'accountingMethod',
    'grossReceipts', 'returnsAllowances', 'costOfGoodsSold', 'grossProfit',
    'otherIncome', 'totalIncome', 'totalDeductions', 'ordinaryIncome',
    'builtInGainsTax', 'excessPassiveIncomeTax', 'lICSurcharge', 'totalTax',
    'estimatedPayments', 'withholdingPayments', 'totalPayments', 'taxDue',
    'overpayment', 'minimumFranchiseTax', 'shareholderCount',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaForm100S(data);
    return OrganizerSection(
      title: 'CA Form 100S — S Corporation Franchise or Income Tax Return',
      subtitle: 'Federal Form 1120-S counterpart. Min franchise tax \$800. 1.5% S-corp tax estimate.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('Ordinary income', _money(summary['ordinaryIncome']!)),
              ('Total tax (est.)', _money(summary['totalTax']!)),
              ('Tax due / (overpayment)', _money(summary['taxDue']! - summary['overpayment']!)),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          OrganizerTextField(
            label: 'Corporation name',
            value: '${data['corporationName'] ?? ''}',
            onChanged: (v) => _patch('corporationName', v),
          ),
          OrganizerTextField(
            label: 'CA FEIN',
            value: '${data['feinCA'] ?? ''}',
            onChanged: (v) => _patch('feinCA', v),
          ),
          OrganizerTextField(
            label: 'CA Secretary of State No.',
            value: '${data['caSecretaryOfStateNo'] ?? ''}',
            onChanged: (v) => _patch('caSecretaryOfStateNo', v),
          ),
          OrganizerDropdown<String>(
            label: 'Accounting method',
            value: normalizeEnumValue(
              data['accountingMethod'],
              _accountingMethods,
              fallback: 'accrual',
            ),
            items: _accountingMethods,
            onChanged: (v) => _patch('accountingMethod', v ?? 'accrual'),
          ),
          OrganizerMoneyField(
            label: 'Shareholder count',
            value: data['shareholderCount'],
            onChanged: (v) => _patch('shareholderCount', v.round()),
          ),
          for (final f in const [
            ('Gross receipts', 'grossReceipts'),
            ('Returns & allowances', 'returnsAllowances'),
            ('Cost of goods sold', 'costOfGoodsSold'),
            ('Gross profit', 'grossProfit'),
            ('Other income', 'otherIncome'),
            ('Total income', 'totalIncome'),
            ('Total deductions', 'totalDeductions'),
            ('Ordinary income', 'ordinaryIncome'),
            ('Built-in gains tax', 'builtInGainsTax'),
            ('Excess passive income tax', 'excessPassiveIncomeTax'),
            ('LICS surcharge', 'lICSurcharge'),
            ('Minimum franchise tax', 'minimumFranchiseTax'),
            ('Total tax', 'totalTax'),
            ('Estimated payments', 'estimatedPayments'),
            ('Withholding payments', 'withholdingPayments'),
            ('Total payments', 'totalPayments'),
            ('Tax due', 'taxDue'),
            ('Overpayment', 'overpayment'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}

class _CaForm565 extends StatelessWidget {
  const _CaForm565({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'partnershipName', 'feinCA', 'caSecretaryOfStateNo', 'accountingMethod',
    'grossReceipts', 'returnsAllowances', 'costOfGoodsSold', 'grossProfit',
    'ordinaryIncome', 'rentalIncome', 'interestIncome', 'dividendIncome',
    'royaltyIncome', 'capitalGains', 'otherIncome', 'totalIncome',
    'salariesWages', 'guaranteedPayments', 'repairsExpense', 'badDebts',
    'rentsExpense', 'taxesLicenses', 'interestExpense', 'depreciation',
    'otherDeductions', 'totalDeductions', 'ordinaryBusinessIncome',
    'annualTax', 'llcFee', 'totalTax', 'estimatedPayments', 'totalPayments',
    'taxDue', 'overpayment', 'partnerCount',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaForm565(data);
    final method = _accountingMethods.any((e) => e.$1 == '${data['accountingMethod']}')
        ? '${data['accountingMethod']}'
        : 'accrual';
    return OrganizerSection(
      title: 'CA Form 565 — Partnership Return of Income',
      subtitle: 'Federal Form 1065 counterpart. Annual tax \$800 + LLC fee bands by total income.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('Total income', _money(summary['totalIncome']!)),
              ('Ordinary business income', _money(summary['ordinaryBusinessIncome']!)),
              ('LLC fee (est.)', _money(summary['llcFee']!)),
              ('Total tax (est.)', _money(summary['totalTax']!)),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          OrganizerTextField(
            label: 'Partnership / LLC name',
            value: '${data['partnershipName'] ?? ''}',
            onChanged: (v) => _patch('partnershipName', v),
          ),
          OrganizerTextField(
            label: 'CA FEIN',
            value: '${data['feinCA'] ?? ''}',
            onChanged: (v) => _patch('feinCA', v),
          ),
          OrganizerTextField(
            label: 'CA Secretary of State No.',
            value: '${data['caSecretaryOfStateNo'] ?? ''}',
            onChanged: (v) => _patch('caSecretaryOfStateNo', v),
          ),
          OrganizerDropdown<String>(
            label: 'Accounting method',
            value: method,
            items: _accountingMethods,
            onChanged: (v) => _patch('accountingMethod', v ?? 'accrual'),
          ),
          OrganizerMoneyField(
            label: 'Partner count',
            value: data['partnerCount'],
            onChanged: (v) => _patch('partnerCount', v.round()),
          ),
          for (final f in const [
            ('Gross receipts', 'grossReceipts'),
            ('Returns & allowances', 'returnsAllowances'),
            ('Cost of goods sold', 'costOfGoodsSold'),
            ('Gross profit', 'grossProfit'),
            ('Ordinary income', 'ordinaryIncome'),
            ('Rental income', 'rentalIncome'),
            ('Interest income', 'interestIncome'),
            ('Dividend income', 'dividendIncome'),
            ('Royalty income', 'royaltyIncome'),
            ('Capital gains', 'capitalGains'),
            ('Other income', 'otherIncome'),
            ('Total income', 'totalIncome'),
            ('Salaries & wages', 'salariesWages'),
            ('Guaranteed payments', 'guaranteedPayments'),
            ('Repairs', 'repairsExpense'),
            ('Bad debts', 'badDebts'),
            ('Rents expense', 'rentsExpense'),
            ('Taxes & licenses', 'taxesLicenses'),
            ('Interest expense', 'interestExpense'),
            ('Depreciation', 'depreciation'),
            ('Other deductions', 'otherDeductions'),
            ('Total deductions', 'totalDeductions'),
            ('Ordinary business income', 'ordinaryBusinessIncome'),
            ('Annual tax', 'annualTax'),
            ('LLC fee', 'llcFee'),
            ('Total tax', 'totalTax'),
            ('Estimated payments', 'estimatedPayments'),
            ('Total payments', 'totalPayments'),
            ('Tax due', 'taxDue'),
            ('Overpayment', 'overpayment'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}

class _CaForm541 extends StatelessWidget {
  const _CaForm541({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'estateName', 'feinCA', 'fiduciaryName', 'fiduciaryAddress', 'entityType',
    'interest', 'dividends', 'businessIncome', 'capitalGains', 'rents',
    'farmIncome', 'ordinaryGains', 'otherIncome', 'totalIncome',
    'interestExpense', 'taxes', 'fiduciaryFees', 'charitableDeduction',
    'attorneyFees', 'otherDeductions', 'totalDeductions', 'incomeDistDeduction',
    'exemptionAmount', 'taxableIncome', 'caTax', 'amt', 'totalTax',
    'estimatedPayments', 'withholdingPayments', 'totalPayments', 'taxDue',
    'overpayment', 'beneficiaryCount',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaForm541(data);
    final entityType = _fiduciaryTypes.any((e) => e.$1 == '${data['entityType']}')
        ? '${data['entityType']}'
        : 'estate';
    return OrganizerSection(
      title: 'CA Form 541 — Fiduciary Income Tax Return',
      subtitle: 'Federal Form 1041 counterpart for estates and trusts.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('Total income', _money(summary['totalIncome']!)),
              ('Taxable income (est.)', _money(summary['taxableIncome']!)),
              ('Total tax', _money(summary['totalTax']!)),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          OrganizerTextField(
            label: 'Estate / trust name',
            value: '${data['estateName'] ?? ''}',
            onChanged: (v) => _patch('estateName', v),
          ),
          OrganizerTextField(
            label: 'CA FEIN',
            value: '${data['feinCA'] ?? ''}',
            onChanged: (v) => _patch('feinCA', v),
          ),
          OrganizerTextField(
            label: 'Fiduciary name',
            value: '${data['fiduciaryName'] ?? ''}',
            onChanged: (v) => _patch('fiduciaryName', v),
          ),
          OrganizerTextField(
            label: 'Fiduciary address',
            value: '${data['fiduciaryAddress'] ?? ''}',
            onChanged: (v) => _patch('fiduciaryAddress', v),
          ),
          OrganizerDropdown<String>(
            label: 'Entity type',
            value: entityType,
            items: _fiduciaryTypes,
            onChanged: (v) => _patch('entityType', v ?? 'estate'),
          ),
          OrganizerMoneyField(
            label: 'Beneficiary count',
            value: data['beneficiaryCount'],
            onChanged: (v) => _patch('beneficiaryCount', v.round()),
          ),
          for (final f in const [
            ('Interest', 'interest'),
            ('Dividends', 'dividends'),
            ('Business income', 'businessIncome'),
            ('Capital gains', 'capitalGains'),
            ('Rents', 'rents'),
            ('Farm income', 'farmIncome'),
            ('Ordinary gains', 'ordinaryGains'),
            ('Other income', 'otherIncome'),
            ('Total income', 'totalIncome'),
            ('Interest expense', 'interestExpense'),
            ('Taxes', 'taxes'),
            ('Fiduciary fees', 'fiduciaryFees'),
            ('Charitable deduction', 'charitableDeduction'),
            ('Attorney fees', 'attorneyFees'),
            ('Other deductions', 'otherDeductions'),
            ('Total deductions', 'totalDeductions'),
            ('Income distribution deduction', 'incomeDistDeduction'),
            ('Exemption amount', 'exemptionAmount'),
            ('Taxable income', 'taxableIncome'),
            ('CA tax', 'caTax'),
            ('AMT', 'amt'),
            ('Total tax', 'totalTax'),
            ('Estimated payments', 'estimatedPayments'),
            ('Withholding payments', 'withholdingPayments'),
            ('Total payments', 'totalPayments'),
            ('Tax due', 'taxDue'),
            ('Overpayment', 'overpayment'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}

class _CaForm199 extends StatelessWidget {
  const _CaForm199({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'orgName', 'feinCA', 'orgType', 'grossReceipts', 'totalAssets',
    'unrelatedBusinessIncome', 'ubiFederalAmount', 'ubiCAAdditions',
    'ubiCASubtractions', 'ubiTaxableIncome', 'ubiTax', 'minimumTax',
    'totalTax', 'estimatedPayments', 'totalPayments', 'taxDue',
    'overpayment', 'annualRegistrationFee',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaForm199(data);
    return OrganizerSection(
      title: 'CA Form 199 — Exempt Organization Annual Information Return',
      subtitle: 'Federal Form 990 / 990-EZ counterpart. Includes UBI and registration fee.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('UBI taxable income', _money(summary['ubiTaxableIncome']!)),
              ('Total tax + fees (est.)', _money(summary['totalTax']!)),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          OrganizerTextField(
            label: 'Organization name',
            value: '${data['orgName'] ?? ''}',
            onChanged: (v) => _patch('orgName', v),
          ),
          OrganizerTextField(
            label: 'CA FEIN',
            value: '${data['feinCA'] ?? ''}',
            onChanged: (v) => _patch('feinCA', v),
          ),
          OrganizerDropdown<String>(
            label: 'Organization type',
            value: normalizeEnumValue(
              data['orgType'],
              caOrgTypeOptions,
              fallback: '',
            ),
            items: caOrgTypeOptions,
            onChanged: (v) => _patch('orgType', v ?? ''),
          ),
          for (final f in const [
            ('Gross receipts', 'grossReceipts'),
            ('Total assets', 'totalAssets'),
            ('Unrelated business income', 'unrelatedBusinessIncome'),
            ('UBI federal amount', 'ubiFederalAmount'),
            ('CA UBI additions', 'ubiCAAdditions'),
            ('CA UBI subtractions', 'ubiCASubtractions'),
            ('UBI taxable income', 'ubiTaxableIncome'),
            ('UBI tax', 'ubiTax'),
            ('Minimum tax', 'minimumTax'),
            ('Total tax', 'totalTax'),
            ('Estimated payments', 'estimatedPayments'),
            ('Total payments', 'totalPayments'),
            ('Tax due', 'taxDue'),
            ('Overpayment', 'overpayment'),
            ('Annual registration fee', 'annualRegistrationFee'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}

class _CaScheduleR extends StatelessWidget {
  const _CaScheduleR({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'totalSalesEverywhere', 'caSales', 'totalPropertyEverywhere', 'caProperty',
    'totalPayrollEverywhere', 'caPayroll', 'salesFactor', 'propertyFactor',
    'payrollFactor', 'apportionmentPercentage', 'businessIncomeApportioned',
    'nonbusinessIncomeCA', 'totalCAIncome',
  };

  @override
  Widget build(BuildContext context) {
    final summary = summarizeCaScheduleR(data);
    return OrganizerSection(
      title: 'CA Schedule R — Apportionment & Allocation of Income',
      subtitle: 'Sales / property / payroll factors. Modern CA often uses single-sales factor.',
      child: Column(
        children: [
          _EstimateBanner(
            lines: [
              ('Sales factor %', '${summary['salesFactor']}'),
              ('Property factor %', '${summary['propertyFactor']}'),
              ('Payroll factor %', '${summary['payrollFactor']}'),
              ('Apportionment % (est.)', '${summary['apportionmentPercentage']}'),
            ],
            onApply: () => onChanged(applyEstimatePatch(data, summary)),
          ),
          const SizedBox(height: 8),
          for (final f in const [
            ('Total sales everywhere', 'totalSalesEverywhere'),
            ('CA sales', 'caSales'),
            ('Total property everywhere', 'totalPropertyEverywhere'),
            ('CA property', 'caProperty'),
            ('Total payroll everywhere', 'totalPayrollEverywhere'),
            ('CA payroll', 'caPayroll'),
            ('Sales factor %', 'salesFactor'),
            ('Property factor %', 'propertyFactor'),
            ('Payroll factor %', 'payrollFactor'),
            ('Apportionment %', 'apportionmentPercentage'),
            ('Business income apportioned', 'businessIncomeApportioned'),
            ('Nonbusiness income CA', 'nonbusinessIncomeCA'),
            ('Total CA income', 'totalCAIncome'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}

class _CaScheduleK1 extends StatelessWidget {
  const _CaScheduleK1({required this.data, required this.onChanged});
  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _patch(String key, dynamic value) =>
      onChanged(Map<String, dynamic>.from(data)..[key] = value);

  static const _typed = {
    'recipientName', 'recipientTIN', 'recipientType', 'ordinaryIncome',
    'rentalIncome', 'interestIncome', 'dividendIncome', 'capitalGains',
    'section1231Gains', 'otherIncome', 'section179Deduction',
    'charitableContributions', 'investmentInterest', 'otherDeductions',
    'selfEmploymentEarnings', 'caSourceIncome', 'caWithholding',
    'ownershipPercentage',
  };

  @override
  Widget build(BuildContext context) {
    final recipientType = _k1RecipientTypes.any((e) => e.$1 == '${data['recipientType']}')
        ? '${data['recipientType']}'
        : 'individual';
    return OrganizerSection(
      title: 'CA Schedule K-1 — Owner / beneficiary share',
      subtitle: 'Shareholder / partner / beneficiary California-source amounts (generic K-1 intake).',
      child: Column(
        children: [
          OrganizerTextField(
            label: 'Recipient name',
            value: '${data['recipientName'] ?? ''}',
            onChanged: (v) => _patch('recipientName', v),
          ),
          OrganizerTextField(
            label: 'Recipient TIN (last 4 or tokenized)',
            value: '${data['recipientTIN'] ?? ''}',
            onChanged: (v) => _patch('recipientTIN', v),
          ),
          OrganizerDropdown<String>(
            label: 'Recipient type',
            value: recipientType,
            items: _k1RecipientTypes,
            onChanged: (v) => _patch('recipientType', v ?? 'individual'),
          ),
          for (final f in const [
            ('Ordinary income', 'ordinaryIncome'),
            ('Rental income', 'rentalIncome'),
            ('Interest income', 'interestIncome'),
            ('Dividend income', 'dividendIncome'),
            ('Capital gains', 'capitalGains'),
            ('Section 1231 gains', 'section1231Gains'),
            ('Other income', 'otherIncome'),
            ('Section 179 deduction', 'section179Deduction'),
            ('Charitable contributions', 'charitableContributions'),
            ('Investment interest', 'investmentInterest'),
            ('Other deductions', 'otherDeductions'),
            ('Self-employment earnings', 'selfEmploymentEarnings'),
            ('CA-source income', 'caSourceIncome'),
            ('CA withholding', 'caWithholding'),
            ('Ownership %', 'ownershipPercentage'),
          ])
            OrganizerMoneyField(
              label: f.$1,
              value: data[f.$2],
              onChanged: (v) => _patch(f.$2, v),
            ),
          NestedMapEditor(data: data, onChanged: onChanged, excludeKeys: _typed),
        ],
      ),
    );
  }
}
