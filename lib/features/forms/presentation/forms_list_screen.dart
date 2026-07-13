import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

class TaxFormItem {
  const TaxFormItem(this.name, this.status, {this.route});
  final String name;
  final String status; // not_started | in_progress | completed
  final String? route;
}

const demoForms = <TaxFormItem>[
  TaxFormItem('Fillable Client Data Sheet', 'in_progress', route: '/organizer'),
  TaxFormItem('Self Employment Form', 'not_started'),
  TaxFormItem('Filing Status Flow Chart', 'not_started'),
  TaxFormItem('Schedule A Itemized Deduction', 'completed'),
  TaxFormItem('Consent to Use', 'completed'),
  TaxFormItem('Consent to Disclose', 'not_started'),
  TaxFormItem('Borrower Disclosures', 'not_started'),
  TaxFormItem('TILA / Interest Rate', 'not_started'),
];

class FormsListScreen extends StatelessWidget {
  const FormsListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return MkgColors.primary;
      case 'in_progress':
        return MkgColors.green;
      default:
        return MkgColors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Not Started';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MkgColors.primary, Color(0xFF004A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your 2025 tax forms',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusChip(label: 'Demo session', color: Colors.white),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.go('/profile'),
                    icon: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
                    label: const Text('Verify Profile', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader('Forms List'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: demoForms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final form = demoForms[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (form.route != null) {
                    context.go(form.route!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${form.name} wizard coming next.')),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MkgColors.lightPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description_outlined, color: MkgColors.primary),
                      ),
                      const Spacer(),
                      Text(
                        form.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25),
                      ),
                      const SizedBox(height: 8),
                      StatusChip(label: _statusLabel(form.status), color: _statusColor(form.status)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const SectionHeader('Quick links'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open, color: MkgColors.primary),
                title: const Text('Upload documents'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/documents'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined, color: MkgColors.primary),
                title: const Text('Ask Tessa'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/tessa'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.support_agent, color: MkgColors.primary),
                title: const Text('Contact support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/support'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
