import 'package:oons/core/screen_guard_stub.dart'
    if (dart.library.io) 'package:oons/core/screen_guard_io.dart' as impl;

/// Best-effort screenshot / screen-recording protection (mobile only).
Future<void> enableScreenGuard() => impl.enableScreenGuard();
