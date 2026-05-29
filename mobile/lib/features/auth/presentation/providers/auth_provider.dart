import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

enum AuthStatus { initial, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.successMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? successMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage,
        successMessage: successMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState());

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.login(email: email, password: password);
      state = state.copyWith(status: AuthStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  Future<bool> signup(String email, String fullName, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.signup(email: email, fullName: fullName, password: password);
      state = state.copyWith(status: AuthStatus.success, successMessage: 'Account created! Check your email for the 6-digit code.');
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  Future<bool> verifyEmail(String email, String otp) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.verifyEmail(email: email, otp: otp);
      state = state.copyWith(status: AuthStatus.success, successMessage: 'Email verified! You can now log in.');
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _repo.resendOtp(email: email);
    } catch (_) {}
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.forgotPassword(email);
      state = state.copyWith(status: AuthStatus.success, successMessage: 'Reset code sent to your email.');
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.resetPassword(email: email, otp: otp, newPassword: newPassword);
      state = state.copyWith(status: AuthStatus.success, successMessage: 'Password reset successfully.');
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  Future<bool> loginWithKingsChat(String accessToken, String? refreshToken) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.loginWithKingsChat(accessToken: accessToken, refreshToken: refreshToken);
      state = state.copyWith(status: AuthStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: _parseError(e));
      return false;
    }
  }

  void reset() => state = const AuthState();

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

    String _parseError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      if (data is String) {
        return data;
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  return ref.read(authRepositoryProvider).isLoggedIn();
});