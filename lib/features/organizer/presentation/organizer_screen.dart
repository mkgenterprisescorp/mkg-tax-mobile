import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/tax_year/tax_year_selector.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Figma consent + Schedule A style multi-step organizer.
class OrganizerScreen extends ConsumerStatefulWidget {
  const OrganizerScreen({super.key});

  @override
  ConsumerState<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends ConsumerState<OrganizerScreen> {
  int _step = 0;
  bool _saving = false;

  // Consent to Use
  final _useTaxpayer = TextEditingController();
  final _useJoint = TextEditingController();
  // Consent to Disclose
  final _discloseTaxpayer = TextEditingController();
  final _discloseJoint = TextEditingController();
  // Schedule A — medical
  final _medical = <String, TextEditingController>{
    'Medical & Dental': TextEditingController(),
    'Prescriptions': TextEditingController(),
    'Hospital Insurance': TextEditingController(),
    'Hospital & Emergency': TextEditingController(),
    'Lab & X-Ray': TextEditingController(),
    'Dental': TextEditingController(),
    'Glasses & Contact Lenses': TextEditingController(),
    'Medical Miles Driven': TextEditingController(),
  };
  // Schedule A — taxes / contributions
  final _taxes = <String, TextEditingController>{
    'Real Estate': TextEditingController(),
    'Personal Property': TextEditingController(),
    'State Income Taxes': TextEditingController(),
    'Church': TextEditingController(),
    'United Way': TextEditingController(),
    'Home Mortgage Interest': TextEditingController(),
  };

  static const _titles = [
    'Consent to Use',
    'Consent to Disclose',
    'Medical & Dental',
    'Taxes & Contributions',
    'Review',
  ];

  @override
  void dispose() {
    _useTaxpayer.dispose();
    _useJoint.dispose();
    _discloseTaxpayer.dispose();
    _discloseJoint.dispose();
    for (final c in _medical.values) {
      c.dispose();
    }
    for (final c in _taxes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _payload() {
    return {
      'consentToUse': {
        'printedNameTaxpayer': _useTaxpayer.text.trim(),
        'printedNameJoint': _useJoint.text.trim(),
        'signedAt': DateTime.now().toIso8601String(),
      },
      'consentToDisclose': {
        'printedNameTaxpayer': _discloseTaxpayer.text.trim(),
        'printedNameJoint': _discloseJoint.text.trim(),
        'signedAt': DateTime.now().toIso8601String(),
      },
      'scheduleA': {
        'medical': {for (final e in _medical.entries) e.key: e.value.text.trim()},
        'taxesAndContributions': {for (final e in _taxes.entries) e.key: e.value.text.trim()},
      },
      'source': 'mkg-tax-mobile',
      'figmaFlow': 'tax-filling-app-v2',
    };
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      // Load current return then PUT merged organizer data (financemkgtaxpro contract).
      final current = await api.get('/api/tax-returns/current');
      if (current.statusCode == 200 && current.data is Map && current.data['id'] != null) {
        final id = current.data['id'];
        final existing = Map<String, dynamic>.from((current.data['data'] as Map?) ?? {});
        existing['mobileOrganizer'] = _payload();
        final res = await api.put('/api/tax-returns/$id', data: {'data': existing});
        if (!mounted) return;
        if ((res.statusCode ?? 500) < 300) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to financemkgtaxpro tax return.')),
          );
          context.go('/home');
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save return (${current.statusCode}). Sign in and ensure a tax year exists.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tax = ref.watch(taxYearProvider);
    final year = tax.selectedYear ?? tax.currentFilingYear;
    return Column(
      children: [
        const TaxYearSelectorBar(dense: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tax year ${year ?? '—'} · Organizer ${tax.workspace?.organizerCompletionPercentage ?? 0}%',
                style: const TextStyle(color: MkgColors.textGrey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_step + 1) / _titles.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text('Step ${_step + 1} of ${_titles.length} · ${_titles[_step]}',
                  style: const TextStyle(color: MkgColors.textGrey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ..._buildStep(),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => setState(() => _step--),
                        child: const Text('BACK'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () {
                              if (_step < _titles.length - 1) {
                                setState(() => _step++);
                              } else {
                                _submit();
                              }
                            },
                      child: _saving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_step < _titles.length - 1 ? 'NEXT' : 'SUBMIT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStep() {
    switch (_step) {
      case 0:
        return [
          const SectionHeader('Consent to Use of Tax Return Information'),
          const Text(
            'Federal law requires this consent form be provided to you. By continuing, you authorize MKG Tax Consultants to use your tax return information as described in the portal consent.',
            style: TextStyle(height: 1.4, color: MkgColors.textGrey),
          ),
          const SizedBox(height: 16),
          TextField(controller: _useTaxpayer, decoration: const InputDecoration(labelText: 'Printed Name Of Taxpayer')),
          const SizedBox(height: 12),
          TextField(controller: _useJoint, decoration: const InputDecoration(labelText: 'Printed Name Of Joint Taxpayer (optional)')),
        ];
      case 1:
        return [
          const SectionHeader('Consent to Disclose Tax Return Information'),
          const Text(
            'By signing below, you authorize disclosure of your tax return information to MKG Tax Consultants as required for preparation and related services.',
            style: TextStyle(height: 1.4, color: MkgColors.textGrey),
          ),
          const SizedBox(height: 16),
          TextField(controller: _discloseTaxpayer, decoration: const InputDecoration(labelText: 'Printed Name Of Taxpayer')),
          const SizedBox(height: 12),
          TextField(controller: _discloseJoint, decoration: const InputDecoration(labelText: 'Printed Name Of Joint Taxpayer (optional)')),
        ];
      case 2:
        return [
          const SectionHeader('Medical & Dental Expenses'),
          for (final e in _medical.entries) ...[
            TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: e.key),
            ),
            const SizedBox(height: 10),
          ],
        ];
      case 3:
        return [
          const SectionHeader('Taxes & Contributions'),
          for (final e in _taxes.entries) ...[
            TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: e.key),
            ),
            const SizedBox(height: 10),
          ],
        ];
      default:
        return [
          const SectionHeader('Review & submit'),
          Card(
            child: ListTile(
              title: const Text('Consent to Use'),
              subtitle: Text(_useTaxpayer.text.isEmpty ? 'Missing taxpayer name' : _useTaxpayer.text),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Consent to Disclose'),
              subtitle: Text(_discloseTaxpayer.text.isEmpty ? 'Missing taxpayer name' : _discloseTaxpayer.text),
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('Destination'),
              subtitle: Text('PUT /api/tax-returns/:id on financemkgtax.com'),
            ),
          ),
        ];
    }
  }
}
