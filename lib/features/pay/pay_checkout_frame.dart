import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/pay/pay_iframe_stub.dart'
    if (dart.library.html) 'package:oons/features/pay/pay_iframe_web.dart' as pay_iframe;

/// In-app Paymob checkout frame (web iframe; native opens external browser).
class PayCheckoutFrame extends StatelessWidget {
  const PayCheckoutFrame({
    super.key,
    required this.url,
    required this.lang,
  });

  final String url;
  final String lang;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return pay_iframe.buildPayIframe(url);
    }
    return _NativeCheckoutFallback(url: url, lang: lang);
  }
}

class _NativeCheckoutFallback extends StatelessWidget {
  const _NativeCheckoutFallback({required this.url, required this.lang});
  final String url;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Client.card,
        border: Border.all(color: Client.ink, width: Client.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'ar' ? 'كمّلي الدفع في نافذة بايموب' : 'Finish payment in the Paymob window',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Client.ink),
          ),
          const SizedBox(height: 8),
          Text(
            lang == 'ar'
                ? 'هتفتح صفحة الدفع الآمنة. بعد ما تخلصي، ارجعي للتطبيق.'
                : 'A secure checkout page will open. Come back here when you are done.',
            style: const TextStyle(fontSize: 13, height: 1.45, color: Client.body),
          ),
          const SizedBox(height: 16),
          ClientPrimaryButton(
            label: lang == 'ar' ? 'افتحي صفحة الدفع' : 'Open payment page',
            onTap: () => openExternal(url),
          ),
        ],
      ),
    );
  }
}
