/// Public compile-time config. Never put secrets here.
///
/// Architecture rule: Flutter talks to HTTP APIs only — never Neon PostgreSQL.
/// Tax-year workspace APIs live on Laravel (`LARAVEL_API_BASE_URL`).
/// Legacy portal cookie APIs remain on `API_BASE_URL` until Sanctum cutover completes.
class AppConfig {
  /// financemkgtaxpro portal (cookie session) — transitional.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://financemkgtax.com',
  );

  /// Laravel Chinese Wall / mobile tax-year API host.
  /// Example local: http://127.0.0.1:8000
  static const String laravelApiBaseUrl = String.fromEnvironment(
    'LARAVEL_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiRoot => _trim(apiBaseUrl);

  static String get laravelApiRoot => _trim(laravelApiBaseUrl);

  static bool get hasLaravelApi => laravelApiRoot.isNotEmpty;

  static String _trim(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
