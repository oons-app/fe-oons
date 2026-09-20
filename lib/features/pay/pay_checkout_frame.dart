import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oons/features/pay/pay_iframe_stub.dart'
    if (dart.library.html) 'package:oons/features/pay/pay_iframe_web.dart' as pay_iframe;
import 'package:oons/features/pay/pay_native_stub.dart'
    if (dart.library.io) 'package:oons/features/pay/pay_native_webview.dart' as pay_native;

/// Paymob checkout stays inside the app: web iframe, native in-app WebView.
class PayCheckoutFrame extends StatelessWidget {
  const PayCheckoutFrame({
    super.key,
    required this.url,
    required this.lang,
    this.onReturned,
  });

  final String url;
  final String lang;
  final VoidCallback? onReturned;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return pay_iframe.buildPayIframe(url);
    }
    return pay_native.buildPayWebView(url: url, onReturned: onReturned);
  }
}
