import 'package:flutter/services.dart';

const _channel = MethodChannel('oons/alert_sound');

Future<void> playOonsAlertSound() async {
  try {
    await _channel.invokeMethod<void>('play');
  } catch (_) {}
}

Future<void> unlockOonsAlertSound() async {
  try {
    await _channel.invokeMethod<void>('unlock');
  } catch (_) {}
}
