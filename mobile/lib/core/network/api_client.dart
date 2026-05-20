import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient._();

  static final _storage = const FlutterSecureStorage();

  static Dio get dio {
    final d = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Attach access token to every request
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConfig.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Token expired — try refresh
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh(d);
            if (refreshed) {
              // Retry original request with new token
              final token = await _storage.read(key: AppConfig.accessTokenKey);
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await d.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
          return handler.next(error);
        },
      ),
    );

    return d;
  }

  static Future<bool> _tryRefresh(Dio dio) async {
    try {
      final refreshToken = await _storage.read(key: AppConfig.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConfig.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      await _storage.write(
        key: AppConfig.accessTokenKey,
        value: response.data['access_token'],
      );
      await _storage.write(
        key: AppConfig.refreshTokenKey,
        value: response.data['refresh_token'],
      );
      return true;
    } catch (_) {
      await _storage.deleteAll();
      return false;
    }
  }
}
