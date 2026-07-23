import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/entities/data/entities_repository.dart';
import '../api/portal_repository.dart';
import '../config/app_config.dart';
import '../network/api_error_mapper.dart';
import '../network/laravel_api_client.dart';
import '../sync/sync_providers.dart';
import 'return_number.dart';

class TaxYearInfo {
  const TaxYearInfo({
    required this.taxYear,
    required this.label,
    required this.isCurrentFilingYear,
    this.efileAvailable = true,
    this.paperFilingOnly = false,
    this.organizerAvailable = true,
    this.status = 'active',
  });

  final int taxYear;
  final String label;
  final bool isCurrentFilingYear;
  final bool efileAvailable;
  final bool paperFilingOnly;
  final bool organizerAvailable;
  final String status;

  factory TaxYearInfo.fromJson(Map<String, dynamic> json) {
    final year = (json['tax_year'] as num).toInt();
    return TaxYearInfo(
      taxYear: year,
      label: (json['label'] ?? '$year').toString(),
      isCurrentFilingYear: json['is_current_filing_year'] == true,
      efileAvailable: json['efile_available'] != false,
      paperFilingOnly: json['paper_filing_only'] == true,
      organizerAvailable: json['organizer_available'] != false,
      status: (json['status'] ?? 'active').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'tax_year': taxYear,
    'label': label,
    'is_current_filing_year': isCurrentFilingYear,
    'efile_available': efileAvailable,
    'paper_filing_only': paperFilingOnly,
    'organizer_available': organizerAvailable,
    'status': status,
  };
}

class TaxYearWorkspace {
  const TaxYearWorkspace({
    required this.taxYear,
    required this.federalReturnStatus,
    required this.organizerStatus,
    required this.organizerCompletionPercentage,
    this.estimatedRefund,
    this.estimatedBalanceDue,
    this.stateReturns = const [],
    this.documentsCount = 0,
    this.taxReturnId,
    this.workspaceId,
    this.entityId,
    this.returnNumber,
  });

  final int taxYear;
  final String federalReturnStatus;
  final String organizerStatus;
  final int organizerCompletionPercentage;
  final num? estimatedRefund;
  final num? estimatedBalanceDue;
  final List<Map<String, dynamic>> stateReturns;
  final int documentsCount;
  final dynamic taxReturnId;

  /// Laravel `/api/v1` tax-year workspace UUID.
  final String? workspaceId;
  final String? entityId;

  /// Human desk code `{LAST4}-{MM}-{DD}-{SEQ}` (e.g. GOVA-07-19-01).
  final String? returnNumber;

  factory TaxYearWorkspace.fromJson(Map<String, dynamic> json) {
    final states =
        (json['state_workspaces'] as List?) ?? (json['state_returns'] as List?);
    final docs = json['documents'];
    final docsCount =
        (json['documents_count'] as num?)?.toInt() ??
        (docs is List ? docs.length : 0);
    return TaxYearWorkspace(
      taxYear: (json['tax_year'] as num?)?.toInt() ?? 0,
      federalReturnStatus: _humanizeStatus(
        json['federal_return_status'] ?? 'Not Started',
      ),
      organizerStatus: _humanizeStatus(
        json['organizer_status'] ?? 'Not Started',
      ),
      organizerCompletionPercentage:
          (json['organizer_completion_percentage'] as num?)?.toInt() ?? 0,
      estimatedRefund: json['estimated_refund'] as num?,
      estimatedBalanceDue: json['estimated_balance_due'] as num?,
      stateReturns:
          states
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      documentsCount: docsCount,
      taxReturnId: json['tax_return_id'] ?? json['taxReturnId'] ?? json['id'],
      workspaceId: (json['id'] ?? json['workspace_id'])?.toString(),
      entityId: (json['mobile_entity_id'] ?? json['entity_id'])?.toString(),
      returnNumber: ReturnNumber.fromWorkspaceJson(json),
    );
  }

  /// Derive progress from a portal `tax_returns` row (cookie-auth builds).
  factory TaxYearWorkspace.fromPortalReturn(
    Map<String, dynamic> row, {
    int documentsCount = 0,
  }) {
    final year = (row['year'] as num?)?.toInt() ?? 0;
    final status = (row['status'] ?? 'draft').toString();
    final data = Map<String, dynamic>.from((row['data'] as Map?) ?? {});
    final pct = _estimateOrganizerPct(data, status);
    return TaxYearWorkspace(
      taxYear: year,
      federalReturnStatus: status,
      organizerStatus: pct >= 100
          ? 'Complete'
          : pct > 0
          ? 'In Progress'
          : 'Not Started',
      organizerCompletionPercentage: pct,
      documentsCount: documentsCount,
      taxReturnId: row['id'],
      returnNumber: ReturnNumber.fromWorkspaceJson(row),
    );
  }

  Map<String, dynamic> toJson() => {
    'tax_year': taxYear,
    'federal_return_status': federalReturnStatus,
    'organizer_status': organizerStatus,
    'organizer_completion_percentage': organizerCompletionPercentage,
    if (estimatedRefund != null) 'estimated_refund': estimatedRefund,
    if (estimatedBalanceDue != null)
      'estimated_balance_due': estimatedBalanceDue,
    'state_returns': stateReturns,
    'documents_count': documentsCount,
    if (taxReturnId != null) 'tax_return_id': taxReturnId,
    if (workspaceId != null) 'workspace_id': workspaceId,
    if (entityId != null) 'entity_id': entityId,
    if (returnNumber != null) 'return_number': returnNumber,
  };
}

String _humanizeStatus(Object? raw) {
  final s = (raw ?? '').toString();
  if (s.isEmpty) return 'Not Started';
  return s
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

int _estimateOrganizerPct(Map<String, dynamic> data, String status) {
  if (status == 'processing' ||
      status == 'filed' ||
      status == 'accepted' ||
      status == 'completed') {
    return 100;
  }
  var score = 0;
  var total = 8;
  if ('${data['prepType'] ?? ''}'.isNotEmpty) score++;
  if ('${data['firstName'] ?? ''}'.trim().isNotEmpty &&
      '${data['lastName'] ?? ''}'.trim().isNotEmpty) {
    score++;
  }
  final wages = data['wages'];
  final hasIncome =
      (wages is num && wages > 0) ||
      ((data['w2Forms'] as List?)?.isNotEmpty ?? false) ||
      ((data['scheduleE'] is Map) &&
          ((data['scheduleE']['rentalProperties'] as List?)?.isNotEmpty ??
              false));
  if (hasIncome) score++;
  if (data['itemizeDeductions'] == true || (data['scheduleA'] is Map)) score++;
  final sc = data['scheduleC'];
  if (sc is Map && '${sc['businessName'] ?? ''}'.trim().isNotEmpty) score++;
  if (data['ca540'] is Map) score++;
  if ('${data['routingNumber'] ?? ''}'.trim().isNotEmpty) score++;
  if (data['consentPerjury'] == true || data['consentToEFile'] == true) score++;
  // Entity prep
  for (final k in [
    'form1120',
    'form1120S',
    'form1065',
    'form990EZ',
    'form990',
    'form1041',
  ]) {
    final m = data[k];
    if (m is Map &&
        m.values.any((v) => v != null && '$v'.trim().isNotEmpty && v != 0)) {
      score = (score + 2).clamp(0, total);
      break;
    }
  }
  return ((score / total) * 100).round().clamp(0, 100);
}

class MobileDashboardBootstrap {
  const MobileDashboardBootstrap({
    this.years = const [],
    this.currentFilingYear,
    this.selectedYear,
    this.catalogSource,
    this.workspace,
    this.tasks = const [],
  });

  final List<TaxYearInfo> years;
  final int? currentFilingYear;
  final int? selectedYear;
  final String? catalogSource;
  final TaxYearWorkspace? workspace;
  final List<Map<String, dynamic>> tasks;

  bool get hasDashboardData => years.isNotEmpty || workspace != null;

  factory MobileDashboardBootstrap.fromJson(Map<String, dynamic> root) {
    final payload = _asMap(root['data']) ?? root;
    final catalog =
        _asMap(payload['tax_year_catalog']) ??
        _asMap(payload['catalog']) ??
        _asMap(payload['taxYears']) ??
        _asMap(payload['tax_years']);
    final yearsRaw =
        _asList(payload['years']) ??
        _asList(payload['tax_years']) ??
        _asList(payload['taxYears']) ??
        _asList(catalog?['years']) ??
        const [];
    final years = yearsRaw
        .whereType<Map>()
        .map((e) => TaxYearInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta =
        _asMap(payload['meta']) ??
        _asMap(catalog?['meta']) ??
        _asMap(payload['tax_year_meta']);
    final workspaceMap =
        _asMap(payload['workspace']) ??
        _asMap(payload['tax_year_workspace']) ??
        _asMap(payload['active_workspace']) ??
        (_looksLikeWorkspace(payload) ? payload : null);
    final workspace = workspaceMap == null
        ? null
        : TaxYearWorkspace.fromJson(workspaceMap);
    final current =
        _intFrom(
          meta?['current_filing_tax_year'] ??
              meta?['currentFilingTaxYear'] ??
              payload['current_filing_tax_year'] ??
              payload['currentFilingTaxYear'],
        ) ??
        (years.isNotEmpty
            ? years
                  .firstWhere(
                    (y) => y.isCurrentFilingYear,
                    orElse: () => years.first,
                  )
                  .taxYear
            : null);
    final selected =
        _intFrom(
          payload['selected_tax_year'] ??
              payload['selectedTaxYear'] ??
              payload['tax_year'],
        ) ??
        workspace?.taxYear ??
        current;
    final tasks =
        (_asList(payload['tasks']) ??
                _asList(workspaceMap?['tasks']) ??
                const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    return MobileDashboardBootstrap(
      years: years,
      currentFilingYear: current,
      selectedYear: selected,
      catalogSource: (meta?['source'] ?? payload['source'] ?? 'laravel')
          .toString(),
      workspace: workspace,
      tasks: tasks,
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<dynamic>? _asList(Object? value) => value is List ? value : null;

  static int? _intFrom(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  static bool _looksLikeWorkspace(Map<String, dynamic> value) {
    return value.containsKey('tax_year') &&
        (value.containsKey('organizer_completion_percentage') ||
            value.containsKey('federal_return_status') ||
            value.containsKey('workspace_id'));
  }
}

class TaxYearRepository {
  TaxYearRepository(this._api);
  final LaravelApiClient _api;

  /// Server-authoritative 10-year list (`GET /api/v1/tax-years`).
  /// Falls back to local computation if Laravel is unreachable.
  Future<({List<TaxYearInfo> years, int current, String source})>
  listTaxYears() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/tax-years');
      if ((res.statusCode ?? 500) < 400 && res.data != null) {
        final payload = res.data!['data'];
        List yearsRaw = const [];
        Map<String, dynamic>? meta;
        if (payload is Map) {
          yearsRaw = (payload['years'] as List?) ?? const [];
          meta = payload['meta'] is Map
              ? Map<String, dynamic>.from(payload['meta'] as Map)
              : null;
        } else if (payload is List) {
          // Legacy shape compatibility.
          yearsRaw = payload;
        }
        final data = yearsRaw
            .whereType<Map>()
            .map((e) => TaxYearInfo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final current =
            (meta?['current_filing_tax_year'] as num?)?.toInt() ??
            (data.isNotEmpty ? data.first.taxYear : _localCurrentFilingYear());
        if (data.isNotEmpty) {
          return (years: data, current: current, source: 'laravel');
        }
      }
    } catch (_) {
      // fall through
    }
    return _localCatalog();
  }

  /// Lightweight dashboard bootstrap (`GET /api/v1/mobile/bootstrap`).
  ///
  /// The endpoint is expected to return catalog/workspace/task summaries only;
  /// full organizer payloads are deliberately ignored by the dashboard path.
  Future<MobileDashboardBootstrap?> mobileBootstrap({int? taxYear}) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.mobileBootstrap(taxYear: taxYear);
    final code = res.statusCode ?? 500;
    if (code == 404 || code == 405) return null;
    if (code >= 400 || res.data == null) {
      throw StateError(
        'We’re unable to refresh your dashboard right now. Please try again.',
      );
    }
    final bootstrap = MobileDashboardBootstrap.fromJson(res.data!);
    return bootstrap.hasDashboardData ? bootstrap : null;
  }

  /// Activate (or fetch) a tax-year workspace for an entity.
  ///
  /// Throws [StateError] with a safe, user-facing message on auth / API failure
  /// so Sanctum builds never silently fall through to a cookie-portal workspace
  /// (portal rows have no Laravel `workspaceId`, which breaks Tax Organizer).
  ///
  /// Prefer [activateWorkspacePacked] when the caller can reuse embedded
  /// organizer/tasks (avoids follow-up GETs on staging).
  Future<TaxYearWorkspace> activateWorkspace({
    required String entityId,
    required int taxYear,
  }) async {
    final packed = await activateWorkspacePacked(
      entityId: entityId,
      taxYear: taxYear,
    );
    return packed.workspace;
  }

  /// Activate and return the embedded organizer/tasks snapshot in one round-trip.
  Future<WorkspaceActivation> activateWorkspacePacked({
    required String entityId,
    required int taxYear,
  }) async {
    await _api.ensureBearerFromStorage();
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to open your tax organizer.');
    }
    // Activate embeds organizer + tasks; staging Neon often needs > default timeouts.
    final writeOptions = Options(
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    );
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _api.post<Map<String, dynamic>>(
          '/api/v1/entities/$entityId/tax-years/activate',
          data: {'tax_year': taxYear},
          options: writeOptions,
        );
        final code = res.statusCode ?? 500;
        if (code >= 400 || res.data == null) {
          throw StateError(_activateFailureMessage(code));
        }
        final data = res.data!['data'];
        if (data is! Map) {
          throw StateError('We’re unable to open your tax organizer right now. Please try again.');
        }
        final map = Map<String, dynamic>.from(data);
        final workspace = TaxYearWorkspace.fromJson(map);
        if ((workspace.workspaceId ?? '').isEmpty) {
          throw StateError('No tax-year workspace. Select a year and try again.');
        }
        final organizer = map['organizer'] is Map
            ? Map<String, dynamic>.from(map['organizer'] as Map)
            : null;
        final tasks = (map['tasks'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const <Map<String, dynamic>>[];
        return WorkspaceActivation(
          workspace: workspace,
          tasks: tasks,
          organizer: organizer,
          tasksEmbedded: map.containsKey('tasks'),
        );
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode;
        final retryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            status == 502 ||
            status == 503 ||
            status == 504;
        if (!retryable || attempt >= 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      } on StateError catch (e) {
        lastError = e;
        // Retry once on generic open failures (transient upstream).
        if (attempt >= 1 || !e.message.contains('unable to open your tax organizer')) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    final err = lastError;
    if (err != null) throw err;
    throw StateError('We’re unable to open your tax organizer right now. Please try again.');
  }

  static String _activateFailureMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Please sign in again to open your tax organizer.';
      case 403:
        return 'This action is not authorized.';
      case 404:
        return 'No tax-year workspace. Select a year and try again.';
      case 422:
        return 'Some information could not be validated. Please check your entries and try again.';
      case 429:
        return 'Too many requests — wait a moment and try again.';
      default:
        return 'We’re unable to open your tax organizer right now. Please try again.';
    }
  }

  Future<TaxYearWorkspace?> getWorkspaceById(String workspaceId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId',
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return TaxYearWorkspace.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>?> getOrganizer(String workspaceId) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> listDocuments(String workspaceId) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/documents',
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return const [];
    return (res.data!['data'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  Future<List<Map<String, dynamic>>> listTasks(String workspaceId) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/tasks',
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return const [];
    return (res.data!['data'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  Future<Map<String, dynamic>> addState(
    String workspaceId,
    String stateCode, {
    String residencyType = 'resident',
  }) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to save your state return.');
    }
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/states',
      data: {
        'state_code': stateCode.trim().toUpperCase(),
        'residency_type': residencyType,
      },
    );
    final code = res.statusCode ?? 500;
    if (code >= 400 || res.data == null) {
      throw StateError(_stateSaveFailureMessage(code));
    }
    final data = res.data!['data'];
    if (data is! Map) {
      throw StateError(
        'We’re unable to save your state return right now. Please try again.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static String _stateSaveFailureMessage(int statusCode) {
    switch (statusCode) {
      case 401:
        return 'Please sign in again to save your state return.';
      case 403:
        return 'This action is not authorized.';
      case 404:
        return 'No tax-year workspace. Select a year and try again.';
      case 422:
        return 'Some information could not be validated. Please check your entries and try again.';
      case 429:
        return 'Too many requests — wait a moment and try again.';
      default:
        return 'We’re unable to save your state return right now. Please try again.';
    }
  }

  int _localCurrentFilingYear() => DateTime.now().year - 1;

  ({List<TaxYearInfo> years, int current, String source}) _localCatalog() {
    final current = _localCurrentFilingYear();
    final years = <TaxYearInfo>[
      for (var y = current; y >= current - 9; y--)
        TaxYearInfo(
          taxYear: y,
          label: y == current ? '$y — Current Filing Season' : '$y',
          isCurrentFilingYear: y == current,
        ),
    ];
    return (years: years, current: current, source: 'local-fallback');
  }
}

final taxYearRepositoryProvider = Provider<TaxYearRepository>((ref) {
  return TaxYearRepository(ref.watch(laravelApiClientProvider));
});

/// Result of `POST .../tax-years/activate` including embedded payloads.
class WorkspaceActivation {
  const WorkspaceActivation({
    required this.workspace,
    this.tasks = const [],
    this.organizer,
    this.tasksEmbedded = false,
  });

  final TaxYearWorkspace workspace;
  final List<Map<String, dynamic>> tasks;
  final Map<String, dynamic>? organizer;

  /// True when the activate JSON included a `tasks` key (even if empty).
  final bool tasksEmbedded;
}

/// Scope keys that must match the active workspace before reusing [organizerSnapshot].
class OrganizerSnapshotScope {
  const OrganizerSnapshotScope({this.workspaceId, this.entityId, this.taxYear});

  final String? workspaceId;
  final String? entityId;
  final int? taxYear;

  bool matches(TaxYearWorkspace? workspace) {
    if (workspace == null) return false;
    if ((workspaceId ?? '').isNotEmpty &&
        workspaceId != workspace.workspaceId) {
      return false;
    }
    if ((entityId ?? '').isNotEmpty &&
        (workspace.entityId ?? '').isNotEmpty &&
        entityId != workspace.entityId) {
      return false;
    }
    if (taxYear != null && taxYear != workspace.taxYear) return false;
    return true;
  }
}

/// Default soft-cache TTL for the tax-year catalog (also invalidated on season rollover).
const Duration kTaxYearCatalogTtl = Duration(hours: 12);

/// Whether [state] may skip `GET /tax-years` on a normal remount.
bool isTaxYearCatalogWarm(
  TaxYearState state, {
  DateTime? now,
  Duration ttl = kTaxYearCatalogTtl,
}) {
  final clock = now ?? DateTime.now();
  final expectedLocalFilingYear = clock.year - 1;
  final catalogMatchesCurrentSeason =
      state.currentFilingYear == expectedLocalFilingYear;
  final loadedAt = state.catalogLoadedAt;
  final withinTtl = loadedAt != null && clock.difference(loadedAt) < ttl;
  return state.years.isNotEmpty &&
      state.currentFilingYear != null &&
      catalogMatchesCurrentSeason &&
      withinTtl;
}

class TaxYearState {
  const TaxYearState({
    this.years = const [],
    this.selectedYear,
    this.currentFilingYear,
    this.catalogLoadedAt,
    this.workspace,
    this.tasks = const [],
    this.organizerSnapshot,
    this.organizerSnapshotScope,
    this.loading = false,
    this.source = 'unknown',
    this.error,
  });

  final List<TaxYearInfo> years;
  final int? selectedYear;
  final int? currentFilingYear;

  /// Wall-clock when [years] / [currentFilingYear] were last fetched.
  final DateTime? catalogLoadedAt;
  final TaxYearWorkspace? workspace;
  final List<Map<String, dynamic>> tasks;

  /// Organizer JSON from the last activate (same shape as GET .../organizer).
  final Map<String, dynamic>? organizerSnapshot;

  /// Taxpayer / return / year keys for [organizerSnapshot].
  final OrganizerSnapshotScope? organizerSnapshotScope;
  final bool loading;
  final String source;
  final String? error;

  /// Snapshot only when scope keys still match the active workspace.
  Map<String, dynamic>? get scopedOrganizerSnapshot {
    final snap = organizerSnapshot;
    final scope = organizerSnapshotScope;
    if (snap == null || scope == null) return null;
    if (!scope.matches(workspace)) return null;
    return snap;
  }

  TaxYearState copyWith({
    List<TaxYearInfo>? years,
    int? selectedYear,
    int? currentFilingYear,
    DateTime? catalogLoadedAt,
    TaxYearWorkspace? workspace,
    List<Map<String, dynamic>>? tasks,
    Map<String, dynamic>? organizerSnapshot,
    OrganizerSnapshotScope? organizerSnapshotScope,
    bool? loading,
    String? source,
    String? error,
    bool clearWorkspace = false,
    bool clearOrganizerSnapshot = false,
    bool clearCatalogLoadedAt = false,
  }) {
    final dropSnapshot = clearOrganizerSnapshot || clearWorkspace;
    return TaxYearState(
      years: years ?? this.years,
      selectedYear: selectedYear ?? this.selectedYear,
      currentFilingYear: currentFilingYear ?? this.currentFilingYear,
      catalogLoadedAt: clearCatalogLoadedAt
          ? null
          : (catalogLoadedAt ?? this.catalogLoadedAt),
      workspace: clearWorkspace ? null : (workspace ?? this.workspace),
      tasks: tasks ?? this.tasks,
      organizerSnapshot: dropSnapshot
          ? null
          : (organizerSnapshot ?? this.organizerSnapshot),
      organizerSnapshotScope: dropSnapshot
          ? null
          : (organizerSnapshotScope ?? this.organizerSnapshotScope),
      loading: loading ?? this.loading,
      source: source ?? this.source,
      error: error,
    );
  }
}

class DashboardCachedSnapshot {
  const DashboardCachedSnapshot({
    required this.cachedAt,
    this.years = const [],
    this.selectedYear,
    this.currentFilingYear,
    this.catalogLoadedAt,
    this.workspace,
    this.tasks = const [],
    this.source = 'cache',
  });

  final DateTime cachedAt;
  final List<TaxYearInfo> years;
  final int? selectedYear;
  final int? currentFilingYear;
  final DateTime? catalogLoadedAt;
  final TaxYearWorkspace? workspace;
  final List<Map<String, dynamic>> tasks;
  final String source;

  factory DashboardCachedSnapshot.fromState(TaxYearState state) {
    return DashboardCachedSnapshot(
      cachedAt: DateTime.now(),
      years: state.years,
      selectedYear: state.selectedYear,
      currentFilingYear: state.currentFilingYear,
      catalogLoadedAt: state.catalogLoadedAt,
      workspace: state.workspace,
      tasks: state.tasks,
      source: state.source,
    );
  }

  factory DashboardCachedSnapshot.fromJson(Map<String, dynamic> json) {
    final years = (json['years'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => TaxYearInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final tasks = (json['tasks'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final workspaceRaw = json['workspace'];
    return DashboardCachedSnapshot(
      cachedAt:
          _dateFrom(json['cached_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      years: years,
      selectedYear: _intFrom(json['selected_year']),
      currentFilingYear: _intFrom(json['current_filing_year']),
      catalogLoadedAt: _dateFrom(json['catalog_loaded_at']),
      workspace: workspaceRaw is Map
          ? TaxYearWorkspace.fromJson(Map<String, dynamic>.from(workspaceRaw))
          : null,
      tasks: tasks,
      source: (json['source'] ?? 'cache').toString(),
    );
  }

  bool get hasDashboardData => years.isNotEmpty || workspace != null;

  TaxYearState toTaxYearState() {
    return TaxYearState(
      years: years,
      selectedYear: selectedYear ?? workspace?.taxYear ?? currentFilingYear,
      currentFilingYear: currentFilingYear,
      catalogLoadedAt: catalogLoadedAt,
      workspace: workspace,
      tasks: tasks,
      loading: false,
      source: source == 'unknown' ? 'cache' : source,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'cached_at': cachedAt.toIso8601String(),
    'years': years.map((y) => y.toJson()).toList(),
    if (selectedYear != null) 'selected_year': selectedYear,
    if (currentFilingYear != null) 'current_filing_year': currentFilingYear,
    if (catalogLoadedAt != null)
      'catalog_loaded_at': catalogLoadedAt!.toIso8601String(),
    if (workspace != null) 'workspace': workspace!.toJson(),
    'tasks': tasks,
    'source': source,
  };

  static int? _intFrom(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  static DateTime? _dateFrom(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class TaxYearNotifier extends Notifier<TaxYearState> {
  @override
  TaxYearState build() => const TaxYearState(loading: true);

  TaxYearRepository get _repo => ref.read(taxYearRepositoryProvider);

  Future<void>? _bootstrapInFlight;
  bool _bootstrapForceCatalog = false;

  /// True while a forceCatalog follow-up is already chained after the current
  /// soft in-flight bootstrap. Concurrent force callers share that follow-up.
  bool _bootstrapForceQueued = false;

  /// Bumped for every workspace refresh that may await I/O. Stale completions
  /// with an older epoch must not overwrite a newer year/entity/workspace.
  int _workspaceRefreshEpoch = 0;

  /// Soft bootstrap: keep painted Home content when catalog/workspace already warm.
  /// Coalesces concurrent callers (Home remount + pull-to-refresh).
  ///
  /// Stores the body [Future] itself (not a `whenComplete` wrapper) and clears
  /// that exact instance on both success and failure so a later bootstrap can run.
  /// A soft in-flight run does not satisfy a later [forceCatalog] caller — that
  /// caller is chained to run after the soft Future settles (success or failure).
  Future<void> bootstrap({bool forceCatalog = false}) {
    final existing = _bootstrapInFlight;
    if (existing != null) {
      if (!forceCatalog || _bootstrapForceCatalog) {
        return existing;
      }
      // Soft failures are normally absorbed inside [_bootstrapBody]; still use
      // catchError so an unexpected rejection cannot block a forced refresh.
      // Concurrent force callers while soft is in-flight share one follow-up.
      if (_bootstrapForceQueued) {
        return existing
            .catchError((Object _) {})
            .then((_) => bootstrap(forceCatalog: true));
      }
      _bootstrapForceQueued = true;
      return existing.catchError((Object _) {}).then((_) {
        _bootstrapForceQueued = false;
        return bootstrap(forceCatalog: true);
      });
    }

    _bootstrapForceQueued = false;
    _bootstrapForceCatalog = forceCatalog;
    final pending = _bootstrapBody(forceCatalog: forceCatalog);
    _bootstrapInFlight = pending;
    pending.whenComplete(() {
      if (identical(_bootstrapInFlight, pending)) {
        _bootstrapInFlight = null;
        _bootstrapForceCatalog = false;
      }
    });
    return pending;
  }

  /// True while a [bootstrap] Future is coalesced — for tests.
  @visibleForTesting
  bool get debugBootstrapInFlight => _bootstrapInFlight != null;

  /// The exact in-flight [Future] currently stored — for tests.
  @visibleForTesting
  Future<void>? get debugBootstrapInFlightFuture => _bootstrapInFlight;

  /// Current workspace-refresh epoch — for tests.
  @visibleForTesting
  int get debugWorkspaceRefreshEpoch => _workspaceRefreshEpoch;

  Future<void> hydrateDashboardCache() async {
    if (state.workspace != null || state.years.isNotEmpty) return;
    final accountKey = ref.read(activeSyncAccountKeyProvider);
    if (accountKey == null || accountKey.isEmpty) return;
    try {
      final raw = await ref
          .read(syncCursorStoreProvider)
          .readDashboardSnapshot(accountKey);
      if (raw == null) return;
      final snapshot = DashboardCachedSnapshot.fromJson(raw);
      if (!snapshot.hasDashboardData) return;
      state = snapshot.toTaxYearState();
    } catch (_) {
      // Cache read/decode failures should never block live dashboard refresh.
    }
  }

  void _persistDashboardCache() {
    final accountKey = ref.read(activeSyncAccountKeyProvider);
    if (accountKey == null || accountKey.isEmpty) return;
    final snapshot = DashboardCachedSnapshot.fromState(state);
    if (!snapshot.hasDashboardData) return;
    unawaited(
      ref
          .read(syncCursorStoreProvider)
          .writeDashboardSnapshot(accountKey, snapshot.toJson())
          .catchError((_) {}),
    );
  }

  Future<bool> _tryMobileDashboardBootstrap({
    required bool forceCatalog,
    required bool hasWarmCatalog,
  }) async {
    if (!AppConfig.usesLaravelAuth) return false;
    final needsCatalog = forceCatalog || !hasWarmCatalog;
    ({List<TaxYearInfo> years, int current, String source})? catalog;
    MobileDashboardBootstrap? bootstrap;
    Object? catalogError;
    Object? bootstrapError;

    if (needsCatalog) {
      final catalogFuture = _repo.listTaxYears();
      final bootstrapFuture = _repo.mobileBootstrap(
        taxYear: state.selectedYear,
      );
      await Future.wait<void>([
        catalogFuture
            .then<void>((value) {
              catalog = value;
            })
            .catchError((Object error) {
              catalogError = error;
            }),
        bootstrapFuture
            .then<void>((value) {
              bootstrap = value;
            })
            .catchError((Object error) {
              bootstrapError = error;
            }),
      ]);
    } else {
      try {
        bootstrap = await _repo.mobileBootstrap(taxYear: state.selectedYear);
      } catch (e) {
        bootstrapError = e;
      }
    }

    if (bootstrapError != null) throw bootstrapError!;
    final payload = bootstrap;
    if (payload == null) {
      if (catalog != null) {
        final selected = state.selectedYear ?? catalog!.current;
        state = state.copyWith(
          years: catalog!.years,
          currentFilingYear: catalog!.current,
          catalogLoadedAt: DateTime.now(),
          selectedYear: selected,
          source: catalog!.source,
          loading: false,
        );
      } else if (catalogError != null) {
        throw catalogError!;
      }
      return false;
    }

    final years = payload.years.isNotEmpty
        ? payload.years
        : (catalog?.years.isNotEmpty == true ? catalog!.years : state.years);
    final current =
        payload.currentFilingYear ??
        catalog?.current ??
        state.currentFilingYear ??
        (years.isNotEmpty ? years.first.taxYear : null);
    final selected =
        payload.selectedYear ??
        state.selectedYear ??
        payload.workspace?.taxYear ??
        current;
    final loadedAt =
        years.isNotEmpty && (needsCatalog || state.catalogLoadedAt == null)
        ? DateTime.now()
        : state.catalogLoadedAt;
    state = state.copyWith(
      years: years,
      currentFilingYear: current,
      catalogLoadedAt: loadedAt,
      selectedYear: selected,
      workspace: payload.workspace ?? state.workspace,
      tasks: payload.tasks,
      loading: false,
      source: payload.catalogSource ?? catalog?.source ?? 'laravel',
      error: null,
    );
    _persistDashboardCache();
    return true;
  }

  Future<void> _bootstrapBody({required bool forceCatalog}) async {
    final hasWarmCatalog = isTaxYearCatalogWarm(state);
    // Only flash full-screen loading when we have nothing to show yet.
    if (!hasWarmCatalog) {
      state = state.copyWith(loading: true, error: null);
    } else {
      state = state.copyWith(error: null);
    }
    try {
      if (AppConfig.usesLaravelAuth) {
        final bootstrapped = await _tryMobileDashboardBootstrap(
          forceCatalog: forceCatalog,
          hasWarmCatalog: hasWarmCatalog,
        );
        if (bootstrapped) return;
      }
      final needsCatalog =
          (forceCatalog || !hasWarmCatalog) &&
          !(AppConfig.usesLaravelAuth && isTaxYearCatalogWarm(state));
      if (needsCatalog) {
        final catalog = await _repo.listTaxYears();
        final selected = state.selectedYear ?? catalog.current;
        state = state.copyWith(
          years: catalog.years,
          currentFilingYear: catalog.current,
          catalogLoadedAt: DateTime.now(),
          selectedYear: selected,
          source: catalog.source,
          loading: false,
        );
      } else if (state.loading) {
        state = state.copyWith(loading: false);
      }
      await refreshWorkspace();
      _persistDashboardCache();
    } catch (e) {
      state = state.copyWith(loading: false, error: ApiErrorMapper.map(e));
    }
  }

  Future<void> selectYear(int year) async {
    // Invalidate any in-flight activate for the previous selection first.
    _workspaceRefreshEpoch++;
    state = state.copyWith(selectedYear: year, clearWorkspace: true);
    await refreshWorkspace();
  }

  /// Drop cached activate-embedded organizer (e.g. after a successful save).
  void clearOrganizerSnapshot() {
    if (state.organizerSnapshot == null) return;
    state = state.copyWith(clearOrganizerSnapshot: true);
  }

  /// After silent autosave, merge saved section answers into the warm snapshot
  /// so a scoped reopen does not hydrate pre-edit activate JSON.
  ///
  /// [sectionAnswers] maps `section_key` → flat answer map (same shape as
  /// Laravel section `answers`). Scope must still match the active workspace.
  void mergeOrganizerSnapshotSectionAnswers(
    Map<String, Map<String, dynamic>> sectionAnswers, {
    String? prepType,
  }) {
    if (sectionAnswers.isEmpty) return;
    final snap = state.organizerSnapshot;
    final scope = state.organizerSnapshotScope;
    if (snap == null || scope == null || !scope.matches(state.workspace)) {
      return;
    }

    final next = Map<String, dynamic>.from(snap);
    final sections = Map<String, dynamic>.from(
      (next['sections'] as Map?) ?? const <String, dynamic>{},
    );
    final answersRoot = Map<String, dynamic>.from(
      (sections['answers'] as Map?) ?? const <String, dynamic>{},
    );
    for (final entry in sectionAnswers.entries) {
      answersRoot[entry.key] = {
        'answers': Map<String, dynamic>.from(entry.value),
      };
    }
    sections['answers'] = answersRoot;
    next['sections'] = sections;
    if (prepType != null && prepType.isNotEmpty) {
      next['prep_type'] = prepType;
    }
    state = state.copyWith(organizerSnapshot: next);
  }

  /// Whether this refresh epoch may still commit workspace/snapshot state.
  bool _canCommitWorkspaceRefresh({
    required int epoch,
    required int requestedYear,
    String? requestedEntityId,
  }) {
    if (epoch != _workspaceRefreshEpoch) return false;
    final selected = state.selectedYear ?? state.currentFilingYear;
    if (selected != requestedYear) return false;
    if (requestedEntityId != null &&
        requestedEntityId.isNotEmpty &&
        (state.workspace?.entityId ?? '').isNotEmpty &&
        state.workspace!.entityId != requestedEntityId) {
      // Selection moved to another taxpayer/entity while this call was awaiting.
      return false;
    }
    return true;
  }

  Future<void> refreshWorkspace({bool force = false}) async {
    // Organizer / Documents may open before the year selector is touched —
    // fall back to the catalog current year instead of no-op'ing.
    final year = state.selectedYear ?? state.currentFilingYear;
    if (year == null) return;
    if (state.selectedYear == null) {
      state = state.copyWith(selectedYear: year);
    }

    // Prefer Laravel `/api/v1` workspace when Sanctum is configured + token present.
    if (AppConfig.usesLaravelAuth) {
      // Warm cache: skip activate/tasks round-trip when already on this year.
      final existing = state.workspace;
      if (!force &&
          existing != null &&
          existing.taxYear == year &&
          (existing.workspaceId ?? '').isNotEmpty &&
          state.source == 'laravel') {
        return;
      }
      final epoch = ++_workspaceRefreshEpoch;
      final requestedYear = year;
      try {
        final entities = ref.read(entitiesRepositoryProvider);
        final entity = await entities.ensurePrimaryEntity();
        final entityId = entity?['id']?.toString();
        if (entityId == null || entityId.isEmpty) {
          throw StateError(
            'We’re unable to open your tax organizer right now. Please try again.',
          );
        }
        if (!_canCommitWorkspaceRefresh(
          epoch: epoch,
          requestedYear: requestedYear,
          requestedEntityId: entityId,
        )) {
          return;
        }
        final packed = await _repo.activateWorkspacePacked(
          entityId: entityId,
          taxYear: requestedYear,
        );
        // Activate already embeds tasks — avoid a second ~4s GET when present.
        final tasks = packed.tasksEmbedded
            ? packed.tasks
            : (packed.workspace.workspaceId == null
                  ? const <Map<String, dynamic>>[]
                  : await _repo.listTasks(packed.workspace.workspaceId!));
        if (!_canCommitWorkspaceRefresh(
          epoch: epoch,
          requestedYear: requestedYear,
          requestedEntityId: entityId,
        )) {
          return;
        }
        // Packed payload must still describe the year/entity we asked for.
        if (packed.workspace.taxYear != requestedYear) return;
        final packedEntity = packed.workspace.entityId ?? entityId;
        if (packedEntity != entityId) return;

        state = state.copyWith(
          workspace: packed.workspace,
          tasks: tasks,
          organizerSnapshot: packed.organizer,
          organizerSnapshotScope: OrganizerSnapshotScope(
            workspaceId: packed.workspace.workspaceId,
            entityId: packedEntity,
            taxYear: packed.workspace.taxYear,
          ),
          source: 'laravel',
          error: null,
        );
        _persistDashboardCache();
        return;
      } catch (e) {
        if (!_canCommitWorkspaceRefresh(
          epoch: epoch,
          requestedYear: requestedYear,
        )) {
          return;
        }
        // Never fall through to cookie-portal on Sanctum builds — portal rows
        // lack a Laravel workspace UUID and Tax Organizer will hard-fail.
        state = state.copyWith(
          clearWorkspace: true,
          tasks: const [],
          error: ApiErrorMapper.map(e),
        );
        return;
      }
    }

    // Cookie-portal fallback: derive progress from tax_returns for the selected year.
    final epoch = ++_workspaceRefreshEpoch;
    final requestedYear = year;
    try {
      final portal = ref.read(portalRepositoryProvider);
      String? lastName;
      try {
        lastName =
            (await ref.read(authRepositoryProvider).currentUser())?.lastName;
      } catch (_) {}
      final row = await portal.getOrCreateReturnForYear(
        requestedYear,
        lastName: lastName,
      );
      var docsCount = 0;
      try {
        if (row['id'] != null) {
          docsCount = (await portal.listDocuments(row['id'])).length;
        }
      } catch (_) {}
      if (!_canCommitWorkspaceRefresh(
        epoch: epoch,
        requestedYear: requestedYear,
      )) {
        return;
      }
      final rowYear = (row['year'] as num?)?.toInt();
      if (rowYear != null && rowYear != requestedYear) return;

      state = state.copyWith(
        workspace: TaxYearWorkspace.fromPortalReturn(
          row,
          documentsCount: docsCount,
        ),
        tasks: const [],
        source: state.source == 'laravel' ? state.source : 'portal-returns',
        error: null,
      );
      _persistDashboardCache();
    } catch (e) {
      if (!_canCommitWorkspaceRefresh(
        epoch: epoch,
        requestedYear: requestedYear,
      )) {
        return;
      }
      state = state.copyWith(error: ApiErrorMapper.map(e));
    }
  }
}

final taxYearProvider = NotifierProvider<TaxYearNotifier, TaxYearState>(
  TaxYearNotifier.new,
);
