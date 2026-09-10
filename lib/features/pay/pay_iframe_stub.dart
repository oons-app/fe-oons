import 'package:flutter/material.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Non-web stub — never used when kIsWeb is true.
Widget buildPayIframe(String url) {
  return Container(
    color: Client.card,
    alignment: Alignment.center,
    child: Text('Checkout unavailable on this platform.', style: TextStyle(color: Client.muted)),
  );
}
