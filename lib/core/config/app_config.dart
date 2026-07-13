/// Public runtime config only. Never store secrets here.
class AppConfig {
  /// Public API base URL for Laravel (`API_BASE_URL`).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
