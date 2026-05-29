// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/animated_orb.dart';
import '../widgets/clareon_logo.dart';
import '../widgets/shared_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  
  // Clear any previous error first
  ref.read(authProvider.notifier).clearError();
  
  final success = await ref
      .read(authProvider.notifier)
      .login(_emailCtrl.text.trim(), _passwordCtrl.text);
  if (success && mounted) context.go('/home');
}

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle blue glow behind orb
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2563EB)
                          .withOpacity(isDark ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Center(child: AnimatedOrb(size: 60)),
                      const SizedBox(height: 20),
                      const Center(child: ClareonLogo()),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'AI meeting intelligence',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(letterSpacing: 0.4),
                        ),
                      ),
                      const SizedBox(height: 52),
                      Text('Welcome back',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Sign in to continue',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 32),
                      if (state.errorMessage != null)
                        ErrorBanner(message: state.errorMessage!),
                      AuthTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        isPassword: true,
                        textInputAction: TextInputAction.done,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Enter your password'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push('/forgot-password'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClareonButton(
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                        label: 'Sign In',
                      ),
                      const SizedBox(height: 20),
                      const OrDivider(),
                      const SizedBox(height: 20),
                      KingsChatButton(
                        onPressed: () =>
                            context.push('/kingschat-login'),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?",
                              style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () {
                              ref.read(authProvider.notifier).clearError(); 
                              context.push('/signup');
                            },
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}