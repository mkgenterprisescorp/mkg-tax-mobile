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
  Future<TaxYearWorkspace?> activateWorkspace({
    required String entityId,
    required int taxYear,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/entities/$entityId/tax-years/activate',
      data: {'tax_year': taxYear},
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return TaxYearWorkspace.fromJson(Map<String, dynamic>.from(data));
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

  Future<Map<String, dynamic>?> addState(
    String workspaceId,
    String stateCode, {
    String residencyType = 'resident',
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/states',
      data: {'state_code': stateCode, 'residency_type': residencyType},
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
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

class TaxYearState {
  const TaxYearState({
    this.years = const [],
    this.selectedYear,
    this.currentFilingYear,
    this.workspace,
    this.tasks = const [],
    this.loading = false,
    this.source = 'unknown',
    this.error,
  });

  final List<TaxYearInfo> years;
  final int? selectedYear;
  final int? currentFilingYear;
  final TaxYearWorkspace? workspace;
  final List<Map<String, dynamic>> tasks;
  final bool loading;
  final String source;
  final String? error;

  TaxYearState copyWith({
    List<TaxYearInfo>? years,
    int? selectedYear,
    int? currentFilingYear,
    TaxYearWorkspace? workspace,
    List<Map<String, dynamic>>? tasks,
    bool? loading,
    String? source,
    String? error,
    bool clearWorkspace = false,
  }) {
    return TaxYearState(
      years: years ?? this.years,
      selectedYear: selectedYear ?? this.selectedYear,
      currentFilingYear: currentFilingYear ?? this.currentFilingYear,
      workspace: clearWorkspace ? null : (workspace ?? this.workspace),
      tasks: tasks ?? this.tasks,
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

  Future<void> bootstrap() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final catalog = await _repo.listTaxYears();
      final selected = state.selectedYear ?? catalog.current;
      state = state.copyWith(
        years: catalog.years,
        currentFilingYear: catalog.current,
        selectedYear: selected,
        source: catalog.source,
        loading: false,
      );
      await refreshWorkspace();
    } catch (e) {
      state = state.copyWith(loading: false, error: ApiErrorMapper.map(e));
    }
  }

  Future<void> selectYear(int year) async {
    state = state.copyWith(selectedYear: year, clearWorkspace: true);
    await refreshWorkspace();
  }

  Future<void> refreshWorkspace({bool force = false}) async {
    final year = state.selectedYear;
    if (year == null) return;

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
        if (entityId != null) {
          final workspace = await _repo.activateWorkspace(entityId: entityId, taxYear: year);
          if (workspace != null) {
            final wid = workspace.workspaceId;
            final tasks = wid == null ? const <Map<String, dynamic>>[] : await _repo.listTasks(wid);
            state = state.copyWith(
              workspace: workspace,
              tasks: tasks,
              source: 'laravel',
            );
            return;
          }
        }
      } catch (e) {
        state = state.copyWith(error: ApiErrorMapper.map(e));
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
      );
    } catch (e) {
      state = state.copyWith(error: ApiErrorMapper.map(e));
    }
  }
}

final taxYearProvider = NotifierProvider<TaxYearNotifier, TaxYearState>(TaxYearNotifier.new);
