import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/tax_year/tax_year_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../documents/data/documents_repository.dart';
import '../data/bookkeeping_close_settings.dart';

/// Bookkeeping hub — wired to portal intake, documents, banking, and payroll.
class BookkeepingScreen extends ConsumerStatefulWidget {
  const BookkeepingScreen({super.key});

  @override
  ConsumerState<BookkeepingScreen> createState() => _BookkeepingScreenState();
}

class _BookkeepingScreenState extends ConsumerState<BookkeepingScreen> {
  bool _loadingDocs = true;
  int _docCount = 0;
  String? _docsError;

  static final _intakeUri = Uri.parse(
    'https://${AppConfig.canonicalPortalHost}/bookkeeping-intake',
  );
  static final _serviceUri = Uri.parse(
    'https://${AppConfig.canonicalPortalHost}/business-services/bookkeeping-payroll',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loadingDocs = true;
      _docsError = null;
    });
    try {
      await ref.read(taxYearProvider.notifier).refreshWorkspace();
      final workspaceId = ref.read(taxYearProvider).workspace?.workspaceId;
      if (workspaceId == null) {
        if (!mounted) return;
        setState(() {
          _loadingDocs = false;
          _docCount = 0;
          _docsError = 'Select a tax year workspace, then upload statements.';
        });
        return;
      }
      final docs = await ref.read(documentsRepositoryProvider).list(workspaceId);
      if (!mounted) return;
      setState(() {
        _docCount = docs.length;
        _loadingDocs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDocs = false;
        _docsError = 'Documents will appear after you sign in and upload statements.';
        _docCount = 0;
      });
    }
  }

  Future<void> _openUri(Uri uri) async {
    final safe = AppConfig.rewriteLegacyPortalUri(uri);
    await launchUrl(safe, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(bookkeepingCloseProvider);
    final now = DateTime.now();
    final monthLabel = _monthLabel(now);
    final closePct = BookkeepingCloseSettings.checklistIds.isEmpty
        ? 0.0
        : completed.length / BookkeepingCloseSettings.checklistIds.length;

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text('Bookkeeping', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Monthly books, statement uploads, and payroll coordination with MKG.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthLabel close',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '${completed.length} of ${BookkeepingCloseSettings.checklistIds.length} steps complete',
                  style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: closePct,
                    minHeight: 8,
                    backgroundColor: MkgColors.surfaceGrey,
                    color: MkgColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Get started'),
          _ActionTile(
            icon: Icons.assignment_outlined,
            title: 'Bookkeeping + payroll intake',
            subtitle: 'Full portal intake (11 sections) — same form as web',
            onTap: () => _openUri(_intakeUri),
          ),
          _ActionTile(
            icon: Icons.upload_file_outlined,
            title: 'Upload statements & receipts',
            subtitle: _loadingDocs
                ? 'Loading documents…'
                : (_docsError ??
                    (_docCount == 0
                        ? 'No uploads yet — add bank/card statements here'
                        : '$_docCount document(s) on file · tap to manage')),
            onTap: () => context.go('/documents'),
          ),
          _ActionTile(
            icon: Icons.document_scanner_outlined,
            title: 'Smart document intake',
            subtitle: 'W-2 / PDF extraction into your organizer when available',
            onTap: () => context.go('/documents/smart-intake'),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Monthly close checklist'),
          const Text(
            'Track this month’s close. Tap a step to mark it done or open the related tool.',
            style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final item in _closeItems)
            _ChecklistTile(
              title: item.title,
              subtitle: item.subtitle,
              done: completed.contains(item.id),
              onToggle: () => ref.read(bookkeepingCloseProvider.notifier).toggle(item.id),
              onOpen: item.route == null
                  ? (item.external == null ? null : () => _openUri(item.external!))
                  : () => context.go(item.route!),
            ),
          const SizedBox(height: 8),
          const SectionHeader('Transactions to categorize'),
          MkgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank & card activity',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload statements and receipts. Your MKG bookkeeper categorizes '
                  'transactions during monthly close — there is no in-app ledger sync yet.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.go('/documents'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Upload bank / card statements'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/tessa'),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Ask Tessa about categorization'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Related tools'),
          _ActionTile(
            icon: Icons.account_balance_outlined,
            title: 'Banking connections',
            subtitle: 'Connection status (no money movement in-app)',
            onTap: () => context.go('/banking'),
          ),
          _ActionTile(
            icon: Icons.payments_outlined,
            title: 'Payroll tools',
            subtitle: 'W-4 / paycheck estimates',
            onTap: () => context.go('/payroll-tools'),
          ),
          _ActionTile(
            icon: Icons.receipt_outlined,
            title: 'Bookkeeping fees & invoices',
            subtitle: 'Fee schedule and hosted payments',
            onTap: () => context.go('/billing'),
          ),
          _ActionTile(
            icon: Icons.info_outline,
            title: 'Bookkeeping & payroll services',
            subtitle: 'Learn more on mkgtaxconsultants.com',
            onTap: () => _openUri(_serviceUri),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  static final _closeItems = <_CloseItem>[
    _CloseItem(
      id: 'intake',
      title: 'Complete bookkeeping intake',
      subtitle: 'Business setup on the portal form',
      external: _intakeUri,
    ),
    _CloseItem(
      id: 'bank_statements',
      title: 'Upload bank statements',
      subtitle: 'All accounts for this month',
      route: '/documents',
    ),
    _CloseItem(
      id: 'card_statements',
      title: 'Upload credit card statements',
      subtitle: 'Business cards used this month',
      route: '/documents',
    ),
    _CloseItem(
      id: 'receipts',
      title: 'Upload receipts / invoices',
      subtitle: 'Expenses and vendor bills',
      route: '/documents',
    ),
    _CloseItem(
      id: 'payroll',
      title: 'Review payroll',
      subtitle: 'Pay rates, hours, and W-4 tools',
      route: '/payroll-tools',
    ),
    _CloseItem(
      id: 'review',
      title: 'Confirm close with MKG',
      subtitle: 'Message your bookkeeper / Tessa',
      route: '/tessa',
    ),
  ];
}

class _CloseItem {
  const _CloseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.route,
    this.external,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? route;
  final Uri? external;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MkgColors.lightPrimary,
          child: Icon(icon, color: MkgColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onToggle,
    this.onOpen,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: IconButton(
          tooltip: done ? 'Mark incomplete' : 'Mark complete',
          onPressed: onToggle,
          icon: Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? MkgColors.green : MkgColors.textGrey,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: onOpen == null ? null : const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}
