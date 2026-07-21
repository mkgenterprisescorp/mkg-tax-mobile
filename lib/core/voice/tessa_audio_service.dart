import '../network/laravel_api_client.dart';
import '../platform/platform_api.dart';

/// Client-side capture stub — audio bytes go to Laravel STT only (no API keys here).
class SpeechCaptureService {
  Future<List<int>> capturePlaceholder() async => const [];
}

/// Language detection is advisory; Laravel asks before switching.
class LanguageDetectionService {
  /// Never auto-apply. Returns candidates for Laravel (max 3).
  List<String> candidates({
    required String preferred,
    required String secondary,
  }) {
    final codes = <String>{preferred, secondary, 'en-US'}.toList();
    return codes.take(3).toList();
  }
}

/// TTS/STT via Laravel gateway — Gemini/Speech keys stay server-side.
class TessaAudioService {
  TessaAudioService(this._api);
  final LaravelApiClient _api;

  Future<Map<String, dynamic>?> transcribe({
    required String audioBase64,
    required List<String> languageCodes,
    String mimeType = 'audio/wav',
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/tessa/languages/speech/transcribe',
      data: {
        'audio_base64': audioBase64,
        'mime_type': mimeType,
        'language_codes': languageCodes.take(3).toList(),
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }

  Future<Map<String, dynamic>?> synthesize({
    required String text,
    required String languageCode,
  }) async {
    if (_api.bearerToken == null) return null;
    final res = await _api.post<Map<String, dynamic>>(
      '/api/v1/tessa/languages/speech/synthesize',
      data: {
        'text': text,
        'language_code': languageCode,
      },
    );
    if (!PlatformApi.ok(res)) return null;
    return PlatformApi.unwrapMap(res);
  }
}
