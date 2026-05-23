import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: Color(0xFF2563EB), size: 32),
              ),
              const SizedBox(height: 24),
              const Text('Check your email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 32),

              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(state.errorMessage!,
                      style: const TextStyle(color: Color(0xFFEF4444))),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 48, height: 56,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    onChanged: (val) {
                      if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                      if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                      if (_otp.length == 6) _submit();
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                )),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading || _otp.length < 6 ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify'),
              ),
              const SizedBox(height: 16),
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
    );
  }
}