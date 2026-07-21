/// Phase-1 supported UI locales + full launch catalog metadata (BCP-47).
class SupportedLocales {
  SupportedLocales._();

  /// UI localization enabled in Phase 1.
  static const phaseOneUi = ['en-US', 'es-US'];

  /// Full launch catalog (capability gated by Laravel TESSA_LANGUAGE_PHASE).
  static const launchCatalog = <String, String>{
    'en-US': 'English',
    'es-US': 'Spanish',
    'cmn-Hans-CN': 'Mandarin Chinese',
    'yue-Hant-HK': 'Cantonese Chinese',
    'vi-VN': 'Vietnamese',
    'fil-PH': 'Filipino / Tagalog',
    'ko-KR': 'Korean',
    'ar-US': 'Arabic',
    'fr-US': 'French',
    'ht-HT': 'Haitian Creole',
    'pt-BR': 'Portuguese',
    'ru-RU': 'Russian',
    'hi-IN': 'Hindi',
    'ur-PK': 'Urdu',
    'pa-IN': 'Punjabi',
    'gu-IN': 'Gujarati',
    'bn-IN': 'Bengali',
    'te-IN': 'Telugu',
    'ta-IN': 'Tamil',
    'ja-JP': 'Japanese',
    'fa-IR': 'Persian / Farsi',
    'de-DE': 'German',
    'pl-PL': 'Polish',
    'so-SO': 'Somali',
    'hmn': 'Hmong',
    'am-ET': 'Amharic',
    'uk-UA': 'Ukrainian',
    'nv-US': 'Navajo',
  };

  static String displayName(String code) => launchCatalog[code] ?? code;

  static bool isPhaseOneUi(String code) => phaseOneUi.contains(normalize(code));

  static String normalize(String code) {
    final c = code.trim().replaceAll('_', '-');
    const aliases = {
      'en': 'en-US',
      'es': 'es-US',
      'zh': 'cmn-Hans-CN',
      'zh-CN': 'cmn-Hans-CN',
      'zh-Hans': 'cmn-Hans-CN',
    };
    return aliases[c] ?? c;
  }
}
