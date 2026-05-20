import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _tokenCtrl = TextEditingController();

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    final success = await ref
        .read(authProvider.notifier)
        .verifyEmail(_tokenCtrl.text.trim());
    if (success && mounted) context.go('/login');
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
                "We've sent a verification token to your email address. Paste it below.",
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

              if (state.successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(state.successMessage!,
                      style: const TextStyle(color: Color(0xFF22C55E))),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(labelText: 'Verification Token'),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Verify Email'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
