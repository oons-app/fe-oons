import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/services.dart';

html.AudioElement? _el;
bool _unlocked = false;
String? _src;
Future<void>? _load;

Future<void> unlockOonsAlertSound() async {
  if (_unlocked) return;
  try {
    await _ensureEl();
    final a = _el;
    if (a == null) return;
    a.muted = true;
    await a.play();
    a.pause();
    a.muted = false;
    a.currentTime = 0;
    _unlocked = true;
  } catch (_) {}
}

Future<void> playOonsAlertSound() async {
  try {
    await _ensureEl();
    final a = _el;
    if (a == null) return;
    a.currentTime = 0;
    a.volume = 0.85;
    a.muted = false;
    await a.play();
  } catch (_) {}
}

Future<void> _ensureEl() {
  return _load ??= () async {
    final data = await rootBundle.load('assets/sounds/oons_alert.wav');
    final bytes = data.buffer.asUint8List();
    final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], 'audio/wav');
    _src = html.Url.createObjectUrlFromBlob(blob);
    _el = html.AudioElement()
      ..src = _src!
      ..preload = 'auto';
  }();
}
