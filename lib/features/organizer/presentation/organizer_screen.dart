import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/organizer_defaults.dart';
import '../data/organizer_repository.dart';
import 'organizer_fields.dart';

/// Tax Organizer — personal + business parity with financemkgtaxpro `/organizer`.
/// Saves into canonical `tax_returns.data` keys (not `mobileOrganizer`).
class OrganizerScreen extends ConsumerStatefulWidget {
  const OrganizerScreen({super.key});

  @override
  ConsumerState<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends ConsumerState<OrganizerScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  dynamic _returnId;
  int _year = DateTime.now().year - 1;
  String _status = 'draft';
  int _step = 0;
  Map<String, dynamic> _data = {};

  List<String> get _steps {
    final prep = '${_data['prepType'] ?? 'personal'}';
    final steps = stepsForPrepType(prep);
    if (!businessEntityTypes.contains(prep) && !showScheduleCStep(_data)) {
      return steps.where((s) => s != 'Schedule C').toList();
    }
    return steps;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tax = ref.read(taxYearProvider);
      final preferred = tax.selectedYear ?? tax.currentFilingYear;
      final result = await ref.read(organizerRepositoryProvider).loadCurrent(preferredYear: preferred);
      if (!mounted) return;
      setState(() {
        _returnId = result.returnId;
        _year = result.year;
        _status = result.status;
        _data = result.data;
        _data['filingStatus'] = result.filingStatus;
        _loading = false;
        _step = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _setRoot(String key, dynamic value) {
    setState(() => _data = Map<String, dynamic>.from(_data)..[key] = value);
  }

  void _setNested(String nestKey, Map<String, dynamic> value) {
    setState(() => _data = Map<String, dynamic>.from(_data)..[nestKey] = value);
  }

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from((_data[key] as Map?) ?? {});

  Future<void> _save({bool submit = false}) async {
    setState(() => _saving = true);
    try {
      final status = submit ? 'processing' : 'draft';
      final filingStatus = '${_data['filingStatus'] ?? 'single'}';
      await ref.read(organizerRepositoryProvider).save(
            returnId: _returnId,
            year: _year,
            status: status,
            filingStatus: filingStatus,
            data: {
              ..._data,
              'source': 'mkg-tax-mobile',
              'clientPlatform': 'flutter',
            },
          );
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(submit ? 'Submitted for processing.' : 'Draft saved.')),
      );
      if (submit) context.go('/tax-center');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _next() async {
    await _save();
    if (!mounted) return;
    if (_step >= _steps.length - 1) {
      await _save(submit: true);
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) {
      context.go('/tax-center');
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: MkgColors.primary));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final steps = _steps;
    final stepIndex = _step.clamp(0, steps.length - 1);
    final title = steps[stepIndex];
    final locked = _status == 'processing' || _status == 'completed' || _status == 'filed' || _status == 'accepted';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tax Organizer · TY $_year',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: locked || _saving ? null : () => _save(), child: const Text('Save')),
          ],
        ),
        Text('Status: $_status · Return #$_returnId', style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
        const SizedBox(height: 12),
        _StepProgress(steps: steps, index: stepIndex),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MkgColors.primary)),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: locked,
          child: KeyedSubtree(
            key: ValueKey('org-step-$title-$stepIndex'),
            child: _buildStep(title),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _back,
                child: Text(stepIndex == 0 ? 'Tax Center' : 'Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: locked || _saving ? null : _next,
                child: Text(
                  _saving
                      ? 'Saving…'
                      : stepIndex >= steps.length - 1
                          ? 'Submit'
                          : 'Save & Continue',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep(String title) {
    final prep = '${_data['prepType'] ?? 'personal'}';
    if (title == 'Filing Info') return _filingInfoStep();
    if (title == 'Personal Info') return _personalInfoStep();
    if (title == 'Income (1040)') return _incomeStep();
    if (title == 'Credits & Deductions') return _creditsStep();
    if (title == 'Schedule C') return _scheduleCStep();
    if (title == 'CA 540 State Tax') return _ca540Step();
    if (title == 'Direct Deposit') return _directDepositStep();
    if (title == 'Review & Sign') return _reviewStep();
    if (businessEntityTypes.contains(prep) && title.contains('Form')) {
      return _entityFormStep(prep);
    }
    return const Text('Unknown step');
  }

  Widget _filingInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrganizerSection(
          title: 'Filing type',
          subtitle: 'Matches financemkgtaxpro prepType — personal, Schedule C business, or entity returns.',
          child: OrganizerDropdown<String>(
            label: 'Preparation type',
            value: '${_data['prepType'] ?? 'personal'}',
            items: prepTypeOptions,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _data = Map<String, dynamic>.from(_data)..['prepType'] = v;
                _step = 0;
              });
            },
          ),
        ),
        OrganizerDropdown<String>(
          label: 'Filing status',
          value: '${_data['filingStatus'] ?? 'single'}',
          items: filingStatusOptions,
          onChanged: (v) => _setRoot('filingStatus', v ?? 'single'),
        ),
        OrganizerTextField(
          label: 'Filing year',
          value: '${_data['filingYear'] ?? _year}',
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final y = int.tryParse(v);
            if (y != null) {
              _year = y;
              _setRoot('filingYear', y);
            }
          },
        ),
        const MkgCard(
          child: Text(
            'Personal & Schedule C use the 1040 workflow. Entity types (1120, 1120-S, 1065, 990-EZ, etc.) use a shorter entity form flow — same schemas as the web portal.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _personalInfoStep() {
    return Column(
      children: [
        OrganizerSection(
          title: 'Taxpayer',
          child: Column(
            children: [
              OrganizerTextField(label: 'First name', value: '${_data['firstName'] ?? ''}', onChanged: (v) => _setRoot('firstName', v)),
              OrganizerTextField(label: 'Middle initial', value: '${_data['middleInitial'] ?? ''}', onChanged: (v) => _setRoot('middleInitial', v)),
              OrganizerTextField(label: 'Last name', value: '${_data['lastName'] ?? ''}', onChanged: (v) => _setRoot('lastName', v)),
              OrganizerTextField(label: 'SSN / ITIN', value: '${_data['ssn'] ?? ''}', onChanged: (v) => _setRoot('ssn', v)),
              OrganizerTextField(label: 'Date of birth', value: '${_data['dateOfBirth'] ?? ''}', onChanged: (v) => _setRoot('dateOfBirth', v)),
              OrganizerTextField(label: 'Phone', value: '${_data['phone'] ?? ''}', onChanged: (v) => _setRoot('phone', v)),
              OrganizerTextField(label: 'Email', value: '${_data['email'] ?? ''}', onChanged: (v) => _setRoot('email', v)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Address',
          child: Column(
            children: [
              OrganizerTextField(label: 'Street', value: '${_data['address'] ?? ''}', onChanged: (v) => _setRoot('address', v)),
              OrganizerTextField(label: 'Apt / Suite', value: '${_data['apartment'] ?? ''}', onChanged: (v) => _setRoot('apartment', v)),
              OrganizerTextField(label: 'City', value: '${_data['city'] ?? ''}', onChanged: (v) => _setRoot('city', v)),
              OrganizerTextField(label: 'State', value: '${_data['state'] ?? ''}', onChanged: (v) => _setRoot('state', v)),
              OrganizerTextField(label: 'ZIP', value: '${_data['zip'] ?? ''}', onChanged: (v) => _setRoot('zip', v)),
            ],
          ),
        ),
        if ('${_data['filingStatus']}' == 'married_joint' || '${_data['filingStatus']}' == 'married_separate')
          OrganizerSection(
            title: 'Spouse',
            child: Column(
              children: [
                OrganizerTextField(label: 'Spouse first name', value: '${_data['spouseFirstName'] ?? ''}', onChanged: (v) => _setRoot('spouseFirstName', v)),
                OrganizerTextField(label: 'Spouse last name', value: '${_data['spouseLastName'] ?? ''}', onChanged: (v) => _setRoot('spouseLastName', v)),
                OrganizerTextField(label: 'Spouse SSN', value: '${_data['spouseSSN'] ?? ''}', onChanged: (v) => _setRoot('spouseSSN', v)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _incomeStep() {
    final scheduleE = _map('scheduleE');
    final rentals = List<Map<String, dynamic>>.from(
      ((scheduleE['rentalProperties'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    return Column(
      children: [
        OrganizerSection(
          title: 'Income summary (1040)',
          child: Column(
            children: [
              OrganizerMoneyField(label: 'Wages (W-2)', value: _data['wages'], onChanged: (v) => _setRoot('wages', v)),
              OrganizerMoneyField(label: 'Federal tax withheld', value: _data['taxWithheld'], onChanged: (v) => _setRoot('taxWithheld', v)),
              OrganizerMoneyField(label: 'Interest income', value: _data['interestIncome'], onChanged: (v) => _setRoot('interestIncome', v)),
              OrganizerMoneyField(label: 'Dividend income', value: _data['dividendIncome'], onChanged: (v) => _setRoot('dividendIncome', v)),
              OrganizerMoneyField(label: 'Business income (Schedule C)', value: _data['businessIncome'], onChanged: (v) => _setRoot('businessIncome', v)),
              OrganizerMoneyField(label: 'Capital gains', value: _data['capitalGains'], onChanged: (v) => _setRoot('capitalGains', v)),
              OrganizerMoneyField(label: 'Rental income', value: _data['rentalIncome'], onChanged: (v) => _setRoot('rentalIncome', v)),
              OrganizerMoneyField(label: 'Unemployment', value: _data['unemploymentComp'], onChanged: (v) => _setRoot('unemploymentComp', v)),
              OrganizerMoneyField(label: 'Social Security benefits', value: _data['socialSecurityBenefits'], onChanged: (v) => _setRoot('socialSecurityBenefits', v)),
              OrganizerMoneyField(label: 'Other income', value: _data['otherIncome'], onChanged: (v) => _setRoot('otherIncome', v)),
            ],
          ),
        ),
        OrganizerSection(
          title: 'Schedule E — Rental / Royalty',
          subtitle: 'Same rentalProperties[] schema as web Organizer.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rentals.length; i++) ...[
                MkgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Property ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            onPressed: () {
                              final next = List<Map<String, dynamic>>.from(rentals)..removeAt(i);
                              _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                            },
                            icon: const Icon(Icons.delete_outline, color: MkgColors.red),
                          ),
                        ],
                      ),
                      OrganizerTextField(
                        label: 'Address',
                        value: '${rentals[i]['address'] ?? ''}',
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(rentals);
                          next[i] = Map<String, dynamic>.from(next[i])..['address'] = v;
                          _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                        },
                      ),
                      for (final field in const [
                        ('rentReceived', 'Rent received'),
                        ('mortgage', 'Mortgage interest'),
                        ('insurance', 'Insurance'),
                        ('repairs', 'Repairs'),
                        ('taxes', 'Taxes'),
                        ('utilities', 'Utilities'),
                        ('depreciation', 'Depreciation'),
                        ('advertising', 'Advertising'),
                        ('otherExpenses', 'Other expenses'),
                      ])
                        OrganizerMoneyField(
                          label: field.$2,
                          value: rentals[i][field.$1],
                          onChanged: (v) {
                            final next = List<Map<String, dynamic>>.from(rentals);
                            next[i] = Map<String, dynamic>.from(next[i])..[field.$1] = v;
                            _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  final next = [...rentals, emptyRentalProperty()];
                  _setNested('scheduleE', {...scheduleE, 'rentalProperties': next});
                },
                icon: const Icon(Icons.add),
                label: const Text('Add rental property'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _creditsStep() {
    final scheduleA = _map('scheduleA');
    return Column(
      children: [
        OrganizerSection(
          title: 'Adjustments & credits',
          child: Column(
            children: [
              OrganizerMoneyField(label: 'Educator expenses', value: _data['educatorExpenses'], onChanged: (v) => _setRoot('educatorExpenses', v)),
              OrganizerMoneyField(label: 'Student loan interest', value: _data['studentLoanInterest'], onChanged: (v) => _setRoot('studentLoanInterest', v)),
              OrganizerMoneyField(label: 'IRA deduction', value: _data['iraDeduction'], onChanged: (v) => _setRoot('iraDeduction', v)),
              OrganizerMoneyField(label: 'Dependent care expenses', value: _data['dependentCareExpenses'], onChanged: (v) => _setRoot('dependentCareExpenses', v)),
              OrganizerCheckbox(
                label: 'Itemize deductions (Schedule A)',
                value: _data['itemizeDeductions'] == true,
                onChanged: (v) => _setRoot('itemizeDeductions', v),
              ),
            ],
          ),
        ),
        if (_data['itemizeDeductions'] == true)
          OrganizerSection(
            title: 'Schedule A',
            child: NestedMapEditor(
              data: scheduleA,
              onChanged: (m) => _setNested('scheduleA', m),
            ),
          ),
      ],
    );
  }

  Widget _scheduleCStep() {
    final scheduleC = _map('scheduleC');
    const identity = [
      'businessName',
      'businessEIN',
      'businessAddress',
      'businessApartment',
      'businessCity',
      'businessState',
      'businessZip',
      'businessType',
      'accountingMethod',
    ];
    final expenseKeys = scheduleC.keys.where((k) => !identity.contains(k)).toList();
    return Column(
      children: [
        OrganizerSection(
          title: 'Business identity',
          subtitle: 'Schedule C — Profit or Loss From Business (sole prop / gig).',
          child: NestedMapEditor(
            data: scheduleC,
            onlyKeys: identity,
            onChanged: (m) => _setNested('scheduleC', m),
          ),
        ),
        OrganizerSection(
          title: 'Income & expenses',
          child: NestedMapEditor(
            data: scheduleC,
            onlyKeys: expenseKeys,
            onChanged: (m) => _setNested('scheduleC', m),
          ),
        ),
      ],
    );
  }

  Widget _ca540Step() {
    final ca540 = _map('ca540');
    return OrganizerSection(
      title: 'California Form 540',
      subtitle: 'Key CA fields from web organizer (server may recalculate AGI/tax).',
      child: NestedMapEditor(
        data: ca540.isEmpty
            ? {
                'caWages': _data['wages'] ?? 0,
                'caTaxWithheld': 0,
                'caEstimatedPayments': 0,
                'residencyStatus': 'resident',
              }
            : ca540,
        onChanged: (m) => _setNested('ca540', m),
      ),
    );
  }

  Widget _directDepositStep() {
    return OrganizerSection(
      title: 'Banking / direct deposit',
      child: Column(
        children: [
          OrganizerTextField(label: 'Bank name', value: '${_data['bankName'] ?? ''}', onChanged: (v) => _setRoot('bankName', v)),
          OrganizerTextField(label: 'Routing number', value: '${_data['routingNumber'] ?? ''}', onChanged: (v) => _setRoot('routingNumber', v)),
          OrganizerTextField(label: 'Account number', value: '${_data['accountNumber'] ?? ''}', onChanged: (v) => _setRoot('accountNumber', v)),
          OrganizerDropdown<String>(
            label: 'Account type',
            value: '${_data['accountType'] ?? 'checking'}',
            items: const [('checking', 'Checking'), ('savings', 'Savings')],
            onChanged: (v) => _setRoot('accountType', v ?? 'checking'),
          ),
        ],
      ),
    );
  }

  Widget _entityFormStep(String prep) {
    final form = _map(prep);
    final labels = businessFormLabels[prep] ?? prep;
    // Prefer identity-ish keys first for usability.
    final keys = form.keys.toList();
    final identityKeys = <String>[];
    for (final k in keys) {
      final lower = k.toLowerCase();
      if (lower.startsWith('schedule')) continue;
      final isId = lower.contains('name') ||
          lower.contains('ein') ||
          lower.contains('address') ||
          lower.contains('year') ||
          lower.contains('type') ||
          lower.contains('code') ||
          lower.contains('date') ||
          lower.contains('number') ||
          lower.contains('partner') ||
          lower.contains('shareholder') ||
          lower.contains('website') ||
          lower.contains('mission') ||
          lower.contains('purpose') ||
          lower.contains('status') ||
          lower.contains('city') ||
          lower == 'state' ||
          lower.contains('zip');
      if (isId) identityKeys.add(k);
      if (identityKeys.length >= 18) break;
    }
    final rest = keys.where((k) => !identityKeys.contains(k)).toList();

    return Column(
      children: [
        OrganizerSection(
          title: labels,
          subtitle: 'Field names match financemkgtaxpro `$prep` in tax_returns.data.',
          child: NestedMapEditor(
            data: form,
            onlyKeys: identityKeys.isEmpty ? keys.take(12).toList() : identityKeys,
            onChanged: (m) => _setNested(prep, m),
          ),
        ),
        OrganizerSection(
          title: 'Income, deductions & schedules',
          child: NestedMapEditor(
            data: form,
            onlyKeys: rest,
            onChanged: (m) => _setNested(prep, m),
          ),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final prep = '${_data['prepType'] ?? 'personal'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prep type: $prep', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Filing status: ${_data['filingStatus']}'),
              Text('Year: ${_data['filingYear'] ?? _year}'),
              Text('Name: ${_data['firstName'] ?? ''} ${_data['lastName'] ?? ''}'),
              if (prep == 'business' || showScheduleCStep(_data))
                Text('Schedule C: ${_map('scheduleC')['businessName'] ?? '(not named)'}'),
              if ((_map('scheduleE')['rentalProperties'] as List?)?.isNotEmpty == true)
                Text('Schedule E properties: ${(_map('scheduleE')['rentalProperties'] as List).length}'),
              if (businessEntityTypes.contains(prep))
                Text('Entity: ${businessFormLabels[prep]}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrganizerTextField(
          label: 'Typed signature / printed name',
          value: '${_data['typedSignature'] ?? _data['printedName'] ?? ''}',
          onChanged: (v) {
            _setRoot('typedSignature', v);
            _setRoot('printedName', v);
            _setRoot('signatureType', 'type');
          },
        ),
        OrganizerCheckbox(
          label: 'I consent to e-file this return',
          value: _data['consentToEFile'] == true,
          onChanged: (v) => _setRoot('consentToEFile', v),
        ),
        OrganizerCheckbox(
          label: 'I declare under penalty of perjury that this information is true',
          value: _data['consentPerjury'] == true,
          onChanged: (v) => _setRoot('consentPerjury', v),
        ),
        OrganizerCheckbox(
          label: 'Consent to use / disclose tax information (IRC 7216)',
          value: _data['consent7216Use'] == true,
          onChanged: (v) {
            _setRoot('consent7216Use', v);
            _setRoot('consent7216Disclosure', v);
            _setRoot('consentToDisclosure', v);
          },
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.steps, required this.index});

  final List<String> steps;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (index + 1) / steps.length,
            minHeight: 8,
            backgroundColor: MkgColors.surfaceGrey,
            color: MkgColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${index + 1} of ${steps.length}',
          style: const TextStyle(fontSize: 12, color: MkgColors.textGrey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
