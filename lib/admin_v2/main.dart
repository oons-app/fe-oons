import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:oons/admin_v2/app.dart';
import 'package:oons/core/analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  await Hive.initFlutter();
  await Hive.openBox('prefs');
  await Hive.openBox('cache');
  await AppAnalytics.init(forceSurface: AnalyticsSurface.admin);
  runApp(const ProviderScope(child: OpsConsoleV2App()));
}
