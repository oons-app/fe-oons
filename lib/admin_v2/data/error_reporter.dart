import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:oons/admin_v2/data/staff_client.dart';

/// Best-effort crash sink for the Ops Console. Chains the existing
/// `FlutterError.onError` / `PlatformDispatcher.onError` handlers and POSTs a
/// clipped report to `/admin/client-error` (staff-authenticated, log-only on the
/// server). No-ops when nobody is signed in. Install once at app start.
class OpsErrorReporter {
  static bool _installed = false;
  static final Set<int> _recent = {};

  static void install() {
    if (_installed) return;
    _installed = true;

    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      priorFlutterOnError?.call(details);
      _report('flutter', details.exceptionAsString(), details.stack?.toString());
    };

    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _report('zone', error.toString(), stack.toString());
      return priorPlatformOnError?.call(error, stack) ?? false;
    };
  }

  static void _report(String kind, String message, String? stack) {
    if (staffClient.readToken() == null) return;
    // Collapse duplicate spam (e.g. a failing build firing every frame).
    final key = Object.hash(kind, message);
    if (!_recent.add(key)) return;
    Timer(const Duration(seconds: 20), () => _recent.remove(key));

    unawaited(staffClient.post('/admin/client-error', data: {
      'kind': kind,
      'message': message,
      if (stack != null) 'stack': stack,
      'route': Uri.base.fragment.isNotEmpty ? Uri.base.fragment : Uri.base.path,
    }).catchError((_) => <String, dynamic>{}));
  }
}
