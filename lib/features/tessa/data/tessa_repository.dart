import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';

class TessaMessageResult {
  const TessaMessageResult({
    required this.reply,
    this.source,
    this.nextActions = const [],
    this.formPlan = const {},
    this.diagnostics = const [],
  });

  final String reply;
  final String? source;
  final List<Map<String, dynamic>> nextActions;
  final Map<String, dynamic> formPlan;
  final List<Map<String, dynamic>> diagnostics;
}

class TessaActionResult {
  const TessaActionResult({
    required this.type,
    required this.ok,
    this.summary = '',
    this.payload = const {},
  });

  final String type;
  final bool ok;
  final String summary;
  final Map<String, dynamic> payload;
}

class TessaRepository {
  TessaRepository(this._api, this._portal);
  final LaravelApiClient _api;
  final PortalRepository _portal;

  Future<List<Map<String, dynamic>>> listConversations() async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/tessa/conversations');
      if (!PlatformApi.ok(res)) return const [];
      final map = PlatformApi.unwrapMap(res);
      final rows = map?['conversations'];
      if (rows is! List) return const [];
      return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return _portal.listConversations();
  }

  Future<Map<String, dynamic>> createConversation({String title = 'Mobile TaxPro Assist'}) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/tessa/conversations',
        data: {'title': title},
      );
      if (!PlatformApi.ok(res)) throw StateError('Create conversation failed');
      return PlatformApi.unwrapMap(res) ?? {};
    }
    return _portal.createConversation(title: title);
  }

  Future<Map<String, dynamic>?> getConversation(dynamic id) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.get<Map<String, dynamic>>('/api/v1/tessa/conversations/$id');
      if (!PlatformApi.ok(res)) return null;
      return PlatformApi.unwrapMap(res);
    }
    return _portal.getConversation(id);
  }

  /// Sends a chat message and returns reply + form-automation nextActions.
  Future<TessaMessageResult> sendMessage(
    dynamic id,
    String content, {
    String? prepType,
    List<String>? jurisdictions,
    String? homeState,
    Map<String, dynamic>? organizer,
    int? taxYear,
    String? workspaceId,
    String? preferredLanguage,
    String? locale,
  }) async {
    if (AppConfig.usesLaravelAuth && _api.bearerToken != null) {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/v1/tessa/conversations/$id/messages',
        data: {
          'content': content,
          if (prepType != null) 'prep_type': prepType,
          if (jurisdictions != null) 'jurisdictions': jurisdictions,
          if (homeState != null) 'home_state': homeState,
          if (organizer != null) 'organizer': organizer,
          if (taxYear != null) 'tax_year': taxYear,
          if (workspaceId != null) 'workspace_id': workspaceId,
          if (preferredLanguage != null) 'preferred_language': preferredLanguage,
          if (locale != null) 'locale': locale,
        },
      );
      if (!PlatformApi.ok(res)) throw StateError('TESSA send failed');
      final map = PlatformApi.unwrapMap(res) ?? {};
      return TessaMessageResult(
        reply: map['reply']?.toString() ?? '',
        source: map['source']?.toString(),
        nextActions: _asMapList(map['next_actions']),
        formPlan: map['form_plan'] is Map
            ? Map<String, dynamic>.from(map['form_plan'] as Map)
            : const {},
        diagnostics: _asMapList(map['diagnostics']),
      );
    }
    final reply = await _portal.sendAiMessage(id, content);
    return TessaMessageResult(reply: reply, source: 'portal');
  }

  /// Standalone form-analysis nextActions (no chat turn).
  Future<Map<String, dynamic>?> analyzeForms({
    String? prepType,
    List<String>? jurisdictions,
    String? homeState,
    Map<String, dynamic>? organizer,
    int taxYear = 2025,
    String? workspaceId,
  }) async {
    if (!AppConfig.usesLaravelAuth || _api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/tessa/assist/analyze',
      data: {
        'tax_year': taxYear,
        if (prepType != null) 'prep_type': prepType,
        if (jurisdictions != null) 'jurisdictions': jurisdictions,
        if (homeState != null) 'home_state': homeState,
        if (organizer != null) 'organizer': organizer,
        if (workspaceId != null) 'workspace_id': workspaceId,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Execute a propose-only nextAction against Laravel estimate/intake routes.
  Future<TessaActionResult> executeNextAction(
    Map<String, dynamic> action, {
    String? workspaceId,
    Map<String, dynamic>? organizer,
    String prepType = 'personal',
    List<String> jurisdictions = const ['CA'],
    int taxYear = 2025,
  }) async {
    if (!AppConfig.usesLaravelAuth || _api.bearerToken == null) {
      return TessaActionResult(
        type: '${action['type'] ?? 'action'}',
        ok: false,
        summary: 'Sign in required to run automation.',
      );
    }

    final type = '${action['type'] ?? ''}';
    try {
      switch (type) {
        case 'analyze_form_completeness':
          final analysis = await analyzeForms(
            prepType: prepType,
            jurisdictions: jurisdictions,
            organizer: organizer,
            taxYear: taxYear,
            workspaceId: workspaceId,
          );
          final forms = (analysis?['form_plan'] is Map)
              ? ((analysis!['form_plan'] as Map)['required_forms'] ?? [])
              : [];
          return TessaActionResult(
            type: type,
            ok: analysis != null,
            summary: analysis == null
                ? 'Form analysis failed.'
                : 'Form plan: ${forms is List ? forms.join(', ') : forms}. '
                    '${(analysis['next_actions'] as List?)?.length ?? 0} next actions.',
            payload: analysis ?? const {},
          );

        case 'run_federal_1040_preview':
          if (workspaceId == null || workspaceId.isEmpty) {
            return TessaActionResult(
              type: type,
              ok: false,
              summary: 'Open a tax-year workspace first for Form 1040 preview.',
            );
          }
          final res = await _api.get<Map<String, dynamic>>(
            '/api/v1/tax-year-workspaces/$workspaceId/organizer/form-1040-preview',
          );
          final map = PlatformApi.unwrapMap(res) ?? {};
          return TessaActionResult(
            type: type,
            ok: PlatformApi.ok(res),
            summary: PlatformApi.ok(res)
                ? 'Form 1040 intake preview ready (estimate/intake only — not certified).'
                : 'Form 1040 preview failed.',
            payload: map,
          );

        case 'run_federal_tax_estimate':
          // Prefer workspace Form 1040 preview (Laravel organizer math) when no
          // inline organizer map was supplied — avoids empty wages=0 estimates.
          final hasOrganizer = organizer != null && organizer.isNotEmpty;
          if (!hasOrganizer && workspaceId != null && workspaceId.isNotEmpty) {
            final previewRes = await _api.get<Map<String, dynamic>>(
              '/api/v1/tax-year-workspaces/$workspaceId/organizer/form-1040-preview',
            );
            if (PlatformApi.ok(previewRes)) {
              final preview = PlatformApi.unwrapMap(previewRes) ?? {};
              final estimate = preview['refund_estimate'] is Map
                  ? Map<String, dynamic>.from(preview['refund_estimate'] as Map)
                  : <String, dynamic>{};
              return TessaActionResult(
                type: type,
                ok: true,
                summary: 'Federal tax estimate returned (estimate-only).',
                payload: {
                  ...estimate,
                  if (preview['form'] != null) 'form': preview['form'],
                  'refund_estimate': estimate.isEmpty ? preview : estimate,
                },
              );
            }
          }
          final res = await _api.post<Map<String, dynamic>>(
            '/api/v1/tax-estimates',
            data: {
              'tax_year': taxYear,
              if (organizer != null) ...organizer,
              'wages': organizer?['wages'] ?? 0,
            },
          );
          final map = PlatformApi.unwrapMap(res) ?? {};
          return TessaActionResult(
            type: type,
            ok: PlatformApi.ok(res),
            summary: PlatformApi.ok(res)
                ? 'Federal tax estimate returned (estimate-only).'
                : 'Federal tax estimate failed.',
            payload: map,
          );

        case 'run_ca540_estimate':
          if (workspaceId != null && workspaceId.isNotEmpty) {
            final res = await _api.get<Map<String, dynamic>>(
              '/api/v1/tax-year-workspaces/$workspaceId/organizer/ca540-estimate',
            );
            final map = PlatformApi.unwrapMap(res) ?? {};
            if (PlatformApi.ok(res)) {
              return TessaActionResult(
                type: type,
                ok: true,
                summary: 'CA Form 540 estimate loaded from organizer (Laravel exclusive).',
                payload: map,
              );
            }
          }
          final res = await _api.post<Map<String, dynamic>>(
            '/api/v1/ca540/calculate',
            data: {
              'tax_year': taxYear,
              'ca540': organizer?['ca540'] ?? organizer ?? {},
            },
          );
          final map = PlatformApi.unwrapMap(res) ?? {};
          return TessaActionResult(
            type: type,
            ok: PlatformApi.ok(res),
            summary: PlatformApi.ok(res)
                ? 'CA Form 540 estimate calculated (estimate-only).'
                : 'CA Form 540 estimate failed.',
            payload: map,
          );

        case 'run_ca_business_estimate':
          final forms = action['forms'];
          final first = forms is List && forms.isNotEmpty ? '${forms.first}' : '100';
          final formKey = _caBusinessFormKey(first);
          final res = await _api.post<Map<String, dynamic>>(
            '/api/v1/ca-business/calculate',
            data: {
              'form': formKey,
              'tax_year': taxYear,
              'data': organizer ?? {},
            },
          );
          final map = PlatformApi.unwrapMap(res) ?? {};
          return TessaActionResult(
            type: type,
            ok: PlatformApi.ok(res),
            summary: PlatformApi.ok(res)
                ? 'CA business $formKey estimate calculated (Laravel exclusive).'
                : 'CA business estimate failed for $formKey.',
            payload: map,
          );

        case 'run_state_workflow_intake':
          final code = '${action['jurisdiction'] ?? ''}'.toUpperCase();
          if (code.isEmpty || code == 'CA') {
            return TessaActionResult(
              type: type,
              ok: false,
              summary: 'CA stays on Laravel CA540 / ca-business routes.',
            );
          }
          final family = '${action['return_family'] ?? 'individual'}';
          final filing = '${action['filing_type'] ?? 'resident'}';
          final res = await _api.post<Map<String, dynamic>>(
            '/api/v1/states/$code/workflows/evaluate',
            data: {
              'return_family': family,
              'filing_type': filing,
              'answers': organizer ?? {},
            },
          );
          final map = PlatformApi.unwrapMap(res) ?? {};
          final pct = map['percentComplete'] ?? map['percent_complete'];
          final primary = map['primaryFormId'] ?? action['primary_form_id'];
          return TessaActionResult(
            type: type,
            ok: PlatformApi.ok(res),
            summary: PlatformApi.ok(res)
                ? '$code intake ${primary ?? ''} — $pct% complete (intake-only, no tax invented).'
                : '$code workflow evaluate failed.',
            payload: map,
          );

        default:
          return TessaActionResult(
            type: type.isEmpty ? 'action' : type,
            ok: false,
            summary: 'No executor for $type — ask Tessa in chat for guidance.',
          );
      }
    } catch (error) {
      return TessaActionResult(
        type: type.isEmpty ? 'action' : type,
        ok: false,
        summary: ApiErrorMapper.map(error),
      );
    }
  }

  String _caBusinessFormKey(String planId) {
    final u = planId.toUpperCase();
    if (u.contains('100S')) return '100S';
    if (u.contains('100')) return '100';
    if (u.contains('565')) return '565';
    if (u.contains('541')) return '541';
    if (u.contains('199')) return '199';
    if (u.contains('SCHEDULE_R') || u.endsWith('R') || u.contains('SCHEDULER')) return 'R';
    return '100';
  }

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

final tessaRepositoryProvider = Provider<TessaRepository>((ref) {
  return TessaRepository(
    ref.watch(laravelApiClientProvider),
    ref.watch(portalRepositoryProvider),
  );
});
