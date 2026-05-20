import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(authProvider.notifier)
        .resetPassword(_tokenCtrl.text.trim(), _passwordCtrl.text);
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
                const SizedBox(height: 24),
                const Text('Set new password',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Enter the token from your email and your new password.',
                    style: TextStyle(fontSize: 15, color: Colors.grey[500])),
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

                TextFormField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(labelText: 'Reset Token'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your reset token' : null,
                ),
                const SizedBox(height: 16),
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
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
