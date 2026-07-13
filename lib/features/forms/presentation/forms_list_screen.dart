import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

class FormsListScreen extends ConsumerStatefulWidget {
  const FormsListScreen({super.key});

  @override
  ConsumerState<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends ConsumerState<FormsListScreen> {
  Map<String, dynamic>? _taxReturn;
  bool _loadingReturn = true;

  @override
  void initState() {
    super.initState();
    _loadReturn();
  }

  Future<void> _loadReturn() async {
    try {
      final data = await ref.read(authRepositoryProvider).currentTaxReturn();
      if (mounted) setState(() {
        _taxReturn = data;
        _loadingReturn = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReturn = false);
    }
  }

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
    final user = ref.watch(authProvider).user;
    final returnStatus = (_taxReturn?['status'] ?? 'draft').toString();
    final taxYear = (_taxReturn?['taxYear'] ?? _taxReturn?['year'] ?? DateTime.now().year).toString();

    final forms = <TaxFormItem>[
      TaxFormItem('Tax Organizer ($taxYear)', returnStatus == 'draft' ? 'in_progress' : 'in_progress', route: '/organizer'),
      const TaxFormItem('Upload Documents', 'not_started', route: '/documents'),
      const TaxFormItem('Identity / KYC', 'not_started', route: '/profile'),
      const TaxFormItem('Fee Agreement / Billing', 'not_started', route: '/billing'),
      const TaxFormItem('Refund Tracker', 'not_started', route: '/account'),
      const TaxFormItem('Ask TaxPro Assist', 'not_started', route: '/tessa'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MkgColors.primary, MkgColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                user?.displayName ?? 'Client',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(label: 'financemkgtax.com', color: Colors.white),
                  if (user?.kycStatus != null)
                    StatusChip(label: 'KYC: ${user!.kycStatus}', color: MkgColors.accent),
                  if (_loadingReturn)
                    const StatusChip(label: 'Loading return…', color: Colors.white)
                  else if (_taxReturn != null)
                    StatusChip(label: 'Return $taxYear · $returnStatus', color: Colors.white)
                  else
                    const StatusChip(label: 'No return yet', color: Colors.white),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader('Client portal hub'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: forms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            final form = forms[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (form.route != null) context.go(form.route!);
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
      ],
    );
  }
}

class TaxFormItem {
  const TaxFormItem(this.name, this.status, {this.route});
  final String name;
  final String status;
  final String? route;
}
