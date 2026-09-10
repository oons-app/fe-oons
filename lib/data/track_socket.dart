import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oons/data/api.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TrackFix {
  const TrackFix({required this.lat, required this.lng, this.at, this.status, this.hello = false});
  final double lat;
  final double lng;
  final DateTime? at;
  final String? status;
  final bool hello;
}

String trackWsUrl(String bookingId, String token, {String? host}) {
  final raw = host ?? apiHost();
  Uri http;
  if (raw.isEmpty) {
    http = kIsWeb ? Uri.base : Uri.parse('http://127.0.0.1:8088');
  } else {
    http = Uri.parse(raw);
  }
  final scheme = http.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: scheme,
    host: http.host,
    port: http.hasPort ? http.port : null,
    path: '/api/v1/bookings/$bookingId/track',
    queryParameters: {'access': token},
  ).toString();
}

class TrackSocket {
  TrackSocket({required this.bookingId, required this.token, required this.onFix});
  final String bookingId;
  final String token;
  final void Function(TrackFix fix) onFix;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _alive = false;
  bool _open = false;
  int _attempt = 0;

  bool get connected => _open;

  void start() {
    _alive = true;
    _connect();
  }

  void sendPing(double lat, double lng) {
    if (!_open) return;
    try {
      _ch?.sink.add(jsonEncode({'type': 'ping', 'lat': lat, 'lng': lng}));
    } catch (_) {}
  }

  void stop() {
    _alive = false;
    _retry?.cancel();
    _retry = null;
    _open = false;
    _sub?.cancel();
    _sub = null;
    _ch?.sink.close();
    _ch = null;
  }

  void _connect() {
    if (!_alive) return;
    _sub?.cancel();
    try {
      _ch?.sink.close();
    } catch (_) {}
    final ch = WebSocketChannel.connect(Uri.parse(trackWsUrl(bookingId, token)));
    _ch = ch;
    _sub = ch.stream.listen(
      (raw) {
        _attempt = 0;
        _open = true;
        if (raw is! String) return;
        try {
          final m = jsonDecode(raw);
          if (m is! Map) return;
          final type = '${m['type'] ?? ''}';
          final lat = (m['lat'] as num?)?.toDouble() ?? 0;
          final lng = (m['lng'] as num?)?.toDouble() ?? 0;
          if (type != 'location' && type != 'hello') return;
          if (lat == 0 && lng == 0 && type != 'hello') return;
          onFix(TrackFix(
            lat: lat,
            lng: lng,
            at: DateTime.tryParse('${m['at'] ?? ''}'),
            status: m['status'] as String?,
            hello: type == 'hello',
          ));
        } catch (_) {}
      },
      onDone: _scheduleRetry,
      onError: (_) => _scheduleRetry(),
    );
  }

  void _scheduleRetry() {
    _open = false;
    if (!_alive) return;
    _attempt = (_attempt + 1).clamp(1, 6);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _attempt * 2), _connect);
  }
}
