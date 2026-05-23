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
    await _saveTokens(response.data);
  }

  Future<void> verifyEmail({required String email, required String otp}) async {
    await _dio.post('/auth/verify-email', data: {'email': email, 'otp': otp});
  }

  Future<void> resendOtp({required String email}) async {
    await _dio.post('/auth/resend-otp', data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  Future<void> loginWithKingsChat({
    required String accessToken,
    String? refreshToken,
  }) async {
    final response = await _dio.post('/auth/kingschat', data: {
      'access_token': accessToken,
      'refresh_token': refreshToken,
    });
    await _saveTokens(response.data);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: AppConfig.accessTokenKey, value: data['access_token']);
    await _storage.write(key: AppConfig.refreshTokenKey, value: data['refresh_token']);
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

String parseError(Object e) {
  if (e is DioException && e.response?.data != null) {
    final data = e.response!.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
  }
  return 'Something went wrong. Please try again.';
}