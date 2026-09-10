import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:oons/features/client/client_chrome.dart';

Future<void> enableScreenGuard() async {
  try {
    await ScreenProtector.protectDataLeakageWithColor(Client.bg);
    await ScreenProtector.preventScreenshotOn();
  } catch (_) {
    // Plugin may be unavailable on desktop/unsupported targets.
  }
}
