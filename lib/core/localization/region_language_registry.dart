/// Curated MKG regional language priorities (mirrors Laravel config seed).
/// Re-ranked annually from ACS B16001/C16001 via Laravel — not Census 4-region geography.
class RegionLanguageRegistry {
  RegionLanguageRegistry._();

  static const Map<String, List<String>> priorities = {
    '1': [
      'en-US', 'es-US', 'cmn-Hans-CN', 'yue-Hant-HK', 'vi-VN', 'fil-PH', 'ko-KR',
      'nv-US', 'ja-JP', 'hi-IN', 'pa-IN', 'ar-US', 'fa-IR',
    ],
    '2': [
      'en-US', 'es-US', 'ar-US', 'pl-PL', 'de-DE', 'so-SO', 'hmn', 'fr-US',
      'cmn-Hans-CN', 'vi-VN', 'hi-IN', 'ur-PK', 'uk-UA',
    ],
    '3': [
      'en-US', 'es-US', 'vi-VN', 'cmn-Hans-CN', 'ar-US', 'ht-HT', 'fr-US',
      'hi-IN', 'ur-PK', 'gu-IN', 'bn-IN', 'ko-KR', 'pt-BR',
    ],
    '4': [
      'en-US', 'es-US', 'cmn-Hans-CN', 'yue-Hant-HK', 'ko-KR', 'vi-VN', 'ar-US',
      'fr-US', 'ht-HT', 'am-ET', 'ur-PK', 'hi-IN', 'bn-IN', 'ru-RU',
    ],
    '5': [
      'en-US', 'es-US', 'cmn-Hans-CN', 'yue-Hant-HK', 'pt-BR', 'ht-HT', 'fr-US',
      'ru-RU', 'pl-PL', 'ar-US', 'bn-IN', 'hi-IN', 'ur-PK', 'it-IT', 'uk-UA',
    ],
    '6': [
      'en-US', 'es-US', 'cmn-Hans-CN', 'yue-Hant-HK', 'vi-VN', 'fil-PH', 'ko-KR',
      'ru-RU', 'uk-UA', 'ja-JP', 'so-SO', 'pa-IN', 'hi-IN',
    ],
  };

  static const regionNames = {
    '1': 'West / Southwest',
    '2': 'Midwest',
    '3': 'South',
    '4': 'East / Mid-Atlantic',
    '5': 'Northeast',
    '6': 'Northwest',
  };

  static List<String> forRegion(String regionId) =>
      List.unmodifiable(priorities[regionId] ?? const ['en-US', 'es-US']);
}
