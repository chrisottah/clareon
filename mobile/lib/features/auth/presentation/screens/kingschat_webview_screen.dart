import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../../../../core/config/app_config.dart';

class KingsChatWebViewScreen extends ConsumerStatefulWidget {
  const KingsChatWebViewScreen({super.key});

  @override
  ConsumerState<KingsChatWebViewScreen> createState() =>
      _KingsChatWebViewScreenState();
}

class _KingsChatWebViewScreenState
    extends ConsumerState<KingsChatWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  String get _redirectUri => '${AppConfig.baseUrl}/auth/kingschat/callback';

  static const String _clientId = 'com.kingschat';

  String get _loginUrl =>
      'https://accounts.kingsch.at/?client_id=$_clientId'
      '&scopes=["conference_calls"]'
      '&post_redirect=true'
      '&redirect_uri=$_redirectUri';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.navigate;

          if (uri.scheme == 'clareon' && uri.host == 'callback') {
            final accessToken = uri.queryParameters['accessToken'];
            final refreshToken = uri.queryParameters['refreshToken'];

            if (accessToken != null && accessToken.isNotEmpty) {
              _authenticate(accessToken, refreshToken);
            } else {
              _showError('Login failed: no token received from KingsChat.');
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_loginUrl));
  }

  Future<void> _authenticate(String accessToken, String? refreshToken) async {
    setState(() => _isLoading = true);

    final success = await ref
        .read(authProvider.notifier)
        .loginWithKingsChat(accessToken, refreshToken);

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      _showError('Login failed. Please try again.');
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFEF4444)),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login with KingsChat'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading || state.status == AuthStatus.loading)
            const Center(child: CircularProgressIndicator()),
          if (state.errorMessage != null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}