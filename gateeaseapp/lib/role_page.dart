import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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

  static const _mentorPaths = {
    '/MntrHome',
    '/VerifyStudentMentor',
    '/MentorProfileUpdate',
    '/MentorApprovedPasses',
    '/MentorPendingPasses',
    '/MentorAnalytics',
    '/MentorGroupPassCreate',
    '/Logout',
  };

  static const _publicPaths = {
    'verification-pending': '/StudentVerificationPending',
    'verification-rejected': '/StudentVerificationRejected',
  };

  static const _destinations = {
    'students': '/VerifyStudentMentor',
    'profile': '/MentorProfileUpdate',
    'approved-passes': '/MentorApprovedPasses',
    'analytics': '/MentorAnalytics',
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
    final publicPath = _publicPaths[widget.page];
    final entry = Uri.parse(
      baseurl,
    ).resolve(publicPath ?? '/api/role-page/${widget.page}/');
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      await launchUrl(
        Uri.parse(baseurl).resolve(publicPath ?? _destinations[widget.page]!),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) Navigator.maybePop(context);
      return;
    }

    try {
      final headers = publicPath == null
          ? await rolePageAuthorization()
          : <String, String>{};
      if (!mounted) return;
      if (publicPath == null && headers.isEmpty) {
        _showError('Sign in again to open this page.');
        return;
      }

      await WebViewCookieManager().clearCookies();
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _navigate,
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _showError('Unable to load this page. Try again.');
            }
          },
        ),
      );
      final platform = controller.platform;
      if (publicPath == null && platform is AndroidWebViewController) {
        await platform.setOnShowFileSelector((_) async {
          final page = Uri.tryParse(await controller.currentUrl() ?? '');
          if (page == null ||
              !isGateEaseOrigin(page) ||
              !(_mentorPaths.contains(page.path) ||
                  page.path.startsWith('/EditStudent/'))) {
            return [];
          }
          try {
            final image = await ImagePicker().pickImage(
              source: ImageSource.gallery,
            );
            return image == null ? [] : [Uri.file(image.path).toString()];
          } catch (_) {
            return [];
          }
        });
      }
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(entry, headers: headers);
    } catch (_) {
      _showError('Unable to open this page. Try again.');
    }
  }

  NavigationDecision _navigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null || !isGateEaseOrigin(uri)) {
      return NavigationDecision.prevent;
    }
    if (_publicPaths[widget.page] case final path?) {
      return uri.path == path
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    if (uri.path == '/MentorAnalyticsExportCSV') {
      _exportCsv();
      return NavigationDecision.prevent;
    }
    if (uri.path == '/login/' || uri.path == '/') {
      _showError(
        'This page is signed out. Go back and sign in again if needed.',
      );
      return NavigationDecision.prevent;
    }
    return uri.path == '/api/role-page/${widget.page}/' ||
            _mentorPaths.contains(uri.path) ||
            (uri.path.startsWith('/EditStudent/') ||
                uri.path.startsWith('/AcceptStudent/') ||
                uri.path.startsWith('/RejectStudent/') ||
                uri.path.startsWith('/UploadImage/'))
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  Future<void> _exportCsv() async {
    try {
      final response = await dio.get<Uint8List>(
        '/api/mentor/analytics.csv',
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      final data = response.data;
      if (data == null || data.isEmpty) throw StateError('Empty CSV');
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(data, mimeType: 'text/csv')],
          fileNameOverrides: ['mentor_analytics_report.csv'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export the CSV. Try again.')),
        );
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _loading = false;
      });
    }
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
