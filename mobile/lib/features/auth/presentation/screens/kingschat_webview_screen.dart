import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';

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

  // Use a fake redirect that we'll intercept before it loads
  static const String _redirectUri = 'https://clareon.online/api/v1/auth/kingschat/callback';
  static const String _clientId = 'com.kingschat';

  String get _loginUrl =>
      'https://accounts.kingsch.at/?client_id=$_clientId'
      '&scopes=["conference_calls"]'
      '&redirect_uri=$_redirectUri';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _isLoading = true);
          // Check if this URL contains tokens
          if (url.contains('accessToken') || url.contains('access_token')) {
            _handleCallback(url);
          }
        },
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (request) {
          final url = request.url;

          // Intercept any URL with tokens before it loads
          if (url.contains('accessToken') || url.contains('access_token')) {
            _handleCallback(url);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_loginUrl));
  }

  void _handleCallback(String url) {
    final uri = Uri.parse(url);

    // Try query parameters
    String? accessToken =
        uri.queryParameters['accessToken'] ??
        uri.queryParameters['access_token'];

    // Try fragment
    if (accessToken == null && uri.fragment.isNotEmpty) {
      try {
        final fragmentUri = Uri.parse('https://dummy.com?${uri.fragment}');
        accessToken =
            fragmentUri.queryParameters['accessToken'] ??
            fragmentUri.queryParameters['access_token'];
      } catch (_) {}
    }

    // Try parsing the full URL string for token patterns
    if (accessToken == null) {
      final tokenMatch = RegExp(r'access[Tt]oken=([^&\s]+)').firstMatch(url);
      if (tokenMatch != null) {
        accessToken = Uri.decodeComponent(tokenMatch.group(1)!);
      }
    }

    if (accessToken != null) {
      _authenticate(accessToken, null);
    } else {
      // Don't show error for the redirect URI itself
      if (!url.startsWith(_redirectUri)) {
        _showError('Could not extract token. URL: ${url.length > 100 ? '${url.substring(0, 100)}...' : url}');
      }
    }
  }

  Future<void> _authenticate(
      String accessToken, String? refreshToken) async {
    final success = await ref
        .read(authProvider.notifier)
        .loginWithKingsChat(accessToken, refreshToken);
    if (success && mounted) context.go('/home');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
    ));
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