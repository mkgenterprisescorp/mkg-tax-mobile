import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'organizer_defaults.dart';

final organizerRepositoryProvider = Provider<OrganizerRepository>((ref) {
  return OrganizerRepository(ref.watch(apiClientProvider));
});

class OrganizerLoadResult {
  const OrganizerLoadResult({
    required this.returnId,
    required this.year,
    required this.status,
    required this.filingStatus,
    required this.data,
  });

  final dynamic returnId;
  final int year;
  final String status;
  final String filingStatus;
  final Map<String, dynamic> data;
}

class OrganizerRepository {
  OrganizerRepository(this._api);

  final ApiClient _api;

  Future<OrganizerLoadResult> loadCurrent({int? preferredYear}) async {
    final defaults = await OrganizerDefaults.load();
    if (preferredYear != null) {
      defaults['filingYear'] = preferredYear;
    }

    final current = await _api.get('/api/tax-returns/current');
    if (current.statusCode == 200 && current.data is Map && current.data['id'] != null) {
      final row = Map<String, dynamic>.from(current.data as Map);
      final existing = Map<String, dynamic>.from((row['data'] as Map?) ?? {});
      final merged = deepMergeOrganizer(defaults, existing);
      final year = (row['year'] as num?)?.toInt() ?? (merged['filingYear'] as num?)?.toInt() ?? preferredYear ?? DateTime.now().year - 1;
      merged['filingYear'] = year;
      return OrganizerLoadResult(
        returnId: row['id'],
        year: year,
        status: '${row['status'] ?? 'draft'}',
        filingStatus: '${row['filingStatus'] ?? merged['filingStatus'] ?? 'single'}',
        data: merged,
      );
    }

    // Create a draft when none exists.
    final year = preferredYear ?? (defaults['filingYear'] as num?)?.toInt() ?? DateTime.now().year - 1;
    defaults['filingYear'] = year;
    final created = await _api.post(
      '/api/tax-returns',
      data: {
        'year': year,
        'status': 'draft',
        'filingStatus': defaults['filingStatus'] ?? 'single',
        'data': defaults,
      },
    );
    if ((created.statusCode ?? 500) >= 300 || created.data is! Map || created.data['id'] == null) {
      throw StateError('Could not load or create tax return (${current.statusCode}/${created.statusCode}).');
    }
    final row = Map<String, dynamic>.from(created.data as Map);
    return OrganizerLoadResult(
      returnId: row['id'],
      year: year,
      status: 'draft',
      filingStatus: '${defaults['filingStatus'] ?? 'single'}',
      data: defaults,
    );
  }

  Future<void> save({
    required dynamic returnId,
    required int year,
    required String status,
    required String filingStatus,
    required Map<String, dynamic> data,
  }) async {
    final res = await _api.put(
      '/api/tax-returns/$returnId',
      data: {
        'year': year,
        'status': status,
        'filingStatus': filingStatus,
        'data': data,
      },
    );
    if ((res.statusCode ?? 500) >= 300) {
      throw StateError('Save failed (${res.statusCode}).');
    }
  }
}
