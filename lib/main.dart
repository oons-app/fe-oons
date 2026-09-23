import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oons/app/app.dart';
import 'package:oons/app/web_host.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/screen_guard.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/service_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(PathUrlStrategy());
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('cache'),
    Hive.openBox('prefs'),
  ]);
  // Custom domains need the slug before the first route. lady.oons.app does not.
  if (kIsWeb && isCustomBookingHost(Uri.base.host)) {
    await _resolveCustomBookingHost();
  }
  // Paint the real app immediately. Ads were staring at the HTML splash while
  // analytics, date tables, and /areas ran in front of runApp.
  runApp(const ProviderScope(child: OonsApp()));
  unawaited(_afterFirstPaint());
}

Future<void> _afterFirstPaint() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Future.wait([
    initializeDateFormatting('ar'),
    initializeDateFormatting('en'),
  ]);
  if (!kIsWeb || !isCustomBookingHost(Uri.base.host)) {
    await _resolveCustomBookingHost();
  }
  await enableScreenGuard();
  await AppAnalytics.init();
  await refreshServiceCities(activeOnly: true);
}

Future<void> _resolveCustomBookingHost() async {
  if (!kIsWeb) return;
  final host = Uri.base.host;
  if (!isCustomBookingHost(host)) {
    await Hive.box('prefs').delete('custom_host_slug');
    await Hive.box('prefs').delete('custom_host_name');
    return;
  }
  try {
    final r = await api.get('/public/resolve-host', query: {'host': host});
    final slug = '${r['slug'] ?? ''}'.trim();
    if (slug.isNotEmpty) {
      await Hive.box('prefs').put('custom_host_slug', slug);
      await Hive.box('prefs').put('custom_host_name', host);
    }
  } catch (_) {
    // Leave uncached; user may see normal app shell until DNS/verify is ready.
  }
}

