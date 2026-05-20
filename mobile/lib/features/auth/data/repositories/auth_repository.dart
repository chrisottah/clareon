import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:clareon/core/network/api_client.dart';
import 'package:clareon/core/config/app_config.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  final _dio = ApiClient.dio;

  Future<void> signup({
    required String email,
    required String fullName,
    required String password,
  }) async {
    await _dio.post('/auth/signup', data: {
      'email': email,
      'full_name': fullName,
      'password': password,
    });
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _storage.write(
      key: AppConfig.accessTokenKey,
      value: response.data['access_token'],
    );
    await _storage.write(
      key: AppConfig.refreshTokenKey,
      value: response.data['refresh_token'],
    );
  }

  Future<void> verifyEmail(String token) async {
    await _dio.post('/auth/verify-email', data: {'token': token});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _dio.post('/auth/reset-password', data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConfig.accessTokenKey);
    return token != null;
  }
}

/// Parse Dio errors into readable messages
String parseError(Object e) {
  if (e is DioException && e.response?.data != null) {
    final data = e.response!.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
  }
  return 'Something went wrong. Please try again.';
}
