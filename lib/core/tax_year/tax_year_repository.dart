import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/laravel_api_client.dart';

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
  });

  final int taxYear;
  final String federalReturnStatus;
  final String organizerStatus;
  final int organizerCompletionPercentage;
  final num? estimatedRefund;
  final num? estimatedBalanceDue;
  final List<Map<String, dynamic>> stateReturns;
  final int documentsCount;

  factory TaxYearWorkspace.fromJson(Map<String, dynamic> json) {
    return TaxYearWorkspace(
      taxYear: (json['tax_year'] as num?)?.toInt() ?? 0,
      federalReturnStatus: (json['federal_return_status'] ?? 'Not Started').toString(),
      organizerStatus: (json['organizer_status'] ?? 'Not Started').toString(),
      organizerCompletionPercentage: (json['organizer_completion_percentage'] as num?)?.toInt() ?? 0,
      estimatedRefund: json['estimated_refund'] as num?,
      estimatedBalanceDue: json['estimated_balance_due'] as num?,
      stateReturns: (json['state_returns'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [],
      documentsCount: (json['documents_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class TaxYearRepository {
  TaxYearRepository(this._api);
  final LaravelApiClient _api;

  /// Server-authoritative 10-year list. Falls back to local computation if Laravel is unreachable.
  Future<({List<TaxYearInfo> years, int current, String source})> listTaxYears() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/mobile/tax-years');
      if ((res.statusCode ?? 500) < 400 && res.data != null) {
        final data = (res.data!['data'] as List?)
                ?.whereType<Map>()
                .map((e) => TaxYearInfo.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const <TaxYearInfo>[];
        final current = (res.data!['meta']?['current_filing_tax_year'] as num?)?.toInt() ??
            (data.isNotEmpty ? data.first.taxYear : _localCurrentFilingYear());
        return (years: data, current: current, source: 'laravel');
      }
    } catch (_) {
      // fall through
    }
    return _localCatalog();
  }

  Future<TaxYearWorkspace?> activateWorkspace(int taxYear) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>('/api/mobile/tax-years/$taxYear/activate');
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return TaxYearWorkspace.fromJson(Map<String, dynamic>.from(data));
  }

  Future<TaxYearWorkspace?> getWorkspace(int taxYear) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/mobile/tax-years/$taxYear/return');
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return TaxYearWorkspace.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>?> getOrganizer(int taxYear) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>('/api/mobile/tax-years/$taxYear/organizer');
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> listDocuments(int taxYear) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/mobile/tax-years/$taxYear/documents');
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return const [];
    return (res.data!['data'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  Future<List<Map<String, dynamic>>> listTasks(int taxYear) async {
    if (_api.bearerToken == null) return const [];
    final res = await _api.get<Map<String, dynamic>>('/api/mobile/tax-years/$taxYear/tasks');
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return const [];
    return (res.data!['data'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const [];
  }

  Future<Map<String, dynamic>?> addState(int taxYear, String stateCode, {String residencyType = 'resident'}) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/mobile/tax-years/$taxYear/states',
      data: {'state_code': stateCode, 'residency_type': residencyType},
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> registerDocument({
    required int taxYear,
    required String category,
    required String filename,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/mobile/tax-years/$taxYear/documents',
      data: {
        'document_category': category,
        'original_filename': filename,
      },
    );
    if ((res.statusCode ?? 500) >= 400 || res.data == null) return null;
    final data = res.data!['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> priorYearFiling(int taxYear) async {
    if (_api.bearerToken == null) return;
    await _api.post('/api/mobile/tax-years/$taxYear/prior-year-filing', data: {
      'include_federal': true,
      'include_state': true,
      'return_type': 'original',
      'previously_filed': false,
    });
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
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> selectYear(int year) async {
    state = state.copyWith(selectedYear: year, clearWorkspace: true);
    await refreshWorkspace();
  }

  Future<void> refreshWorkspace() async {
    final year = state.selectedYear;
    if (year == null) return;
    final workspace = await _repo.getWorkspace(year) ?? await _repo.activateWorkspace(year);
    final tasks = await _repo.listTasks(year);
    state = state.copyWith(workspace: workspace, tasks: tasks);
  }
}

final taxYearProvider = NotifierProvider<TaxYearNotifier, TaxYearState>(TaxYearNotifier.new);
