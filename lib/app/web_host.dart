import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Reserved platform hosts under `*.oons.app` (not provider vanity slugs).
const reservedOonsSubdomains = {
  'www',
  'api',
  'bo',
  'lady',
  'admin',
  'app',
  'mail',
  'cdn',
  'static',
  'assets',
  'legal',
  'status',
  'staging',
  'domains',
};

/// If the browser host is `{slug}.oons.app`, return that slug.
@visibleForTesting
String? providerSlugFromHost(String host) {
  final h = host.toLowerCase().split(':').first;
  if (!h.endsWith('.oons.app')) return null;
  final labels = h.split('.');
  if (labels.length != 3) return null; // slug.oons.app only
  final slug = labels.first;
  if (slug.isEmpty || reservedOonsSubdomains.contains(slug)) return null;
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(slug)) return null;
  return slug;
}

/// True when the page is served on a provider custom domain (not oons.app).
bool isCustomBookingHost(String host) {
  final h = host.toLowerCase().split(':').first;
  if (h.isEmpty || h == 'localhost' || h.endsWith('.local')) return false;
  if (h == 'oons.app' || h.endsWith('.oons.app')) return false;
  return h.contains('.');
}

/// Vanity `{slug}.oons.app` or resolved custom booking host.
String? bookingSlugForWebHost() {
  if (!kIsWeb) return null;
  final host = Uri.base.host;
  final vanity = providerSlugFromHost(host);
  if (vanity != null) return vanity;
  if (!isCustomBookingHost(host)) return null;
  final cached = Hive.box('prefs').get('custom_host_slug');
  final cachedHost = Hive.box('prefs').get('custom_host_name');
  if (cached is String && cached.isNotEmpty && cachedHost == host) return cached;
  return null;
}

/// Provider booking hosts only allow customer auth (no professional signup).
bool isCustomerOnlyAuthHost() => bookingSlugForWebHost() != null;
