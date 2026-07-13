

class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String accessTokenKey = 'hamili_access_token';
  static const String refreshTokenKey = 'hamili_refresh_token';
}
