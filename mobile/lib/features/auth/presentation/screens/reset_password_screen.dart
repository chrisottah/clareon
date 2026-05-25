// lib/features/auth/presentation/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/shared_ui.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordCtrl = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  String get _otp => _otpControllers.map((c) => c.text).join();

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
    for (final c in _otpControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _otp.length < 6) return;
    final success = await ref
        .read(authProvider.notifier)
        .resetPassword(widget.email, _otp, _passwordCtrl.text);
    if (success && mounted) context.go('/login');
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
                    child: const Icon(Icons.shield_outlined,
                        color: Color(0xFF2563EB), size: 28),
                  ),
                  const SizedBox(height: 24),
                  Text('New password', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the code we sent to ${widget.email}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 36),
                  if (state.errorMessage != null)
                    ErrorBanner(message: state.errorMessage!),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (i) => OtpBox(
                        controller: _otpControllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (val) {
                          if (val.isNotEmpty && i < 5)
                            _focusNodes[i + 1].requestFocus();
                          if (val.isEmpty && i > 0)
                            _focusNodes[i - 1].requestFocus();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _passwordCtrl,
                    label: 'New password',
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
                  const SizedBox(height: 32),
                  ClareonButton(
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                    label: 'Reset Password',
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