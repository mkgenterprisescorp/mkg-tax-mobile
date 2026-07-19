import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../data/state_tax_resources.dart';

/// Official DOR / forms / refund / portal links for all 50 states + DC.
class StateTaxResourcesScreen extends ConsumerStatefulWidget {
  const StateTaxResourcesScreen({super.key});

  @override
  ConsumerState<StateTaxResourcesScreen> createState() => _StateTaxResourcesScreenState();
}

class _StateTaxResourcesScreenState extends ConsumerState<StateTaxResourcesScreen> {
  bool _loading = true;
  String? _error;
  String _source = 'bundled';
  Map<String, dynamic> _federal = const {};
  List<StateTaxResource> _states = const [];
  String _query = '';
  String? _regionFilter;

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
      final result = await ref.read(stateTaxResourcesRepositoryProvider).load();
      if (!mounted) return;
      setState(() {
        _federal = result.federal;
        _states = result.states;
        _source = result.source;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorMapper.map(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<StateTaxResource> get _filtered {
    final q = _query.trim().toLowerCase();
    return [
      for (final s in _states)
        if ((_regionFilter == null || s.regionId == _regionFilter) &&
            (q.isEmpty ||
                s.code.toLowerCase().contains(q) ||
                s.name.toLowerCase().contains(q) ||
                s.regionName.toLowerCase().contains(q)))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final regions = <(String, String)>{
      for (final s in _states) (s.regionId, s.regionName),
    }.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.go('/tax-center'), icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Text('Tax Resources', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const Text(
            'Official agency sites, tax forms, refund status, and taxpayer portals for every jurisdiction.',
            style: TextStyle(color: MkgColors.textGrey),
          ),
          const SizedBox(height: 4),
          Text('Source: $_source', style: const TextStyle(color: MkgColors.textGrey, fontSize: 11)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else ...[
            const SectionHeader('Federal'),
            _LinkCard(
              title: 'IRS',
              subtitle: 'Agency · forms · Where\'s My Refund',
              onAgency: () => _open(_federal['agency_url']?.toString()),
              onForms: () => _open(_federal['forms_url']?.toString()),
              onRefund: () => _open(_federal['refund_tracker_url']?.toString()),
              onPortal: () => _open(_federal['taxpayer_portal_url']?.toString()),
            ),
            const SizedBox(height: 16),
            const SectionHeader('States & DC'),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search state',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All regions'),
                  selected: _regionFilter == null,
                  onSelected: (_) => setState(() => _regionFilter = null),
                ),
                for (final r in regions)
                  ChoiceChip(
                    label: Text('R${r.$1} ${r.$2}'),
                    selected: _regionFilter == r.$1,
                    onSelected: (_) => setState(() => _regionFilter = r.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in _filtered)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: MkgColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      s.code,
                      style: const TextStyle(color: MkgColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  title: Text('${s.name} · ${s.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Region ${s.regionId} ${s.regionName}'
                    '${s.hasPersonalIncomeTax ? '' : ' · no personal income tax'}',
                  ),
                  children: [
                    _tile('Tax agency', s.agencyUrl, Icons.account_balance),
                    _tile('Tax forms', s.formsUrl, Icons.description_outlined),
                    _tile(
                      s.refundTrackerUrl == null ? 'Where\'s My Refund (N/A)' : 'Where\'s My Refund',
                      s.refundTrackerUrl,
                      Icons.savings_outlined,
                      enabled: s.refundTrackerUrl != null,
                    ),
                    _tile('Taxpayer portal', s.taxpayerPortalUrl, Icons.login),
                    _tile('E-file', s.efileUrl, Icons.upload_file_outlined),
                    const Divider(height: 8),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Form families', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    for (final entry in _formFamilyEntries(s))
                      _tile(entry.$1, entry.$2, Icons.link, enabled: entry.$2 != null),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<(String, String?)> _formFamilyEntries(StateTaxResource s) => [
        ('Individual (1040)', s.formUrls['individual']),
        ('Business', s.formUrls['business']),
        ('Corporate (1120)', s.formUrls['corporate']),
        ('Partnership (1065)', s.formUrls['partnership']),
        ('S corporation (1120-S)', s.formUrls['s_corporation']),
        ('Fiduciary (1041)', s.formUrls['fiduciary']),
        ('Exempt organization (990)', s.formUrls['exempt_organization']),
        ('Withholding / payroll', s.formUrls['withholding_payroll']),
        ('Sales & use tax', s.formUrls['sales_use']),
      ];

  Widget _tile(String title, String? url, IconData icon, {bool enabled = true}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: enabled ? MkgColors.primary : MkgColors.textGrey),
      title: Text(title),
      subtitle: Text(
        enabled ? (url ?? '—') : 'Not applicable',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: enabled ? const Icon(Icons.open_in_new, size: 18) : null,
      onTap: enabled ? () => _open(url) : null,
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.title,
    required this.subtitle,
    required this.onAgency,
    required this.onForms,
    required this.onRefund,
    required this.onPortal,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAgency;
  final VoidCallback onForms;
  final VoidCallback onRefund;
  final VoidCallback onPortal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(subtitle, style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: onAgency, child: const Text('Agency')),
                OutlinedButton(onPressed: onForms, child: const Text('Forms')),
                FilledButton.tonal(onPressed: onRefund, child: const Text('Refund')),
                OutlinedButton(onPressed: onPortal, child: const Text('Portal')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
