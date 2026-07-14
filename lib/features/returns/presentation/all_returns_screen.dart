import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';
import '../../auth/data/auth_repository.dart';

/// Mobile clone of financemkgtaxpro "All Tax Returns" card grid.
class AllReturnsScreen extends ConsumerStatefulWidget {
  const AllReturnsScreen({super.key});

  @override
  ConsumerState<AllReturnsScreen> createState() => _AllReturnsScreenState();
}

class _AllReturnsScreenState extends ConsumerState<AllReturnsScreen> {
  List<Map<String, dynamic>> _returns = const [];
  bool _loading = true;
  bool _lockingAll = false;
  String? _error;
  String _query = '';
  String _year = 'all';
  String _status = 'all';
  int? _selectedId;

  static const _staffRoles = {
    'super_user',
    'admin',
    'manager',
    'regional_manager',
    'district_manager',
    'office_manager',
    'tax_preparer',
    'ea',
    'cpa',
    'loan_officer',
    'processor',
    'tax_attorney',
    'realtor',
    'insurance_agent',
    'ero',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(portalRepositoryProvider).listAllTaxReturns();
      if (!mounted) return;
      setState(() {
        _returns = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _isStaff {
    final role = ref.read(authProvider).user?.role ?? 'client';
    return _staffRoles.contains(role);
  }

  bool _isLocked(Map<String, dynamic> r) {
    final s = (r['status'] ?? '').toString().toLowerCase();
    return s == 'processing' || s == 'completed' || s == 'filed' || s == 'accepted';
  }

  List<Map<String, dynamic>> get _filtered {
    return _returns.where((r) {
      final name = (r['clientName'] ?? '').toString().toLowerCase();
      final email = (r['email'] ?? r['clientEmail'] ?? '').toString().toLowerCase();
      final phone = (r['phone'] ?? '').toString().toLowerCase();
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty && !(name.contains(q) || email.contains(q) || phone.contains(q))) {
        return false;
      }
      if (_year != 'all' && '${r['year']}' != _year) return false;
      if (_status != 'all' && (r['status'] ?? 'draft').toString() != _status) return false;
      return true;
    }).toList();
  }

  Set<String> get _years {
    final y = _returns.map((r) => '${r['year'] ?? ''}').where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return y.toSet();
  }

  Future<void> _toggleLock(Map<String, dynamic> r) async {
    final id = r['id'];
    if (id == null) return;
    final lock = !_isLocked(r);
    try {
      await ref.read(portalRepositoryProvider).toggleReturnLock(id, lock: lock);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _lockAllDrafts() async {
    if (!_isStaff) return;
    setState(() => _lockingAll = true);
    final portal = ref.read(portalRepositoryProvider);
    var ok = 0;
    var fail = 0;
    for (final r in _returns.where((e) => (e['status'] ?? '') == 'draft')) {
      try {
        await portal.toggleReturnLock(r['id'], lock: true);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    await _load();
    if (mounted) {
      setState(() => _lockingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locked $ok draft return(s)${fail > 0 ? ' · $fail failed' : ''}')),
      );
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return '—';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _filingStatus(Map<String, dynamic> r) {
    final data = r['data'];
    if (data is Map) {
      final fs = (data['filingStatus'] ?? r['filingStatus'] ?? '').toString();
      if (fs.isNotEmpty) {
        return fs.replaceAll('_', ' ').split(' ').map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1)}';
        }).join(' ');
      }
    }
    final fs = (r['filingStatus'] ?? '').toString();
    if (fs.isEmpty) return '—';
    return fs.replaceAll('_', ' ');
  }

  String _contact(Map<String, dynamic> r) {
    final phone = (r['phone'] ?? '').toString();
    final email = (r['email'] ?? r['clientEmail'] ?? '').toString();
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return (r['returnNumber'] ?? 'Return #${r['id']}').toString();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final lockedCount = _returns.where(_isLocked).length;
    final clientIds = _returns.map((r) => r['userId']).whereType<Object>().toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextButton.icon(
            onPressed: () => context.go('/forms'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Dashboard'),
            style: TextButton.styleFrom(foregroundColor: MkgColors.primary, alignment: Alignment.centerLeft),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.description_outlined, color: MkgColors.primary, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isStaff ? 'All Tax Returns' : 'My Tax Returns',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: MkgColors.primary,
                    height: 1.1,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isStaff
                ? 'View and manage all client returns and organizers across tax years.'
                : 'View and manage your tax returns and organizers.',
            style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatBadge(
                label: '$lockedCount locked',
                color: MkgColors.red,
                filled: false,
                icon: Icons.lock_outline,
              ),
              _StatBadge(label: '${_returns.length} returns', color: MkgColors.textGrey, filled: false),
              _StatBadge(label: '$clientIds clients', color: MkgColors.textGrey, filled: false),
              _StatBadge(label: '${_returns.length} total', color: MkgColors.accent, filled: true),
            ],
          ),
          if (_isStaff) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: const Text('Reports'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _lockingAll ? null : _lockAllDrafts,
                    style: FilledButton.styleFrom(backgroundColor: MkgColors.red, minimumSize: const Size.fromHeight(44)),
                    icon: _lockingAll
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_outline, size: 18),
                    label: Text(_lockingAll ? 'Locking…' : 'Lock All Returns'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search client name or email...',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: MkgColors.surfaceGrey,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _year,
                  decoration: const InputDecoration(labelText: 'Year', isDense: true),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Years')),
                    ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y))),
                  ],
                  onChanged: (v) => setState(() => _year = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'draft', child: Text('draft')),
                    DropdownMenuItem(value: 'processing', child: Text('processing')),
                    DropdownMenuItem(value: 'completed', child: Text('completed')),
                    DropdownMenuItem(value: 'filed', child: Text('filed')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${filtered.length} results', style: const TextStyle(color: MkgColors.textGrey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: MkgColors.red),
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (filtered.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No returns found'),
                subtitle: Text('Adjust filters or start a return from the dashboard.'),
              ),
            )
          else
            ...filtered.map(_buildCard),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final name = (r['clientName'] ?? 'Unknown Client').toString();
    final status = (r['status'] ?? 'draft').toString();
    final year = (r['year'] ?? '—').toString();
    final locked = _isLocked(r);
    final selected = _selectedId == r['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? MkgColors.primary : const Color(0xFFE2EDE6),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedId = r['id'] as int?),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: MkgColors.lightPrimary,
                    foregroundColor: MkgColors.primary,
                    child: Text(_initials(name), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(_contact(r), style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip(label: status, color: locked ? MkgColors.red : MkgColors.textGrey),
                  StatusChip(label: 'TY $year', color: MkgColors.primary),
                  StatusChip(label: _filingStatus(r), color: MkgColors.textGrey),
                ],
              ),
              if (locked) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: MkgColors.red),
                    SizedBox(width: 4),
                    Text('Locked for processing', style: TextStyle(color: MkgColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: MkgColors.textGrey),
                  const SizedBox(width: 4),
                  Text('Updated ${_fmtDate(r['updatedAt'] ?? r['createdAt'])}', style: const TextStyle(color: MkgColors.textGrey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go('/organizer'),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Open Return'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                  if (_isStaff) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => _toggleLock(r),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        child: Icon(locked ? Icons.lock_open : Icons.lock_outline, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.color,
    required this.filled,
    this.icon,
  });

  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.85) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: filled ? Colors.black87 : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.black87 : color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
