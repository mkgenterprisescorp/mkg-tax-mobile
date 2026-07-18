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
    if (_api.bearerToken == null) return null;
    final res = await _api.put<Map<String, dynamic>>(
      '/api/v1/tax-year-workspaces/$workspaceId/organizer',
      data: {
        'prep_type': prepType,
        'section_key': sectionKey,
        'answers': answers,
        'section_complete': sectionComplete,
        if (status != null) 'status': status,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  /// Persist every catalog section from canonical organizer [data].
  Future<Map<String, dynamic>?> saveAllSections({
    required String workspaceId,
    required Map<String, dynamic> data,
    bool submit = false,
  }) async {
    final prep = '${data['prepType'] ?? 'personal'}';
    Map<String, dynamic>? last;
    final keys = OrganizerSectionMapper.sectionKeysForPrep(prep);
    // Skip Schedule C when not applicable so completion % is not inflated.
    final effectiveKeys = [
      for (final k in keys)
        if (k != 'schedule_c' || showScheduleCStep(data)) k,
    ];
    for (var i = 0; i < effectiveKeys.length; i++) {
      final key = effectiveKeys[i];
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
        'state_ca_540' => 'State Tax Returns',
        'state_multistate' => 'State Tax Returns',
        'direct_deposit' => 'Direct Deposit',
        'review_sign' => 'Review & Sign',
        'entity_form' => businessFormLabels[prep] ?? 'Entity Form',
        _ => key,
      };
      last = await updateSection(
        workspaceId: workspaceId,
        sectionKey: key,
        answers: OrganizerSectionMapper.answersForSection(key, data),
        sectionComplete: isOrganizerStepComplete(stepTitle, data),
        prepType: prep,
        status: submit && i == effectiveKeys.length - 1 ? 'processing' : null,
      );
    }
    return last;
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
