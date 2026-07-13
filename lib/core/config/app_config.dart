/// Public compile-time config. Never put secrets here.
class AppConfig {
  /// Production TaxPro / financemkgtaxpro portal.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://financemkgtax.com',
  );

  static String get apiRoot => apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
}
