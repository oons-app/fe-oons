import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:oons/features/client/client_chrome.dart';

Future<void> enableScreenGuard() async {
  try {
    // Covers the app-switcher snapshot with a plain background instead of
    // whatever screen was showing — not a recording block, just avoids a
    // sensitive-content flash in the OS's task-switcher thumbnail.
    await ScreenProtector.protectDataLeakageWithColor(Client.bg);
    // preventScreenshotOn() also blocks screen recording, which stops
    // screenshots for the App Store listing and the demo recording App
    // Review asks for — removed for that reason.
  } catch (_) {
    // Plugin may be unavailable on desktop/unsupported targets.
  }
}
