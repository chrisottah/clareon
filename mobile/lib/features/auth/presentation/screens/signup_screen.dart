import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).signup(
          _emailCtrl.text.trim(),
          _nameCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (success && mounted) context.push('/verify-email');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Get started',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Create your Clareon account',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                const SizedBox(height: 32),

                if (state.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                    ),
                    child: Text(state.errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444))),
                  ),
                  const SizedBox(height: 16),
                ],

                AuthTextField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Min 8 characters';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Add an uppercase letter';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Add a number';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text('Must be 8+ characters with a number and uppercase letter',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
