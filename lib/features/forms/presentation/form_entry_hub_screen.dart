import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class _FormEntryTarget {
  const _FormEntryTarget({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.prepType,
    required this.focus,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final String prepType;
  final String focus;
  final IconData icon;
}

/// Choose interview vs direct input for core return forms (no Flutter tax math).
class FormEntryHubScreen extends StatelessWidget {
  const FormEntryHubScreen({super.key});

  static const _targets = <_FormEntryTarget>[
    _FormEntryTarget(
      id: '1040',
      title: 'Form 1040',
      subtitle: 'Wages, interest, credits & deductions',
      prepType: 'personal',
      focus: 'income_1040',
      icon: Icons.description_outlined,
    ),
    _FormEntryTarget(
      id: '540',
      title: 'CA Form 540',
      subtitle: 'California resident return lines',
      prepType: 'personal',
      focus: 'state_returns',
      icon: Icons.map_outlined,
    ),
    _FormEntryTarget(
      id: 'schedule_c',
      title: 'Schedule C',
      subtitle: 'Sole proprietor business income',
      prepType: 'business',
      focus: 'schedule_c',
      icon: Icons.storefront_outlined,
    ),
    _FormEntryTarget(
      id: '1120s',
      title: 'Form 1120-S',
      subtitle: 'S corporation entity return',
      prepType: '1120s',
      focus: 'entity_form',
      icon: Icons.apartment_outlined,
    ),
    _FormEntryTarget(
      id: '1120',
      title: 'Form 1120',
      subtitle: 'C corporation entity return',
      prepType: '1120',
      focus: 'entity_form',
      icon: Icons.business_outlined,
    ),
  ];

  void _open(BuildContext context, _FormEntryTarget t, String mode) {
    final q = Uri(
      path: '/organizer',
      queryParameters: {
        'mode': mode,
        'focus': t.focus,
        'prep': t.prepType,
      },
    ).toString();
    context.go(q);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/tools'), icon: const Icon(Icons.arrow_back)),
            const Expanded(
              child: Text('Form entry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const Text(
          'Interview mode asks guided questions so credits and deductions are not overlooked. '
          'Direct input opens the Organizer section for power users. All calculations stay on Laravel.',
          style: TextStyle(color: MkgColors.textGrey, height: 1.35),
        ),
        const SizedBox(height: 14),
        for (final t in _targets)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(t.icon, color: MkgColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(t.subtitle, style: const TextStyle(color: MkgColors.textGrey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _open(context, t, 'interview'),
                        child: const Text('Interview mode'),
                      ),
                      OutlinedButton(
                        onPressed: () => _open(context, t, 'direct'),
                        child: const Text('Direct input'),
                      ),
                      if (t.id == '1040')
                        TextButton(
                          onPressed: () => context.go('/organizer/form-1040'),
                          child: const Text('1040 preview'),
                        ),
                      if (t.id == '540')
                        TextButton(
                          onPressed: () => context.go('/ca-540'),
                          child: const Text('540 estimate'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        MkgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maximize return workflow', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '1) Complete interview/direct entry · 2) Tax savings checklist · '
                '3) Tessa planning value savings · 4) Preview 1040/540 in-app.',
                style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.go('/tax-savings'),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Open tax savings interview'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
