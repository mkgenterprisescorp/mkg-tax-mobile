import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/portal_repository.dart';
import '../../../core/config/app_config.dart';
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
