import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class _SavingItem {
  const _SavingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.cue,
  });

  final String id;
  final String name;
  final String category;
  final String cue;
}

/// Deduction / credit checklist for clients (estimate planning — not AI analysis).
class TaxSavingsScreen extends StatefulWidget {
  const TaxSavingsScreen({super.key});

  @override
  State<TaxSavingsScreen> createState() => _TaxSavingsScreenState();
}

class _TaxSavingsScreenState extends State<TaxSavingsScreen> {
  static const _items = <_SavingItem>[
    _SavingItem(id: 'ctc', name: 'Child Tax Credit', category: 'Credits', cue: 'Qualifying children under 17'),
    _SavingItem(id: 'eitc', name: 'Earned Income Tax Credit (EITC)', category: 'Credits', cue: 'Income & family size limits'),
    _SavingItem(id: 'cdc', name: 'Child & Dependent Care Credit', category: 'Credits', cue: 'Daycare / after-school care'),
    _SavingItem(id: 'aotc', name: 'American Opportunity Credit', category: 'Credits', cue: 'First 4 years of college'),
    _SavingItem(id: 'llc', name: 'Lifetime Learning Credit', category: 'Credits', cue: 'Tuition and related expenses'),
    _SavingItem(id: 'saver', name: 'Saver’s Credit', category: 'Credits', cue: 'IRA / 401(k) contributions'),
    _SavingItem(id: 'ira', name: 'Traditional IRA deduction', category: 'Above-the-line', cue: 'Contribution limits apply'),
    _SavingItem(id: 'hsa', name: 'HSA contributions', category: 'Above-the-line', cue: 'HDHP required'),
    _SavingItem(id: 'se_health', name: 'Self-employed health insurance', category: 'Above-the-line', cue: 'Schedule C / partnership'),
    _SavingItem(id: 'se_tax', name: 'Deductible half of SE tax', category: 'Above-the-line', cue: 'Self-employment'),
    _SavingItem(id: 'student', name: 'Student loan interest', category: 'Above-the-line', cue: 'Form 1098-E'),
    _SavingItem(id: 'educator', name: 'Educator expenses', category: 'Above-the-line', cue: 'K–12 teachers'),
    _SavingItem(id: 'mortgage', name: 'Mortgage interest', category: 'Itemized', cue: 'Form 1098'),
    _SavingItem(id: 'salt', name: 'State & local taxes (SALT)', category: 'Itemized', cue: 'Cap may apply'),
    _SavingItem(id: 'charity', name: 'Charitable contributions', category: 'Itemized', cue: 'Cash and non-cash'),
    _SavingItem(id: 'medical', name: 'Medical & dental expenses', category: 'Itemized', cue: 'AGI floor applies'),
    _SavingItem(id: 'home_office', name: 'Home office (Schedule C)', category: 'Business', cue: 'Exclusive & regular use'),
    _SavingItem(id: 'vehicle', name: 'Business vehicle / mileage', category: 'Business', cue: 'Keep a contemporaneous log'),
    _SavingItem(id: 'supplies', name: 'Office supplies & software', category: 'Business', cue: 'Ordinary & necessary'),
    _SavingItem(id: 'caleitc', name: 'California CalEITC / YCTC', category: 'California', cue: 'FTB 3514 — CA residents'),
    _SavingItem(id: 'renter', name: 'CA renter’s credit', category: 'California', cue: 'Income limits apply'),
  ];

  /// claimed = true, reviewed-not-claimed = false, untouched = absent
  final Map<String, bool> _status = {};
  String _tab = 'All';

  List<String> get _categories => [
        'All',
        ...{for (final i in _items) i.category},
      ];

  List<_SavingItem> get _filtered {
    if (_tab == 'All') return _items;
    return _items.where((i) => i.category == _tab).toList();
  }

  int get _claimed => _status.values.where((v) => v).length;
  int get _missed => _status.values.where((v) => !v).length;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/tools'), icon: const Icon(Icons.arrow_back)),
            const Expanded(
              child: Text('Tax savings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Mark credits and deductions you already claim or want your preparer to review. Planning checklist only — not a formal tax opinion.',
          style: TextStyle(color: MkgColors.textGrey),
        ),
        const SizedBox(height: 14),
        MkgCard(
          child: Row(
            children: [
              Expanded(child: _stat('Claiming', '$_claimed', MkgColors.green)),
              Expanded(child: _stat('Review', '$_missed', MkgColors.orange)),
              Expanded(child: _stat('Total ideas', '${_items.length}', MkgColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _tab == c,
                    onSelected: (_) => setState(() => _tab = c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final item in _filtered)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(item.cue, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('I claim this'),
                        selected: _status[item.id] == true,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _status[item.id] = true;
                          } else {
                            _status.remove(item.id);
                          }
                        }),
                      ),
                      FilterChip(
                        label: const Text('Ask preparer'),
                        selected: _status[item.id] == false,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _status[item.id] = false;
                          } else {
                            _status.remove(item.id);
                          }
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.go('/organizer'),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Apply ideas in Tax Organizer'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('${AppConfig.portalRoot}/tax-savings'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open AI tax plan on web'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/chat'),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Discuss with an advisor'),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
      ],
    );
  }
}
