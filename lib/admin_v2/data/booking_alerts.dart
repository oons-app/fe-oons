import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/core/alert_sound.dart';
import 'package:oons/data/api.dart';

/// Live "new booking" chime for the signed-in super admin.
class SuperAdminBookingAlerts extends ConsumerStatefulWidget {
  const SuperAdminBookingAlerts({super.key});

  @override
  ConsumerState<SuperAdminBookingAlerts> createState() => _SuperAdminBookingAlertsState();
}

class _SuperAdminBookingAlertsState extends ConsumerState<SuperAdminBookingAlerts> {
  http.Client? _http;
  StreamSubscription<String>? _sse;
  Timer? _retry;
  int _backoffSec = 3;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _sync() {
    final sess = ref.read(staffSessionProvider);
    if (!sess.authed || sess.staffRole != roleSuper) {
      _stop();
      return;
    }
    if (_sse != null) return;
    unawaited(_listen());
  }

  void _stop() {
    _retry?.cancel();
    _retry = null;
    _sse?.cancel();
    _sse = null;
    _http?.close();
    _http = null;
    _backoffSec = 3;
  }

  String _eventsUrl() {
    final host = apiHost();
    if (host.isEmpty) return '${Uri.base.origin}/api/v1/me/events';
    return '$host/api/v1/me/events';
  }

  Future<void> _listen() async {
    _stop();
    final token = staffClient.readToken();
    if (token == null || token.isEmpty) return;
    if (ref.read(staffSessionProvider).staffRole != roleSuper) return;
    final httpClient = http.Client();
    _http = httpClient;
    try {
      final req = http.Request('GET', Uri.parse(_eventsUrl()));
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'text/event-stream';
      req.headers['Accept-Encoding'] = 'identity';
      final res = await httpClient.send(req);
      if (!identical(_http, httpClient)) return;
      if (res.statusCode != 200) {
        _scheduleRetry();
        return;
      }
      _backoffSec = 3;
      final buf = StringBuffer();
      _sse = res.stream.transform(utf8.decoder).listen((chunk) {
        buf.write(chunk);
        var data = buf.toString();
        var idx = data.indexOf('\n\n');
        while (idx >= 0) {
          final frame = data.substring(0, idx);
          data = data.substring(idx + 2);
          _onFrame(frame);
          idx = data.indexOf('\n\n');
        }
        buf
          ..clear()
          ..write(data);
      }, onError: (_) => _scheduleRetry(), onDone: _scheduleRetry);
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _sse?.cancel();
    _sse = null;
    _http?.close();
    _http = null;
    if (ref.read(staffSessionProvider).staffRole != roleSuper) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _backoffSec), () {
      _backoffSec = (_backoffSec * 2).clamp(3, 30);
      if (mounted) unawaited(_listen());
    });
  }

  void _onFrame(String frame) {
    for (final line in frame.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final raw = line.substring(5).trim();
      if (raw.isEmpty) continue;
      try {
        final m = jsonDecode(raw);
        if (m is! Map || m['type'] != 'booking_created') continue;
        final id = '${m['bookingId'] ?? ''}';
        if (id.isNotEmpty && !_seen.add(id)) continue;
        final title = '${m['title'] ?? 'حجز جديد'}';
        final body = '${m['body'] ?? ''}'.trim();
        final path = '${m['path'] ?? ''}';
        unawaited(playOonsAlertSound());
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.clearSnackBars();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              body.isEmpty ? title : '$title\n$body',
              style: const TextStyle(color: Ops.plumText, fontSize: 13, height: 1.35),
            ),
            backgroundColor: Ops.plum,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: path.startsWith('/')
                ? SnackBarAction(
                    label: 'فتح',
                    textColor: Ops.plumText,
                    onPressed: () {
                      if (mounted) context.go(path);
                    },
                  )
                : null,
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(staffSessionProvider, (prev, next) {
      if (next.staffRole != roleSuper || !next.authed) {
        _stop();
        return;
      }
      if (prev?.token != next.token || _sse == null) unawaited(_listen());
    });
    return const SizedBox.shrink();
  }
}
