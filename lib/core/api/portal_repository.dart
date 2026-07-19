import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_error_mapper.dart';
import '../tax_year/return_number.dart';

/// Live mkgtaxconsultants.com client APIs (cookie session).
class PortalRepository {
  PortalRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> listTaxReturns() async {
    final res = await _api.get<dynamic>('/api/tax-returns');
    return _asMapList(res.data);
  }

  /// Staff/professional queue (`GET /api/tax-returns/all`). Falls back to own returns on 403.
  Future<List<Map<String, dynamic>>> listAllTaxReturns() async {
    final res = await _api.get<dynamic>('/api/tax-returns/all');
    if (res.statusCode == 200) return _asMapList(res.data);
    if (res.statusCode == 401 || res.statusCode == 403) {
      return listTaxReturns();
    }
    throw PortalException(_message(res.statusCode, 'Failed to load tax returns'));
  }

  Future<Map<String, dynamic>> toggleReturnLock(dynamic id, {required bool lock}) async {
    final res = await _api.post<dynamic>(
      '/api/tax-returns/$id/toggle-lock',
      data: {'action': lock ? 'lock' : 'unlock'},
    );
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'Failed to update lock'));
  }

  Future<List<Map<String, dynamic>>> listEroEfinDirectory() async {
    final res = await _api.get<dynamic>('/api/bureau/ero-efin');
    if (res.statusCode == 200) return _asMapList(res.data);
    if (res.statusCode == 401 || res.statusCode == 403) return const [];
    throw PortalException(_message(res.statusCode, 'Failed to load ERO directory'));
  }

  Future<List<Map<String, dynamic>>> listBureauPreparers() async {
    final res = await _api.get<dynamic>('/api/bureau/preparers');
    if (res.statusCode == 200) return _asMapList(res.data);
    if (res.statusCode == 401 || res.statusCode == 403) return const [];
    throw PortalException(_message(res.statusCode, 'Failed to load preparers'));
  }

  /// Professional client roster (`GET /api/clients/list`).
  Future<({List<Map<String, dynamic>> clients, String scope})> listClients() async {
    final res = await _api.get<dynamic>('/api/clients/list');
    if (res.statusCode != 200) {
      throw PortalException(_message(res.statusCode, 'Failed to load clients'));
    }
    final data = _asMap(res.data) ?? {};
    final clients = _asMapList(data['clients'] ?? data);
    final scope = (data['scope'] ?? 'unknown').toString();
    return (clients: clients, scope: scope);
  }

  Future<Map<String, dynamic>?> currentTaxReturn() async {
    final res = await _api.get<dynamic>('/api/tax-returns/current');
    if (res.statusCode != 200 || res.data == null) return null;
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> createTaxReturn({
    int? taxYear,
    String filingStatus = 'single',
    Map<String, dynamic>? data,
    String? lastName,
    Iterable<String> existingReturnNumbers = const [],
  }) async {
    final year = taxYear ?? DateTime.now().year - 1;
    final payload = Map<String, dynamic>.from(
      data ?? {'filingYear': year, 'source': 'mkg-tax-mobile'},
    );
    if ((payload['returnNumber'] ?? '').toString().trim().isEmpty) {
      payload['returnNumber'] = ReturnNumber.next(
        lastName: lastName ?? '',
        date: DateTime.now(),
        existingCodes: existingReturnNumbers,
      );
    }
    final res = await _api.post<dynamic>(
      '/api/tax-returns',
      data: {
        'year': year,
        'status': 'draft',
        'filingStatus': filingStatus,
        'data': payload,
      },
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return _asMap(res.data) ?? {};
    }
    throw PortalException(_message(res.statusCode, 'Failed to create tax return'));
  }

  /// Find return for [year] or create a draft. Auto-assigns `data.returnNumber`
  /// as `{LAST4}-{MM}-{DD}-{SEQ}` when missing.
  Future<Map<String, dynamic>> getOrCreateReturnForYear(
    int year, {
    String? lastName,
  }) async {
    final all = await listTaxReturns();
    final existingCodes = <String>[
      for (final row in all) ?ReturnNumber.fromWorkspaceJson(row),
    ];
    for (final row in all) {
      if ((row['year'] as num?)?.toInt() != year) continue;
      final code = ReturnNumber.fromWorkspaceJson(row);
      if (code != null) return row;
      final id = row['id'];
      if (id == null) return row;
      final data = Map<String, dynamic>.from((row['data'] as Map?) ?? {});
      final assigned = ReturnNumber.next(
        lastName: lastName ?? '${data['lastName'] ?? ''}',
        date: DateTime.now(),
        existingCodes: existingCodes,
      );
      data['returnNumber'] = assigned;
      return updateTaxReturn(id, {'data': data});
    }
    return createTaxReturn(
      taxYear: year,
      lastName: lastName,
      existingReturnNumbers: existingCodes,
    );
  }

  Future<List<int>> downloadDocumentBytes(dynamic documentId) async {
    final res = await _api.dio.get<List<int>>(
      '/api/documents/$documentId/download',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (c) => c != null && c < 500,
      ),
    );
    if (res.statusCode == 200 && res.data != null) return res.data!;
    // Fallback secure-download may require OTP — surface clear error.
    final secure = await _api.dio.get<List<int>>(
      '/api/documents/$documentId/secure-download',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (c) => c != null && c < 500,
        followRedirects: true,
      ),
    );
    if (secure.statusCode == 200 && secure.data != null) return secure.data!;
    throw PortalException(
      _message(secure.statusCode, 'Download failed (${res.statusCode}/${secure.statusCode}). OTP may be required on web.'),
    );
  }

  Future<Map<String, dynamic>> updateTaxReturn(
    dynamic id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put<dynamic>('/api/tax-returns/$id', data: body);
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'Failed to update tax return'));
  }

  Future<List<Map<String, dynamic>>> listDocuments(dynamic returnId) async {
    final res = await _api.get<dynamic>('/api/tax-returns/$returnId/documents');
    return _asMapList(res.data);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required MultipartFile file,
    required dynamic taxReturnId,
    String type = 'other',
  }) async {
    final form = FormData.fromMap({
      'file': file,
      'taxReturnId': '$taxReturnId',
      'type': type,
    });
    final res = await _api.postMultipart<dynamic>(
      '/api/documents/upload',
      formData: form,
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return _asMap(res.data) ?? {};
    }
    throw PortalException(_message(res.statusCode, 'Upload failed'));
  }

  Future<Map<String, dynamic>?> verificationStatus() async {
    final res = await _api.get<dynamic>('/api/user/verification-status');
    if (res.statusCode != 200) return null;
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> submitKyc(Map<String, dynamic> body) async {
    final res = await _api.post<dynamic>('/api/user/kyc-submit', data: body);
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'KYC submission failed'));
  }

  Future<Map<String, dynamic>> saveSsn(String ssn) async {
    final res = await _api.post<dynamic>('/api/user/ssn', data: {'ssn': ssn});
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'Failed to save SSN'));
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final res = await _api.put<dynamic>('/api/user/profile', data: body);
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'Profile update failed'));
  }

  Future<Map<String, dynamic>> calculateLoan(num amount) async {
    final res = await _api.post<dynamic>(
      '/api/loans/calculate',
      data: {'amount': amount},
    );
    if (res.statusCode == 200) return _asMap(res.data) ?? {};
    throw PortalException(_message(res.statusCode, 'Loan calculation failed'));
  }

  Future<Map<String, dynamic>> applyLoan(Map<String, dynamic> body) async {
    final res = await _api.post<dynamic>('/api/loans/apply', data: body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return _asMap(res.data) ?? {};
    }
    throw PortalException(_message(res.statusCode, 'Loan application failed'));
  }

  Future<List<Map<String, dynamic>>> listInvoices() async {
    final res = await _api.get<dynamic>('/api/invoicing/invoices');
    return _asMapList(res.data);
  }

  Future<List<Map<String, dynamic>>> listChatRooms() async {
    final res = await _api.get<dynamic>('/api/chat/rooms');
    return _asMapList(res.data);
  }

  Future<List<Map<String, dynamic>>> chatMessages(dynamic roomId) async {
    final res = await _api.get<dynamic>('/api/chat/rooms/$roomId/messages');
    return _asMapList(res.data);
  }

  Future<Map<String, dynamic>> sendChatMessage(
    dynamic roomId,
    String content,
  ) async {
    final res = await _api.post<dynamic>(
      '/api/chat/rooms/$roomId/messages',
      data: {'content': content},
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return _asMap(res.data) ?? {};
    }
    throw PortalException(_message(res.statusCode, 'Failed to send message'));
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final res = await _api.get<dynamic>('/api/conversations');
    return _asMapList(res.data);
  }

  Future<Map<String, dynamic>> createConversation({String? title}) async {
    final res = await _api.post<dynamic>(
      '/api/conversations',
      data: {'title': title ?? 'Mobile TaxPro Assist'},
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return _asMap(res.data) ?? {};
    }
    throw PortalException(_message(res.statusCode, 'Failed to start conversation'));
  }

  Future<Map<String, dynamic>?> getConversation(dynamic id) async {
    final res = await _api.get<dynamic>('/api/conversations/$id');
    if (res.statusCode != 200) return null;
    return _asMap(res.data);
  }

  /// Posts a message and collects SSE assistant text when possible.
  Future<String> sendAiMessage(dynamic conversationId, String content) async {
    final res = await _api.post<dynamic>(
      '/api/conversations/$conversationId/messages',
      data: {'content': content},
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw PortalException(_message(res.statusCode, 'AI reply failed'));
    }
    final raw = res.data?.toString() ?? '';
    final buffer = StringBuffer();
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final json = jsonDecode(payload);
        if (json is Map) {
          final delta = json['choices']?[0]?['delta']?['content'] ??
              json['content'] ??
              json['text'];
          if (delta != null) buffer.write(delta.toString());
        } else if (json is String) {
          buffer.write(json);
        }
      } catch (_) {
        buffer.write(payload);
      }
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty) return text;
    if (raw.trim().isNotEmpty && !raw.contains('data:')) return raw.trim();
    return 'I received your message. Open the web AI assistant if the reply did not stream fully on mobile.';
  }

  static List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Object>()
          .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{'value': e})
          .toList();
    }
    if (data is Map) {
      final nested = data['data'] ?? data['invoices'] ?? data['rooms'] ?? data['documents'];
      if (nested is List) return _asMapList(nested);
    }
    return const [];
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Safe, non-server-controlled message for a failed portal call. Never
  /// forwards the response body's `message`/`error` fields — those are
  /// server-authored free text and must not reach the UI directly. Falls
  /// back to [fallback] — a fixed, developer-authored string — when the
  /// status code has no specific mapping.
  static String _message(int? statusCode, String fallback) {
    final mapped = ApiErrorMapper.mapStatusCode(statusCode);
    return mapped == ApiErrorMapper.genericMessage ? fallback : mapped;
  }
}

class PortalException implements Exception {
  PortalException(this.message);
  final String message;
  @override
  String toString() => message;
}

final portalRepositoryProvider = Provider<PortalRepository>((ref) {
  return PortalRepository(ref.watch(apiClientProvider));
});
