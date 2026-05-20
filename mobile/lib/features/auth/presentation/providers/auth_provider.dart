import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

// Auth state
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
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: parseError(e),
      );
      return false;
    }
  }

  Future<bool> signup(String email, String fullName, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.signup(email: email, fullName: fullName, password: password);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Account created! Check your email to verify.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: parseError(e),
      );
      return false;
    }
  }

  Future<bool> verifyEmail(String token) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.verifyEmail(token);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Email verified! You can now log in.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: parseError(e),
      );
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.forgotPassword(email);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Reset instructions sent to your email.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: parseError(e),
      );
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.resetPassword(token: token, newPassword: newPassword);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Password reset successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: parseError(e),
      );
      return false;
    }
  }

  /// Extracts a user-friendly message from exceptions.
  String parseError(Object e) {
    if (e is DioException) {
      return e.response?.data?['detail'] ?? 'Network error';
    }
    return e.toString();
  }

  void reset() => state = const AuthState();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

// Is user logged in (checks stored token)
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  return ref.read(authRepositoryProvider).isLoggedIn();
});