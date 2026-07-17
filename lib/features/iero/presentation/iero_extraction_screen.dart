import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Mobile clone of financemkgtaxpro "IRS iERO Data Extraction".
class IeroExtractionScreen extends ConsumerStatefulWidget {
  const IeroExtractionScreen({super.key});

  @override
  ConsumerState<IeroExtractionScreen> createState() => _IeroExtractionScreenState();
}

class _IeroExtractionScreenState extends ConsumerState<IeroExtractionScreen> {
  final _zip = TextEditingController();
  final _city = TextEditingController();
  final _quickSearch = TextEditingController();

  String _state = 'all';
  String _radius = '25';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];
  List<Map<String, dynamic>> _directory = const [];

  static const _excludedChains = [
    'H&R Block',
    'Liberty Tax',
    'TurboTax',
    'Intuit',
    'Jackson Hewitt',
    'TaxAct',
    'Cash Store Tax',
    'TaxSlayer',
    'Community Tax',
  ];

  static const _usStates = [
    'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
    'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
    'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY','DC',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _zip.dispose();
    _city.dispose();
    _quickSearch.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final portal = ref.read(portalRepositoryProvider);
      final rows = await Future.wait([
        portal.listEroEfinDirectory(),
        portal.listBureauPreparers(),
      ]);
      final merged = <Map<String, dynamic>>[
        ...rows[0].map((e) => {...e, '_source': 'ero-efin'}),
        ...rows[1].map((e) => {...e, '_source': 'preparer'}),
      ];
      if (!mounted) return;
      setState(() {
        _directory = merged;
        _results = merged;
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

  bool _isExcluded(Map<String, dynamic> row) {
    final blob = [
      row['eroName'],
      row['companyName'],
      row['firstName'],
      row['lastName'],
      row['name'],
    ].whereType<Object>().join(' ').toLowerCase();
    return _excludedChains.any((c) => blob.contains(c.toLowerCase()));
  }

  void _runSearch() {
    final zip = _zip.text.trim();
    final city = _city.text.trim().toLowerCase();
    final q = _quickSearch.text.trim().toLowerCase();
    final filtered = _directory.where((row) {
      if (_isExcluded(row)) return false;
      final rowZip = (row['zip'] ?? row['zipCode'] ?? '').toString();
      final rowCity = (row['city'] ?? '').toString().toLowerCase();
      final rowState = (row['state'] ?? row['licenseState'] ?? '').toString().toUpperCase();
      final name = [
        row['eroName'],
        row['companyName'],
        row['firstName'],
        row['lastName'],
      ].whereType<Object>().join(' ').toLowerCase();

      if (q.isNotEmpty && !name.contains(q) && !rowZip.contains(q) && !rowCity.contains(q)) {
        return false;
      }
      if (zip.isNotEmpty && !rowZip.startsWith(zip)) return false;
      if (city.isNotEmpty && !rowCity.contains(city)) return false;
      if (_state != 'all' && rowState != _state) return false;
      return true;
    }).toList();

    setState(() {
      _results = filtered;
      _error = null;
    });
  }

  int get _independent => _results.where((r) => !_isExcluded(r)).length;
  int get _inCrm => _results.where((r) => r['userId'] != null || r['_source'] == 'preparer').length;
  int get _prospects => _results.where((r) => r['_source'] == 'ero-efin').length;
  int get _pending => (_independent - _inCrm).clamp(0, 1 << 30);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        TextButton.icon(
          onPressed: () => context.go('/forms'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to Dashboard'),
          style: TextButton.styleFrom(foregroundColor: MkgColors.primary, alignment: Alignment.centerLeft),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => context.go('/forms'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Dashboard'),
            style: FilledButton.styleFrom(
              backgroundColor: MkgColors.lightPrimary,
              foregroundColor: MkgColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'IRS iERO Data Extraction',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: MkgColors.primary,
            fontFamily: 'serif',
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Search the IRS Return Preparer Directory for independent EROs. Major chains and franchises are automatically filtered out.',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _KpiCard(label: 'Total Searched', value: '${_directory.length}', color: const Color(0xFF2563EB), icon: Icons.storage_outlined),
              _KpiCard(label: 'Independent iERO', value: '$_independent', color: MkgColors.green, icon: Icons.verified_user_outlined),
              _KpiCard(label: 'In CRM', value: '$_inCrm', color: const Color(0xFF7C3AED), icon: Icons.groups_outlined),
              _KpiCard(label: 'In ERO Prospects', value: '$_prospects', color: MkgColors.orange, icon: Icons.description_outlined),
              _KpiCard(label: 'Pending Import', value: '$_pending', color: MkgColors.red, icon: Icons.trending_up),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quickSearch,
                decoration: const InputDecoration(
                  hintText: 'Search IRS Directory',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: MkgColors.surfaceGrey,
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _results = _directory.where((r) => !_isExcluded(r)).toList();
                });
              },
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Saved'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.public, color: MkgColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'IRS Authorized e-File Provider Search',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Results are filtered to exclude major tax chains and franchises.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(controller: _zip, decoration: const InputDecoration(labelText: 'ZIP Code', hintText: 'e.g., 93721')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All States')),
                    ..._usStates.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() => _state = v ?? 'all'),
                ),
                const SizedBox(height: 10),
                TextField(controller: _city, decoration: const InputDecoration(labelText: 'City (optional)', hintText: 'e.g., Fresno')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _radius,
                  decoration: const InputDecoration(labelText: 'Search Radius (miles)'),
                  items: const [
                    DropdownMenuItem(value: '10', child: Text('10 miles')),
                    DropdownMenuItem(value: '25', child: Text('25 miles')),
                    DropdownMenuItem(value: '50', child: Text('50 miles')),
                    DropdownMenuItem(value: '100', child: Text('100 miles')),
                  ],
                  onChanged: (v) => setState(() => _radius = v ?? '25'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loading ? null : _runSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search IRS Directory'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Queries bureau ERO/preparer directories and filters chains client-side. Full IRS RPO live scrape remains on web when available.',
                  style: TextStyle(color: MkgColors.textGrey, fontSize: 11),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.webRoot),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Open full tool on web'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFF9A3412)),
            SizedBox(width: 8),
            Text(
              'Excluded Chains & Franchises',
              style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in _excludedChains)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(c, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Publicly traded tax chains are excluded to focus on independent mom-and-pop ERO offices.',
          style: TextStyle(color: MkgColors.textGrey, fontSize: 12),
        ),
        const SectionHeader('Search results'),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Card(child: ListTile(title: Text(_error!), trailing: TextButton(onPressed: _bootstrap, child: const Text('Retry'))))
        else if (_results.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No independent EROs matched'),
              subtitle: Text('Try another ZIP/state, or open the web tool for live IRS RPO queries.'),
            ),
          )
        else
          for (final row in _results.take(50))
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: MkgColors.lightPrimary,
                  child: Icon(Icons.storefront_outlined, color: MkgColors.primary),
                ),
                title: Text(
                  (row['eroName'] ??
                          row['companyName'] ??
                          '${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'.trim())
                      .toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if ((row['city'] ?? '').toString().isNotEmpty) row['city'],
                    if ((row['state'] ?? row['licenseState'] ?? '').toString().isNotEmpty) (row['state'] ?? row['licenseState']),
                    if ((row['zip'] ?? '').toString().isNotEmpty) row['zip'],
                    if ((row['efin'] ?? '').toString().isNotEmpty) 'EFIN ${row['efin']}',
                    if ((row['ptin'] ?? '').toString().isNotEmpty) 'PTIN ${row['ptin']}',
                  ].join(' · '),
                ),
                trailing: StatusChip(
                  label: (row['_source'] ?? 'iero').toString(),
                  color: MkgColors.primary,
                ),
              ),
            ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: MkgColors.textGrey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
