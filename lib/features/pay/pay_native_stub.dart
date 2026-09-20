import 'package:flutter/material.dart';
import 'package:oons/features/client/client_chrome.dart';

Widget buildPayWebView({
  required String url,
  VoidCallback? onReturned,
}) {
  return Container(
    color: Client.card,
    alignment: Alignment.center,
    child: const Text('Checkout unavailable on this platform.', style: TextStyle(color: Client.muted)),
  );
}
