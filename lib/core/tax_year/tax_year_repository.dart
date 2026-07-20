import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/entities/data/entities_repository.dart';
import '../api/portal_repository.dart';
import '../config/app_config.dart';
import '../network/api_error_mapper.dart';
import '../network/laravel_api_client.dart';
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
    final states = (json['state_workspaces'] as List?) ?? (json['state_returns'] as List?);
    final docs = json['documents'];
    final docsCount = (json['documents_count'] as num?)?.toInt() ??
        (docs is List ? docs.length : 0);
    return TaxYearWorkspace(
      taxYear: (json['tax_year'] as num?)?.toInt() ?? 0,
      federalReturnStatus: _humanizeStatus(json['federal_return_status'] ?? 'Not Started'),
      organizerStatus: _humanizeStatus(json['organizer_status'] ?? 'Not Started'),
      organizerCompletionPercentage: (json['organizer_completion_percentage'] as num?)?.toInt() ?? 0,
      estimatedRefund: json['estimated_refund'] as num?,
      estimatedBalanceDue: json['estimated_balance_due'] as num?,
      stateReturns: states
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
  if (status == 'processing' || status == 'filed' || status == 'accepted' || status == 'completed') {
    return 100;
  }
  var score = 0;
  var total = 8;
  if ('${data['prepType'] ?? ''}'.isNotEmpty) score++;
  if ('${data['firstName'] ?? ''}'.trim().isNotEmpty && '${data['lastName'] ?? ''}'.trim().isNotEmpty) score++;
  final wages = data['wages'];
  final hasIncome = (wages is num && wages > 0) ||
      ((data['w2Forms'] as List?)?.isNotEmpty ?? false) ||
      ((data['scheduleE'] is Map) &&
          ((data['scheduleE']['rentalProperties'] as List?)?.isNotEmpty ?? false));
  if (hasIncome) score++;
  if (data['itemizeDeductions'] == true || (data['scheduleA'] is Map)) score++;
  final sc = data['scheduleC'];
  if (sc is Map && '${sc['businessName'] ?? ''}'.trim().isNotEmpty) score++;
  if (data['ca540'] is Map) score++;
  if ('${data['routingNumber'] ?? ''}'.trim().isNotEmpty) score++;
  if (data['consentPerjury'] == true || data['consentToEFile'] == true) score++;
  // Entity prep
  for (final k in ['form1120', 'form1120S', 'form1065', 'form990EZ', 'form990', 'form1041']) {
    final m = data[k];
    if (m is Map && m.values.any((v) => v != null && '$v'.trim().isNotEmpty && v != 0)) {
      score = (score + 2).clamp(0, total);
      break;
    }
  }
  return ((score / total) * 100).round().clamp(0, 100);
}

class TaxYearRepository {
  TaxYearRepository(this._api);
  final LaravelApiClient _api;

  /// Server-authoritative 10-year list (`GET /api/v1/tax-years`).
  /// Falls back to local computation if Laravel is unreachable.
  Future<({List<TaxYearInfo> years, int current, String source})> listTaxYears() async {
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
        final current = (meta?['current_filing_tax_year'] as num?)?.toInt() ??
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
    final packed = await activateWorkspacePacked(entityId: entityId, taxYear: taxYear);
    return packed.workspace;
  }

  /// Activate and return the embedded organizer/tasks snapshot in one round-trip.
  Future<WorkspaceActivation> activateWorkspacePacked({
    required String entityId,
    required int taxYear,
  }) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to open your tax organizer.');
    }
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/entities/$entityId/tax-years/activate',
      data: {'tax_year': taxYear},
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
    final res = await _api.get<Map<String, dynamic>>('/api/v1/tax-year-workspaces/$workspaceId');
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
      throw StateError('We’re unable to save your state return right now. Please try again.');
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
  const OrganizerSnapshotScope({
    this.workspaceId,
    this.entityId,
    this.taxYear,
  });

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
  final withinTtl =
      loadedAt != null && clock.difference(loadedAt) < ttl;
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

class TaxYearNotifier extends Notifier<TaxYearState> {
  @override
  TaxYearState build() => const TaxYearState(loading: true);

  TaxYearRepository get _repo => ref.read(taxYearRepositoryProvider);

  Future<void>? _bootstrapInFlight;

  /// Soft bootstrap: keep painted Home content when catalog/workspace already warm.
  /// Coalesces concurrent callers (Home remount + pull-to-refresh).
  ///
  /// Stores the body [Future] itself (not a `whenComplete` wrapper) and clears
  /// that exact instance on both success and failure so a later bootstrap can run.
  Future<void> bootstrap({bool forceCatalog = false}) {
    final existing = _bootstrapInFlight;
    if (existing != null) return existing;

    final pending = _bootstrapBody(forceCatalog: forceCatalog);
    _bootstrapInFlight = pending;
    pending.whenComplete(() {
      if (identical(_bootstrapInFlight, pending)) {
        _bootstrapInFlight = null;
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

  Future<void> _bootstrapBody({required bool forceCatalog}) async {
    final hasWarmCatalog = isTaxYearCatalogWarm(state);
    // Only flash full-screen loading when we have nothing to show yet.
    if (!hasWarmCatalog) {
      state = state.copyWith(loading: true, error: null);
    } else {
      state = state.copyWith(error: null);
    }
    try {
      if (forceCatalog || !hasWarmCatalog) {
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
    } catch (e) {
      state = state.copyWith(loading: false, error: ApiErrorMapper.map(e));
    }
  }

  Future<void> selectYear(int year) async {
    state = state.copyWith(selectedYear: year, clearWorkspace: true);
    await refreshWorkspace();
  }

  /// Drop cached activate-embedded organizer (e.g. after a successful save).
  void clearOrganizerSnapshot() {
    if (state.organizerSnapshot == null) return;
    state = state.copyWith(clearOrganizerSnapshot: true);
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
      try {
        final entities = ref.read(entitiesRepositoryProvider);
        final entity = await entities.ensurePrimaryEntity();
        final entityId = entity?['id']?.toString();
        if (entityId == null || entityId.isEmpty) {
          throw StateError('We’re unable to open your tax organizer right now. Please try again.');
        }
        final packed = await _repo.activateWorkspacePacked(
          entityId: entityId,
          taxYear: year,
        );
        // Activate already embeds tasks — avoid a second ~4s GET when present.
        final tasks = packed.tasksEmbedded
            ? packed.tasks
            : (packed.workspace.workspaceId == null
                ? const <Map<String, dynamic>>[]
                : await _repo.listTasks(packed.workspace.workspaceId!));
        state = state.copyWith(
          workspace: packed.workspace,
          tasks: tasks,
          organizerSnapshot: packed.organizer,
          organizerSnapshotScope: OrganizerSnapshotScope(
            workspaceId: packed.workspace.workspaceId,
            entityId: packed.workspace.entityId ?? entityId,
            taxYear: packed.workspace.taxYear,
          ),
          source: 'laravel',
          error: null,
        );
        return;
      } catch (e) {
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
    try {
      final portal = ref.read(portalRepositoryProvider);
      String? lastName;
      try {
        lastName = (await ref.read(authRepositoryProvider).currentUser())?.lastName;
      } catch (_) {}
      final row = await portal.getOrCreateReturnForYear(year, lastName: lastName);
      var docsCount = 0;
      try {
        if (row['id'] != null) {
          docsCount = (await portal.listDocuments(row['id'])).length;
        }
      } catch (_) {}
      state = state.copyWith(
        workspace: TaxYearWorkspace.fromPortalReturn(row, documentsCount: docsCount),
        tasks: const [],
        source: state.source == 'laravel' ? state.source : 'portal-returns',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: ApiErrorMapper.map(e));
    }
  }
}

final taxYearProvider = NotifierProvider<TaxYearNotifier, TaxYearState>(TaxYearNotifier.new);
