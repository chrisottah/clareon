// lib/features/auth/presentation/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/shared_ui.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
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
    _emailCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_emailCtrl.text.contains('@')) return;
    final success = await ref
        .read(authProvider.notifier)
        .forgotPassword(_emailCtrl.text.trim());
    if (success && mounted) {
      context.push('/reset-password', extra: _emailCtrl.text.trim());
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF2563EB).withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.lock_reset_outlined,
                      color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(height: 24),
                Text('Reset password', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  "Enter your email and we'll send you a reset code.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (state.successMessage != null)
                  SuccessBanner(message: state.successMessage!),
                if (state.errorMessage != null)
                  ErrorBanner(message: state.errorMessage!),
                AuthTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 32),
                ClareonButton(
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                  label: 'Send Reset Code',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}