import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class ServiceCity {
  const ServiceCity({required this.id, required this.name, required this.areas});
  final String id;
  final Loc name;
  final List<String> areas;
}

/// Fallback when /areas is unreachable — live pilot corridor only.
const _fallbackCities = <ServiceCity>[
  ServiceCity(
    id: 'new_cairo',
    name: Loc('New Cairo', 'القاهرة الجديدة'),
    areas: ['madinaty', 'rehab', 'capital'],
  ),
];

List<ServiceCity> serviceCities = List<ServiceCity>.from(_fallbackCities);

const serviceDurations = [30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 480];

Set<String> allCatalogAreaIds() {
  final out = <String>{};
  for (final c in serviceCities) {
    out.addAll(c.areas);
  }
  return out;
}

String cityName(String id, String lang) {
  for (final c in serviceCities) {
    if (c.id == id) return c.name.of(lang);
  }
  return id;
}

DateTime? _areasFetchedAt;
bool _areasLoading = false;

/// Live vetted-provider counts keyed by area slug. Only populated after a
/// successful /areas response that includes [providerCount] — missing means
/// unknown, not zero, so the client must not warn on a stale catalog.
final Map<String, int> areaProviderCounts = {};
bool areaCoverageKnown = false;

int providerCountForArea(String slug) => areaProviderCounts[slug.trim().toLowerCase()] ?? 0;

bool areaCoverageIsKnown(String slug) => areaCoverageKnown && areaProviderCounts.containsKey(slug.trim().toLowerCase());

bool areaHasNoProviders(String slug) {
  final key = slug.trim().toLowerCase();
  if (key.isEmpty || !areaCoverageKnown) return false;
  return (areaProviderCounts[key] ?? 0) <= 0;
}

List<String> suggestedCoveredAreaIds({String? exclude, int limit = 3}) {
  if (!areaCoverageKnown) return const [];
  final skip = (exclude ?? '').trim().toLowerCase();
  final rows = <MapEntry<String, int>>[
    for (final e in areaProviderCounts.entries)
      if (e.value > 0 && e.key != skip) e,
  ]..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [for (final e in rows.take(limit < 1 ? 3 : limit)) e.key];
}

/// Loads live + locked areas from API. Providers/clients use [activeOnly]=true.
Future<void> refreshServiceCities({bool activeOnly = true, bool force = false}) async {
  if (_areasLoading) return;
  if (!force && _areasFetchedAt != null && DateTime.now().difference(_areasFetchedAt!) < const Duration(minutes: 5)) {
    return;
  }
  _areasLoading = true;
  try {
    final r = await api.get('/areas', query: {
      if (activeOnly) 'active': '1' else 'teaser': '1',
    });
    final rows = (r['areas'] as List?) ?? const [];
    if (rows.isEmpty) return;
    final byCity = <String, ServiceCity>{};
    final order = <String>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final slug = '${m['slug'] ?? ''}'.trim();
      if (slug.isEmpty) continue;
      // Public default is active-only; if teaser mode, skip locked for picker chips.
      final status = '${m['status'] ?? ''}';
      final active = m['active'] == true || status == 'active';
      if (activeOnly && !active) continue;
      final cityId = '${m['cityId'] ?? 'other'}'.trim();
      if (cityId.isEmpty) continue;
      final cityName = m['cityName'] is Map ? Loc.fromJson(m['cityName']) : Loc(cityId, cityId);
      final existing = byCity[cityId];
      if (existing == null) {
        order.add(cityId);
        byCity[cityId] = ServiceCity(id: cityId, name: cityName, areas: [slug]);
      } else if (!existing.areas.contains(slug)) {
        byCity[cityId] = ServiceCity(
          id: existing.id,
          name: existing.name,
          areas: [...existing.areas, slug],
        );
      }
    }
    if (byCity.isEmpty) return;
    serviceCities = [for (final id in order) byCity[id]!];
    final nextCounts = <String, int>{};
    var sawCount = false;
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final slug = '${m['slug'] ?? ''}'.trim().toLowerCase();
      if (slug.isEmpty) continue;
      if (m.containsKey('providerCount') || m.containsKey('hasProviders')) {
        sawCount = true;
        nextCounts[slug] = (m['providerCount'] as num?)?.toInt() ?? 0;
      }
    }
    if (sawCount) {
      areaProviderCounts
        ..clear()
        ..addAll(nextCounts);
      areaCoverageKnown = true;
    }
    _areasFetchedAt = DateTime.now();
  } catch (_) {
    // Keep last known / fallback catalog.
  } finally {
    _areasLoading = false;
  }
}
