import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/kingschat_webview_screen.dart';
import '../../features/meetings/presentation/screens/home_screen.dart';
import '../../features/recording/presentation/screens/recording_screen.dart';
import '../../features/meetings/presentation/screens/meeting_detail_screen.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

final _authRepo = AuthRepository();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    redirect: (context, state) async {
      final loggedIn = await _authRepo.isLoggedIn();
      final onAuth = state.uri.toString().startsWith('/login') ||
          state.uri.toString().startsWith('/signup') ||
          state.uri.toString().startsWith('/forgot') ||
          state.uri.toString().startsWith('/reset') ||
          state.uri.toString().startsWith('/verify') ||
          state.uri.toString().startsWith('/kingschat');
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && state.uri.toString() == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/kingschat-login', builder: (_, __) => const KingsChatWebViewScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/record', builder: (_, __) => const RecordingScreen()),
      GoRoute(
        path: '/meeting/:id',
        builder: (context, state) => MeetingDetailScreen(meetingId: state.pathParameters['id']!),
      ),
    ],
  );
});

class AppRouter {
  AppRouter._();
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/kingschat-login', builder: (_, __) => const KingsChatWebViewScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/record', builder: (_, __) => const RecordingScreen()),
      GoRoute(
        path: '/meeting/:id',
        builder: (context, state) => MeetingDetailScreen(meetingId: state.pathParameters['id']!),
      ),
    ],
  );
}