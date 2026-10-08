import 'package:flutter/foundation.dart';
import 'package:oons/data/device_os.dart' if (dart.library.io) 'package:oons/data/device_os_io.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<Map<String, String>>? _cached;

/// Headers stored on the customer's last-seen row. No push token.
Future<Map<String, String>> clientDeviceHeaders() => _cached ??= _load();

Future<Map<String, String>> _load() async {
  var version = '';
  var build = '';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    build = info.buildNumber;
  } catch (_) {}
  final platform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => '',
        };
  return {
    'X-Device-Platform': platform,
    'X-Device-OS': deviceOsLabel(),
    'X-App-Version': version,
    'X-App-Build': build,
  };
}
