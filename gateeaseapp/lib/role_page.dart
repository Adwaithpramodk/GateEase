import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RolePage extends StatefulWidget {
  const RolePage({super.key, required this.title, required this.page});

  final String title;
  final String page;

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  WebViewController? _controller;
  String? _error;
  bool _loading = true;

  static const _publicPaths = {
    'verification-pending': '/StudentVerificationPending',
    'verification-rejected': '/StudentVerificationRejected',
  };

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final path = _publicPaths[widget.page];
    if (path == null) {
      _showError();
      return;
    }
    final entry = Uri.parse(baseurl).resolve(path);
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        final opened = await launchUrl(
          entry,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (opened) {
          Navigator.maybePop(context);
        } else {
          _showError();
        }
        return;
      }

      await WebViewCookieManager().clearCookies();
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null && isGateEaseOrigin(uri) && uri.path == path
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _showError();
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(entry);
    } catch (_) {
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    setState(() {
      _error = 'Unable to open this page. Try again.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _open, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (controller != null) WebViewWidget(controller: controller),
                  if (_loading)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
      ),
    );
  }
}
