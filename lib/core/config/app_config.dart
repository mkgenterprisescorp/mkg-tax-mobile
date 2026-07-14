/// Public compile-time config. Never put secrets or Neon URLs here.
///
/// Target architecture (when DigitalOcean `api.financemkgtax.com` is live):
/// ```
/// Flutter → HTTPS → api.financemkgtax.com/api/v1 (Laravel) → Neon
/// ```
/// **Default build (transitional):** portal host `https://financemkgtax.com`
/// with cookie session auth until the API subdomain DNS + Laravel cutover is ready.
/// Flip production with:
/// `--dart-define=API_BASE_URL=https://api.financemkgtax.com/api/v1`
///
/// Flutter must never connect directly to Neon PostgreSQL.
class AppConfig {
  /// API root. Default = transitional portal (cookie auth).
  /// Production Sanctum: https://api.financemkgtax.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://financemkgtax.com',
  );

  /// Public web app origin (DigitalOcean). Deep links / marketing.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://financemkgtax.com',
  );

  /// Optional override for Laravel host origin (defaults derived from [apiBaseUrl]).
  /// Used for `/api/mobile/*` routes that sit beside `/api/v1`.
  static const String laravelApiBaseUrl = String.fromEnvironment(
    'LARAVEL_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiRoot => _trim(apiBaseUrl);

  static String get webRoot => _trim(webBaseUrl);

  /// Laravel origin for `/api/mobile/*` (strip trailing `/api/v1` when present).
  static String get laravelApiRoot {
    if (laravelApiBaseUrl.trim().isNotEmpty) {
      return _trim(laravelApiBaseUrl);
    }
    final root = apiRoot;
    const suffix = '/api/v1';
    if (root.endsWith(suffix)) {
      return root.substring(0, root.length - suffix.length);
    }
    // Transitional: portal host used as API_BASE_URL without /api/v1.
    return root;
  }

  static bool get hasLaravelApi => laravelApiRoot.isNotEmpty;

  /// True when [apiBaseUrl] targets Laravel `/api/v1` (Sanctum), not legacy portal cookies.
  static bool get usesLaravelAuth {
    final root = apiRoot.toLowerCase();
    return root.contains('/api/v1') || root.startsWith('https://api.financemkgtax.com');
  }

  /// True when API_BASE_URL still points at the cookie portal (device-verify / transitional).
  static bool get usesPortalCookieAuth => !usesLaravelAuth;

  /// Short label for login / about UI.
  static String get authModeLabel =>
      usesLaravelAuth ? 'Laravel Sanctum (api.financemkgtax.com)' : 'Portal sign-in (financemkgtax.com)';

  static String _trim(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
