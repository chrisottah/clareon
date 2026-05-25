// lib/features/auth/presentation/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/animated_orb.dart';
import '../widgets/shared_ui.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).signup(
          _emailCtrl.text.trim(),
          _nameCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (success && mounted) {
      context.push('/verify-email', extra: _emailCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.status == AuthStatus.loading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const MinimalAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Center(child: AnimatedOrb(size: 56)),
                  const SizedBox(height: 28),
                  Text('Create account',
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Start capturing your meetings',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  if (state.errorMessage != null)
                    ErrorBanner(message: state.errorMessage!),
                  AuthTextField(
                    controller: _nameCtrl,
                    label: 'Full name',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
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
                    validator: (v) {
                      if (v == null || v.length < 8) return 'Min 8 characters';
                      if (!v.contains(RegExp(r'[A-Z]')))
                        return 'Add an uppercase letter';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '8+ characters with a number and uppercase letter',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  ClareonButton(
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                    label: 'Create Account',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?',
                          style: theme.textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}