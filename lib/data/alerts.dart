import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/l10n/alert_copy.dart';

class AlertToast {
  const AlertToast({required this.title, required this.body, this.bookingId});
  final String title;
  final String body;
  final String? bookingId;
}

class InboxAlert {
  const InboxAlert({
    required this.id,
    required this.title,
    required this.body,
    this.type = '',
    this.bookingId,
    this.at,
  });
  final String id;
  final String type;
  final String title;
  final String body;
  final String? bookingId;
  final DateTime? at;

  factory InboxAlert.fromMap(Map m) {
    DateTime? at;
    final raw = m['at'];
    if (raw is String) at = DateTime.tryParse(raw);
    final bid = m['bookingId']?.toString();
    return InboxAlert(
      id: '${m['id'] ?? ''}',
      type: '${m['type'] ?? ''}',
      title: '${m['title'] ?? ''}',
      body: '${m['body'] ?? ''}',
      bookingId: (bid == null || bid.isEmpty || bid == 'null') ? null : bid,
      at: at,
    );
  }

  (String title, String body) localized(String lang, {required bool provider}) {
    return AlertCopy.of(
      type,
      lang: lang,
      party: provider ? 'provider' : 'client',
      fallbackTitle: title,
      fallbackBody: body,
    );
  }
}

final alertToastProvider = StateProvider<AlertToast?>((ref) => null);

class AlertInbox extends StateNotifier<List<InboxAlert>> {
  AlertInbox() : super(const []);

  void clear() => state = const [];

  /// Replaces the inbox with [incoming] merged onto the current list.
  /// Returns rows that were not in the previous list (by id).
  List<InboxAlert> apply(List<InboxAlert> incoming) {
    final prev = state;
    final next = mergeInbox(prev, incoming);
    state = next;
    return freshAlerts(prev, next);
  }

  void upsert(InboxAlert row) => apply([row]);
}

final alertInboxProvider = StateNotifierProvider<AlertInbox, List<InboxAlert>>((ref) => AlertInbox());

List<InboxAlert> mergeInbox(List<InboxAlert> current, List<InboxAlert> incoming) {
  final map = <String, InboxAlert>{};
  void put(InboxAlert r) {
    final k = r.id.isNotEmpty ? r.id : '${r.title}|${r.body}|${r.at?.millisecondsSinceEpoch ?? 0}';
    map[k] = r;
  }

  for (final r in current) {
    put(r);
  }
  for (final r in incoming) {
    put(r);
  }
  final out = map.values.toList()
    ..sort((a, b) {
      final at = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
  if (out.length <= 50) return out;
  return out.sublist(0, 50);
}

List<InboxAlert> freshAlerts(List<InboxAlert> prev, List<InboxAlert> next) {
  final seen = {for (final r in prev) if (r.id.isNotEmpty) r.id};
  return next.where((r) => r.id.isNotEmpty && !seen.contains(r.id)).toList();
}

void openAlertVisit(BuildContext context, WidgetRef ref, String? bookingId) {
  if (bookingId == null || bookingId.isEmpty) return;
  final path = ref.read(sessionProvider).isProvider ? '/pro/job/$bookingId' : '/visit/$bookingId';
  context.push(path);
}

final pushControllerProvider = Provider<PushController>((ref) {
  final c = PushController(ref);
  ref.onDispose(c.dispose);
  return c;
});

class PushController {
  PushController(this._ref);
  final Ref _ref;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _channel = const MethodChannel('oons/push');
  StreamSubscription<String>? _sse;
  http.Client? _http;
  Timer? _poll;
  Timer? _hideToast;
  bool _ready = false;
  bool _firstPoll = true;
  bool _alive = false;
  int _n = 0;
  final _toasted = <String>{};

  bool _sseLive = false;
  bool _polling = false;

  Future<void> start() async {
    stop();
    _alive = true;
    await _initLocal();
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'token' && call.arguments is String) {
          await _registerToken(call.arguments as String);
        }
      });
      final existing = await _channel.invokeMethod<String>('getToken');
      if (existing != null && existing.isNotEmpty) await _registerToken(existing);
    } catch (_) {}
    _firstPoll = true;
    await _pollInbox();
    // SSE carries live alerts; HTTP poll is a slow backup (was 4s and made the lab feel laggy).
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => unawaited(_pollInbox()));
    unawaited(_listenSse());
  }

  void stop() {
    _alive = false;
    _stopSse();
    _poll?.cancel();
    _poll = null;
    _hideToast?.cancel();
    _hideToast = null;
    _toasted.clear();
    _firstPoll = true;
    _ref.read(alertInboxProvider.notifier).clear();
    _ref.read(alertToastProvider.notifier).state = null;
  }

  void dispose() => stop();

  void _stopSse() {
    _sseLive = false;
    _sse?.cancel();
    _sse = null;
    _http?.close();
    _http = null;
  }

  Future<void> _initLocal() async {
    if (_ready || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  Future<void> _registerToken(String token) async {
    if (token.isEmpty) return;
    try {
      await api.post('/me/devices', data: {
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'token': token,
      });
    } catch (_) {}
  }

  Future<void> _pollInbox() async {
    if (!_alive || _polling || _ref.read(sessionProvider).token == null) return;
    // When SSE is healthy, skip the backup poll to keep the radio quiet on high-latency links.
    if (_sseLive && !_firstPoll) return;
    _polling = true;
    try {
      final r = await api.get('/me/alerts');
      final raw = r['alerts'];
      if (raw is! List) return;
      final rows = raw.whereType<Map>().map((m) => InboxAlert.fromMap(Map<String, dynamic>.from(m))).toList();
      final fresh = _ref.read(alertInboxProvider.notifier).apply(rows);
      if (_firstPoll) {
        _firstPoll = false;
        return;
      }
      for (final a in fresh.reversed) {
        _present(a, sound: true);
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void _retrySse(Duration wait) {
    Future<void>.delayed(wait, () {
      if (_alive) unawaited(_listenSse());
    });
  }

  Future<void> _listenSse() async {
    _stopSse();
    if (!_alive) return;
    final token = _ref.read(sessionProvider).token;
    if (token == null) return;
    final uri = Uri.parse('${apiHost()}/api/v1/me/events');
    _http = http.Client();
    try {
      final req = http.Request('GET', uri);
      req.headers['Authorization'] = 'Bearer $token';
      req.headers['Accept'] = 'text/event-stream';
      // Avoid Cache-Control on the request — browsers preflight it and some
      // proxies strip SSE; Accept is enough for event-stream negotiation.
      final res = await _http!.send(req);
      if (res.statusCode != 200) {
        _sseLive = false;
        _retrySse(const Duration(seconds: 4));
        return;
      }
      _sseLive = true;
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
      }, onError: (_) {
        _sseLive = false;
        _retrySse(const Duration(seconds: 3));
      }, onDone: () {
        _sseLive = false;
        _retrySse(const Duration(seconds: 3));
      });
    } catch (_) {
      _sseLive = false;
      _retrySse(const Duration(seconds: 4));
    }
  }

  void _onFrame(String frame) {
    for (final line in frame.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final raw = line.substring(5).trim();
      if (raw.isEmpty) continue;
      try {
        final m = jsonDecode(raw);
        if (m is! Map) continue;
        final row = InboxAlert.fromMap(Map<String, dynamic>.from(m));
        if (row.title.isEmpty && row.type.isEmpty) continue;
        _ref.read(alertInboxProvider.notifier).upsert(row);
        _present(row, sound: true);
      } catch (_) {}
    }
  }

  void _present(InboxAlert row, {required bool sound}) {
    if (row.id.isNotEmpty && !_toasted.add(row.id)) return;
    final lang = _ref.read(localeProvider).languageCode;
    final loc = row.localized(lang, provider: _ref.read(sessionProvider).isProvider);
    _ref.read(alertToastProvider.notifier).state = AlertToast(title: loc.$1, body: loc.$2, bookingId: row.bookingId);
    _hideToast?.cancel();
    _hideToast = Timer(const Duration(seconds: 6), () {
      _ref.read(alertToastProvider.notifier).state = null;
    });
    if (sound) unawaited(_sound(loc.$1, loc.$2));
  }

  Future<void> _sound(String title, String body) async {
    if (kIsWeb) return;
    try {
      await _plugin.show(
        _n++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails('oons', 'oons', importance: Importance.high, playSound: true, icon: '@mipmap/ic_launcher'),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, sound: 'default'),
        ),
      );
    } catch (_) {}
  }
}
