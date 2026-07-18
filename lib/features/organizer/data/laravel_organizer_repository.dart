import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import 'organizer_defaults.dart';
import 'organizer_section_mapper.dart';

/// Server-driven organizer for Sanctum `/api/v1` builds.
class LaravelOrganizerRepository {
  LaravelOrganizerRepository(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> show(String workspaceId, {String prepType = 'personal'}) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.get<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      query: {'prep_type': prepType},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> updateSection({
    required String workspaceId,
    required String sectionKey,
    required Map<String, dynamic> answers,
    bool sectionComplete = false,
    String prepType = 'personal',
    String? status,
  }) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to save your organizer.');
    }
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      data: {
        'prep_type': prepType,
        'section_key': sectionKey,
        'answers': answers,
        'section_complete': sectionComplete,
        if (status case final statusValue?) 'status': statusValue,
      },
    );
    if (!PlatformApi.ok(res)) {
      throw StateError(_saveFailureMessage(res.statusCode));
    }
    return PlatformApi.unwrapMap(res);
  }

  /// Persist every catalog section from canonical organizer [data] in **one** PUT.
  /// Avoids N-section request storms that stall autosave under `throttle:30,1`.
  Future<Map<String, dynamic>?> saveAllSections({
    required String workspaceId,
    required Map<String, dynamic> data,
    bool submit = false,
  }) async {
    if (_api.bearerToken == null) {
      throw StateError('Please sign in again to save your organizer.');
    }
    final prep = '${data['prepType'] ?? 'personal'}';
    final keys = OrganizerSectionMapper.sectionKeysForPrep(prep);
    final effectiveKeys = [
      for (final k in keys)
        if (k != 'schedule_c' || showScheduleCStep(data)) k,
    ];

    final sections = <Map<String, dynamic>>[];
    for (final key in effectiveKeys) {
      final stepTitle = switch (key) {
        'filing_info' => 'Filing Info',
        'personal_info' => 'Personal Info',
        'income_1040' => 'Income (1040)',
        'schedule_b' => 'Schedule B',
        'schedule_c' => 'Schedule C',
        'schedule_d' => 'Schedule D',
        'schedule_e' => 'Schedule E',
        'schedule_f' => 'Schedule F',
        'credits_deductions' => 'Credits & Deductions',
        'form_1040x' => 'Form 1040-X',
        'state_ca_540' => 'State Tax Returns',
        'state_multistate' => 'State Tax Returns',
        'direct_deposit' => 'Direct Deposit',
        'review_sign' => 'Review & Sign',
        'entity_form' => businessFormLabels[prep] ?? 'Entity Form',
        _ => key,
      };
      sections.add({
        'section_key': key,
        'answers': OrganizerSectionMapper.answersForSection(key, data),
        'section_complete': isOrganizerStepComplete(stepTitle, data),
      });
    }

    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      data: {
        'prep_type': prep,
        'sections': sections,
        if (submit) 'status': 'processing' else 'status': 'draft',
      },
    );
    if (!PlatformApi.ok(res)) {
      throw StateError(_saveFailureMessage(res.statusCode));
    }
    return PlatformApi.unwrapMap(res);
  }

  String _saveFailureMessage(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'Please sign in again to save your organizer.';
      case 403:
        return 'This action is not authorized.';
      case 422:
        return 'Some information could not be validated. Please check your entries and try again.';
      case 429:
        return 'Too many save requests — wait a moment and try again.';
      default:
        return 'We’re unable to save your organizer right now. Please try again.';
    }
  }

  Future<Map<String, dynamic>?> requestChange({
    required String organizerId,
    required Map<String, dynamic> payload,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/organizers/$organizerId/change-requests',
      data: {'payload': payload},
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}

final laravelOrganizerRepositoryProvider = Provider<LaravelOrganizerRepository>((ref) {
  return LaravelOrganizerRepository(ref.watch(laravelApiClientProvider));
});
