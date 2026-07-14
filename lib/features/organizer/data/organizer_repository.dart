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

  /// Load (or create) the draft for [preferredYear], never silently swapping years.
  Future<OrganizerLoadResult> loadCurrent({int? preferredYear, dynamic returnId}) async {
    final defaults = await OrganizerDefaults.load();
    final year = preferredYear ??
        (defaults['filingYear'] as num?)?.toInt() ??
        DateTime.now().year - 1;
    defaults['filingYear'] = year;

    if (returnId != null) {
      final one = await _api.get('/api/tax-returns/$returnId');
      if (one.statusCode == 200 && one.data is Map && one.data['id'] != null) {
        return _fromRow(Map<String, dynamic>.from(one.data as Map), defaults, year);
      }
    }

    final listRes = await _api.get('/api/tax-returns');
    final rows = <Map<String, dynamic>>[];
    if (listRes.data is List) {
      for (final e in listRes.data as List) {
        if (e is Map) rows.add(Map<String, dynamic>.from(e));
      }
    } else if (listRes.data is Map && listRes.data['data'] is List) {
      for (final e in listRes.data['data'] as List) {
        if (e is Map) rows.add(Map<String, dynamic>.from(e));
      }
    }

    Map<String, dynamic>? match;
    for (final row in rows) {
      final y = (row['year'] as num?)?.toInt();
      if (y == year) {
        match = row;
        break;
      }
    }

    // Prefer an exact-year draft; otherwise create for that year.
    if (match != null) {
      return _fromRow(match, defaults, year);
    }

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
      // Last resort: current endpoint if list/create failed.
      final current = await _api.get('/api/tax-returns/current');
      if (current.statusCode == 200 && current.data is Map && current.data['id'] != null) {
        final row = Map<String, dynamic>.from(current.data as Map);
        final rowYear = (row['year'] as num?)?.toInt() ?? year;
        if (rowYear == year) {
          return _fromRow(row, defaults, year);
        }
      }
      throw StateError('Could not load or create tax return for TY $year (${created.statusCode}).');
    }
    return _fromRow(Map<String, dynamic>.from(created.data as Map), defaults, year);
  }

  OrganizerLoadResult _fromRow(
    Map<String, dynamic> row,
    Map<String, dynamic> defaults,
    int fallbackYear,
  ) {
    final existing = Map<String, dynamic>.from((row['data'] as Map?) ?? {});
    final merged = deepMergeOrganizer(defaults, existing);
    final year = (row['year'] as num?)?.toInt() ??
        (merged['filingYear'] as num?)?.toInt() ??
        fallbackYear;
    merged['filingYear'] = year;
    return OrganizerLoadResult(
      returnId: row['id'],
      year: year,
      status: '${row['status'] ?? 'draft'}',
      filingStatus: '${row['filingStatus'] ?? merged['filingStatus'] ?? 'single'}',
      data: merged,
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
        'data': {
          ...data,
          'filingYear': year,
          'source': 'mkg-tax-mobile',
          'clientPlatform': 'flutter',
        },
      },
    );
    if ((res.statusCode ?? 500) >= 300) {
      throw StateError('Save failed (${res.statusCode}).');
    }
  }
}
