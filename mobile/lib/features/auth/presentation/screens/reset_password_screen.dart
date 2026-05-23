import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordCtrl = TextEditingController();

  String get _otp => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _otpControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _passwordCtrl.dispose();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter reset code',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('We sent a 6-digit code to ${widget.email}',
                    style: TextStyle(color: Colors.grey[500])),
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
                      controller: _otpControllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
                        if (val.isEmpty && i > 0) _focusNodes[i - 1].requestFocus();
                      },
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  )),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _passwordCtrl,
                  label: 'New Password',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Min 8 characters';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}