import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/localization/region_language_registry.dart';
import 'package:mkg_tax_mobile/core/localization/supported_locales.dart';
import 'package:mkg_tax_mobile/core/localization/tax_glossary.dart';
import 'package:mkg_tax_mobile/core/localization/locale_controller.dart';
import 'package:mkg_tax_mobile/core/voice/tessa_audio_service.dart';
import 'package:mkg_tax_mobile/core/voice/tessa_voice_flags.dart';

void main() {
  test('phase one UI locales are English and Spanish only', () {
    expect(SupportedLocales.phaseOneUi, ['en-US', 'es-US']);
    expect(SupportedLocales.isPhaseOneUi('es'), isTrue);
    expect(SupportedLocales.isPhaseOneUi('vi-VN'), isFalse);
  });

  test('voice remains disabled unless reviewed feature flag is on', () {
    expect(TessaVoiceFlags.voiceEnabled, isFalse);
    final body = const LanguagePreferences(spokenResponseEnabled: true).toApiBody();
    expect(body['spoken_response_enabled'], isFalse);
  });

  test('region priorities put Spanish second', () {
    final west = RegionLanguageRegistry.forRegion('1');
    expect(west[0], 'en-US');
    expect(west[1], 'es-US');
    expect(west, contains('nv-US'));
  });

  test('glossary preserves Form W-2 and money tokens', () {
    final ok = TaxGlossary.validatePreservedTokens(
      'Upload Form W-2 showing \$12,345.67',
      'Suba Form W-2 que muestra \$12,345.67',
    );
    expect(ok, isEmpty);

    final bad = TaxGlossary.validatePreservedTokens(
      'Upload Form W-2 showing \$12,345.67',
      'Suba el formulario de salarios',
    );
    expect(bad, isNotEmpty);
  });

  test('speech detection candidates capped at three and never silent-switch', () {
    final detection = LanguageDetectionService();
    final c = detection.candidates(preferred: 'es-US', secondary: 'en-US');
    expect(c.length, lessThanOrEqualTo(3));
    expect(c.first, 'es-US');
  });

  test('bilingual glossary Form W-2 keeps English form number', () {
    final es = TaxGlossary.term('form_w2', 'es-US');
    expect(es, contains('Form W-2'));
    expect(es, contains('Declaración'));
  });
}
