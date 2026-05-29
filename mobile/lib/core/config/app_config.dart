/// Central app configuration.
/// Update BASE_URL when deploying to production.
class AppConfig {
  AppConfig._();

  // Change to your local IP when testing on a real device
  // e.g. "http://192.168.1.100:8000/api/v1"
  static const String baseUrl =
    String.fromEnvironment('BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1');

  static const String appName = 'Clareon';
  static const String appVersion = '1.0.0';

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // Audio
  static const int audioSampleRate = 44100;
  static const int audioBitRate = 128000;
}
