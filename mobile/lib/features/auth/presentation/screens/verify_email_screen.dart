// lib/features/auth/presentation/screens/verify_email_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/shared_ui.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
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
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _submit() async {
    if (_otp.length < 6) return;
    final success = await ref
        .read(authProvider.notifier)
        .verifyEmail(widget.email, _otp);
    if (success && mounted) context.go('/login');
  }

  Future<void> _resend() async {
    await ref.read(authProvider.notifier).resendOtp(widget.email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New code sent to your email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: Color(0xFF2563EB), size: 28),
                ),
                const SizedBox(height: 24),
                Text('Check your email',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                if (state.errorMessage != null)
                  ErrorBanner(message: state.errorMessage!),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5)
                          _focusNodes[i + 1].requestFocus();
                        if (val.isEmpty && i > 0)
                          _focusNodes[i - 1].requestFocus();
                        if (_otp.length == 6) _submit();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                ClareonButton(
                  onPressed: isLoading || _otp.length < 6 ? null : _submit,
                  isLoading: isLoading,
                  label: 'Verify',
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: _resend,
                    child: const Text("Didn't receive a code? Resend"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}