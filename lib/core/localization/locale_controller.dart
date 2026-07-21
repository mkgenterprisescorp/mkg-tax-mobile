import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voice/tessa_voice_flags.dart';
import 'supported_locales.dart';

class LanguagePreferences {
  const LanguagePreferences({
    this.preferredLanguage = 'en-US',
    this.secondaryLanguage = 'en-US',
    this.regionId = '1',
    this.spokenResponseEnabled = false,
    this.bilingualTaxTerms = true,
    this.keepFormLabelsEnglish = true,
    this.humanInterpreterRequested = false,
    this.setupCompleted = false,
  });

  final String preferredLanguage;
  final String secondaryLanguage;
  final String regionId;
  final bool spokenResponseEnabled;
  final bool bilingualTaxTerms;
  final bool keepFormLabelsEnglish;
  final bool humanInterpreterRequested;
  final bool setupCompleted;

  LanguagePreferences copyWith({
    String? preferredLanguage,
    String? secondaryLanguage,
    String? regionId,
    bool? spokenResponseEnabled,
    bool? bilingualTaxTerms,
    bool? keepFormLabelsEnglish,
    bool? humanInterpreterRequested,
    bool? setupCompleted,
  }) {
    return LanguagePreferences(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      secondaryLanguage: secondaryLanguage ?? this.secondaryLanguage,
      regionId: regionId ?? this.regionId,
      spokenResponseEnabled: spokenResponseEnabled ?? this.spokenResponseEnabled,
      bilingualTaxTerms: bilingualTaxTerms ?? this.bilingualTaxTerms,
      keepFormLabelsEnglish: keepFormLabelsEnglish ?? this.keepFormLabelsEnglish,
      humanInterpreterRequested:
          humanInterpreterRequested ?? this.humanInterpreterRequested,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }

  Map<String, dynamic> toApiBody() => {
        'preferred_language': preferredLanguage,
        'secondary_language': secondaryLanguage,
        'region_id': regionId,
        // Voice stays off unless [TessaVoiceFlags.voiceEnabled] is reviewed on.
        'spoken_response_enabled':
            TessaVoiceFlags.voiceEnabled && spokenResponseEnabled,
        'bilingual_tax_terms': bilingualTaxTerms,
        'keep_form_labels_english': keepFormLabelsEnglish,
        'human_interpreter_requested': humanInterpreterRequested,
      };

  Locale get materialLocale {
    final code = SupportedLocales.normalize(preferredLanguage);
    if (code.startsWith('es')) return const Locale('es');
    return const Locale('en');
  }
}

class LocaleController extends Notifier<LanguagePreferences> {
  static const _prefsKey = 'tessa_language_preferences_v1';

  @override
  LanguagePreferences build() {
    Future.microtask(_hydrate);
    return const LanguagePreferences();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parts = Uri.splitQueryString(raw);
      state = LanguagePreferences(
        preferredLanguage: SupportedLocales.normalize(parts['preferred'] ?? 'en-US'),
        secondaryLanguage: SupportedLocales.normalize(parts['secondary'] ?? 'en-US'),
        regionId: parts['region'] ?? '1',
        spokenResponseEnabled:
            TessaVoiceFlags.voiceEnabled && parts['spoken'] == '1',
        bilingualTaxTerms: parts['bilingual'] != '0',
        keepFormLabelsEnglish: parts['keep_en'] != '0',
        humanInterpreterRequested: parts['interpreter'] == '1',
        setupCompleted: parts['setup'] == '1',
      );
    } catch (_) {
      // Keep defaults — never infer from device.
    }
  }

  Future<void> updateLocal(LanguagePreferences next) async {
    // Never silently switch: only explicit updates reach here.
    final normalized = next.copyWith(
      preferredLanguage: SupportedLocales.normalize(next.preferredLanguage),
      secondaryLanguage: SupportedLocales.normalize(next.secondaryLanguage),
      spokenResponseEnabled:
          TessaVoiceFlags.voiceEnabled && next.spokenResponseEnabled,
    );
    state = normalized;
    final prefs = await SharedPreferences.getInstance();
    final encoded = [
      'preferred=${Uri.encodeComponent(normalized.preferredLanguage)}',
      'secondary=${Uri.encodeComponent(normalized.secondaryLanguage)}',
      'region=${Uri.encodeComponent(normalized.regionId)}',
      'spoken=${normalized.spokenResponseEnabled ? 1 : 0}',
      'bilingual=${normalized.bilingualTaxTerms ? 1 : 0}',
      'keep_en=${normalized.keepFormLabelsEnglish ? 1 : 0}',
      'interpreter=${normalized.humanInterpreterRequested ? 1 : 0}',
      'setup=${normalized.setupCompleted ? 1 : 0}',
    ].join('&');
    await prefs.setString(_prefsKey, encoded);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, LanguagePreferences>(LocaleController.new);
