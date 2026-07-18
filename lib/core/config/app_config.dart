/// Public compile-time config. Never put secrets or Neon URLs here.
///
/// Authoritative staging/production API root:
/// `https://app.mkgtaxconsultants.com/api/v1`
///
/// Web client portal:
/// `https://mkgtaxconsultants.com`
///
/// There is deliberately no default value for [apiBaseUrl] — a build that
/// omits `--dart-define=API_BASE_URL=...` must fail loudly at startup (see
/// [AppConfig.validate]) rather than silently talk to some other host.
///
/// Flutter must never connect directly to Neon PostgreSQL or `/internal/*`.
class AppConfig {
  /// API root. No default — see [validate].
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Public web client portal origin (DigitalOcean). Deep links / marketing —
  /// not part of the authenticated mobile API surface.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://mkgtaxconsultants.com',
  );

  /// Hosted invoices/payments page opened from the mobile billing UI.
  /// Always defaults to the authoritative portal — never `financemkgtax.com`.
  static const String _paymentsWebUrlEnv = String.fromEnvironment(
    'PAYMENTS_WEB_URL',
    defaultValue: '',
  );

  /// Optional override for Laravel host origin (defaults derived from [apiBaseUrl]).
  /// Used when Dio needs the host without `/api/v1` (paths then include `/api/v1/...`).
  static const String laravelApiBaseUrl = String.fromEnvironment(
    'LARAVEL_API_BASE_URL',
    defaultValue: '',
  );

  /// Legacy Replit portal hosts — rewrite to [canonicalPortalHost] for deep links.
  static const Set<String> legacyPortalHosts = {
    'financemkgtax.com',
    'www.financemkgtax.com',
  };

  static const String canonicalPortalHost = 'mkgtaxconsultants.com';

  /// Set only for local-development builds against a plain-HTTP dev server
  /// (e.g. an Android emulator hitting `http://10.0.2.2:8000`). Never set
  /// this for a staging or production build.
  static const bool allowInsecureLocalDev = bool.fromEnvironment(
    'ALLOW_INSECURE_LOCAL_DEV',
    defaultValue: false,
  );

  static const List<String> _localDevHosts = ['localhost', '127.0.0.1', '10.0.2.2'];

  static String get apiRoot => _trim(apiBaseUrl);

  static String get webRoot => rewriteLegacyPortalUri(Uri.parse(_trim(webBaseUrl))).toString();

  /// Authoritative hosted payments URL for "Open hosted payments on web".
  static String get paymentsWebUrl {
    final configured = _paymentsWebUrlEnv.trim();
    if (configured.isNotEmpty) {
      return rewriteLegacyPortalUri(Uri.parse(_trim(configured))).toString();
    }
    return 'https://$canonicalPortalHost/payments';
  }

  /// Rewrites legacy `financemkgtax.com` portal hosts to `mkgtaxconsultants.com`.
  /// Leaves Stripe/checkout and unrelated hosts unchanged.
  static Uri rewriteLegacyPortalUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (legacyPortalHosts.contains(host)) {
      return uri.replace(scheme: 'https', host: canonicalPortalHost);
    }
    return uri;
  }

  /// Laravel origin (strip trailing `/api/v1` when present).
  static String get laravelApiRoot {
    if (laravelApiBaseUrl.trim().isNotEmpty) {
      return _trim(laravelApiBaseUrl);
    }
    final root = apiRoot;
    const suffix = '/api/v1';
    if (root.endsWith(suffix)) {
      return root.substring(0, root.length - suffix.length);
    }
    return root;
  }

  static bool get hasLaravelApi => laravelApiRoot.isNotEmpty;

  /// True when [apiBaseUrl] targets Laravel `/api/v1` (Sanctum). After
  /// [validate] has passed, this is always true — kept as a named check
  /// (rather than assuming it) because AuthRepository's portal-cookie code
  /// path is still reachable in tests that bypass validate().
  static bool get usesLaravelAuth => apiRoot.toLowerCase().contains('/api/v1');

  static bool get usesPortalCookieAuth => !usesLaravelAuth;

  /// Short, non-secret label for a diagnostics/about screen.
  /// Client-facing — never includes implementation hostnames or stack names.
  /// Validates [apiBaseUrl] and throws [AppConfigError] — with a message
  /// naming exactly what's wrong — if it is missing or malformed. Call this
  /// once, early in `main()`, before running the real app widget tree. A
  /// misconfigured build must fail loudly, never silently default to some
  /// other host.
  static void validate() => validateUrl(apiBaseUrl, allowInsecureLocalDev: allowInsecureLocalDev);

  /// The actual validation logic, extracted as a pure function of its
  /// arguments so it can be unit-tested against arbitrary inputs — the real
  /// [apiBaseUrl]/[allowInsecureLocalDev] are compile-time `const` values
  /// and can't be varied within a single test binary.
  static void validateUrl(String raw, {bool allowInsecureLocalDev = false}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw AppConfigError(
        'API_BASE_URL was not supplied at build time. Pass '
        '--dart-define=API_BASE_URL=https://app.mkgtaxconsultants.com/api/v1 '
        'when building — there is no default host.',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      throw AppConfigError('API_BASE_URL is not a valid absolute URL: "$trimmed".');
    }

    final isPermittedLocalDev = allowInsecureLocalDev && _localDevHosts.contains(uri.host);
    if (uri.scheme != 'https' && !isPermittedLocalDev) {
      throw AppConfigError(
        'API_BASE_URL must use https:// (got "${uri.scheme}://"). Plain http '
        'is only permitted for local development against localhost/127.0.0.1/'
        '10.0.2.2 with --dart-define=ALLOW_INSECURE_LOCAL_DEV=true.',
      );
    }

    final path = _trim(uri.path);
    if (!path.endsWith('/api/v1')) {
      throw AppConfigError(
        'API_BASE_URL must end with /api/v1 (got path "$path" in "$trimmed").',
      );
    }

    final occurrences = RegExp(r'/api/v1').allMatches(path).length;
    if (occurrences > 1) {
      throw AppConfigError('API_BASE_URL contains a duplicated /api/v1 path segment: "$trimmed".');
    }
  }

  static String _trim(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// Thrown by [AppConfig.validate] when the build-time API configuration is
/// missing or malformed. Callers should catch this in `main()` and show a
/// dedicated configuration-error screen instead of running the normal app.
class AppConfigError extends Error {
  AppConfigError(this.message);

  final String message;

  @override
  String toString() => 'AppConfigError: $message';
}
