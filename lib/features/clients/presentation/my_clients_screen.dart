import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/mkg_theme.dart';
import '../../../core/widgets/mkg_widgets.dart';

/// Professional edition — My Clients (mkgtaxconsultants.com `/my-clients`).
class MyClientsScreen extends ConsumerStatefulWidget {
  const MyClientsScreen({super.key});

  @override
  ConsumerState<MyClientsScreen> createState() => _MyClientsScreenState();
}

class _MyClientsScreenState extends ConsumerState<MyClientsScreen> {
  List<Map<String, dynamic>> _clients = const [];
  String _scope = '';
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final result = await ref.read(portalRepositoryProvider).listClients();
      if (!mounted) return;
      setState(() {
        _clients = result.clients;
        _scope = result.scope;
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

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      final name = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  String _initials(Map<String, dynamic> c) {
    final f = (c['firstName'] ?? '').toString();
    final l = (c['lastName'] ?? '').toString();
    final a = f.isNotEmpty ? f[0] : '';
    final b = l.isNotEmpty ? l[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  String _name(Map<String, dynamic> c) {
    final n = '${c['firstName'] ?? ''} ${c['lastName'] ?? ''}'.trim();
    return n.isEmpty ? (c['email'] ?? 'Client').toString() : n;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'My Clients',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MkgColors.primary,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _scope == 'all'
                ? 'Manage all client accounts across the firm.'
                : _scope == 'assigned'
                    ? 'Clients assigned to you.'
                    : 'Client roster for your professional workspace.',
            style: const TextStyle(color: MkgColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: '${_clients.length} clients', color: MkgColors.primary),
              if (_scope.isNotEmpty) StatusChip(label: 'Scope: $_scope', color: MkgColors.accent),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search client name or email...',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: MkgColors.surfaceGrey,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/all-returns'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('All Returns'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/organizer'),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Organizer'),
                ),
              ),
            ],
          ),
          const SectionHeader('Clients'),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
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
                title: Text('No clients yet'),
                subtitle: Text('Assigned clients will appear here after portal assignment.'),
              ),
            )
          else
            for (final c in filtered)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: MkgColors.lightPrimary,
                    foregroundColor: MkgColors.primary,
                    child: Text(_initials(c), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(_name(c).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(
                    [
                      if ((c['email'] ?? '').toString().isNotEmpty) c['email'],
                      if ((c['phone'] ?? '').toString().isNotEmpty) c['phone'],
                      if ((c['kycStatus'] ?? '').toString().isNotEmpty) 'KYC ${c['kycStatus']}',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/all-returns'),
                ),
              ),
        ],
      ),
    );
  }
}
