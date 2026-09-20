import 'package:flutter/material.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/pay/pay_return.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Widget buildPayWebView({
  required String url,
  VoidCallback? onReturned,
}) {
  return _PayNativeWebView(url: url, onReturned: onReturned);
}

class _PayNativeWebView extends StatefulWidget {
  const _PayNativeWebView({required this.url, this.onReturned});
  final String url;
  final VoidCallback? onReturned;

  @override
  State<_PayNativeWebView> createState() => _PayNativeWebViewState();
}

class _PayNativeWebViewState extends State<_PayNativeWebView> {
  late final WebViewController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Client.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            if (isPayReturnUrl(req.url)) {
              widget.onReturned?.call();
              return NavigationDecision.prevent;
            }
            // Keep 3DS / wallet HTTPS pages inside this WebView — never Chrome.
            if (req.url.startsWith('http://') || req.url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            if (isPayReturnUrl(req.url)) {
              widget.onReturned?.call();
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            if (isPayReturnUrl(url)) widget.onReturned?.call();
          },
          onWebResourceError: (_) {},
        ),
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setOnPlatformPermissionRequest((request) => request.grant());
    }
    _controller = controller;
    _controller.loadRequest(Uri.parse(widget.url)).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void didUpdateWidget(covariant _PayNativeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Client.card,
        border: Border.all(color: Client.ink, width: Client.rule),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (!_ready)
            const ColoredBox(
              color: Client.bg,
              child: Center(child: CircularProgressIndicator(color: Client.plum)),
            ),
        ],
      ),
    );
  }
}
