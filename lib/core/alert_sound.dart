import 'package:oons/core/alert_sound_stub.dart'
    if (dart.library.html) 'package:oons/core/alert_sound_web.dart' as impl;

/// Soft two-note Oons chime played when an in-app alert arrives.
Future<void> playOonsAlertSound() => impl.playOonsAlertSound();

/// Prime the browser audio context after a user gesture so later alerts can sound.
Future<void> unlockOonsAlertSound() => impl.unlockOonsAlertSound();
