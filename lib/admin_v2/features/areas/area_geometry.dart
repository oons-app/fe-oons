import 'package:latlong2/latlong.dart';

/// GeoJSON for an area boundary, as the server stores it
/// (`models.GeoPolygon`): `{"type":"Polygon","coordinates":[[[lng,lat],…]]}`.
/// The editor keeps the outer ring open (no repeated first point) and closes
/// it only on the way out.

/// The drawn ring as a GeoJSON Polygon, or null with fewer than 3 vertices.
Map<String, dynamic>? ringToGeoJson(List<LatLng> ring) {
  if (ring.length < 3) return null;
  final coords = [for (final p in ring) [_round(p.longitude), _round(p.latitude)]];
  coords.add(List<double>.of(coords.first));
  return {
    'type': 'Polygon',
    'coordinates': [coords],
  };
}

/// The outer ring of a GeoJSON Polygon, open (closing point dropped).
/// Null when it isn't a Polygon or has fewer than 3 distinct vertices.
/// [holes] reports whether inner rings were present (the editor drops them).
({List<LatLng> ring, bool holes})? ringFromGeoJson(Object? geo) {
  if (geo is! Map || geo['type'] != 'Polygon') return null;
  final rings = geo['coordinates'];
  if (rings is! List || rings.isEmpty || rings.first is! List) return null;
  final out = <LatLng>[];
  for (final pos in rings.first as List) {
    if (pos is! List || pos.length < 2 || pos[0] is! num || pos[1] is! num) return null;
    final lng = (pos[0] as num).toDouble(), lat = (pos[1] as num).toDouble();
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    out.add(LatLng(lat, lng));
  }
  if (out.length > 1 && out.first == out.last) out.removeLast();
  if (out.length < 3) return null;
  return (ring: out, holes: rings.length > 1);
}

/// Why this ring can't be saved, or null when it can: at least 3 vertices,
/// no edges crossing (a bow-tie matches nothing sensible), and some area.
String? ringProblem(List<LatLng> ring, {required bool ar}) {
  if (ring.length < 3) {
    return ar ? 'الحدود محتاجة ٣ نقط على الأقل' : 'A boundary needs at least 3 points';
  }
  // Crossing first: a symmetric bow-tie's signed area cancels to zero, and
  // "crosses itself" is the message that says what to fix.
  if (ringSelfIntersects(ring)) {
    return ar ? 'خطوط الحدود بتقطع بعض — حرّكي النقط' : 'The boundary crosses itself — move the points';
  }
  if (_area2(ring).abs() < 1e-12) {
    return ar ? 'الحدود مالهاش مساحة' : 'The boundary has no area';
  }
  return null;
}

/// True when two non-adjacent edges of the closed ring cross. O(n²); rings
/// here are a few dozen points.
bool ringSelfIntersects(List<LatLng> ring) {
  final n = ring.length;
  if (n < 4) return false;
  for (var i = 0; i < n; i++) {
    final a1 = ring[i], a2 = ring[(i + 1) % n];
    for (var j = i + 1; j < n; j++) {
      // Adjacent edges share a vertex; skip them (including last↔first).
      if (j == i || (j + 1) % n == i || (i + 1) % n == j) continue;
      final b1 = ring[j], b2 = ring[(j + 1) % n];
      if (_segmentsCross(a1, a2, b1, b2)) return true;
    }
  }
  return false;
}

bool _segmentsCross(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
  final d1 = _cross(p3, p4, p1), d2 = _cross(p3, p4, p2);
  final d3 = _cross(p1, p2, p3), d4 = _cross(p1, p2, p4);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

double _cross(LatLng a, LatLng b, LatLng c) =>
    (b.longitude - a.longitude) * (c.latitude - a.latitude) - (b.latitude - a.latitude) * (c.longitude - a.longitude);

double _area2(List<LatLng> r) {
  var s = 0.0;
  for (var i = 0; i < r.length; i++) {
    final a = r[i], b = r[(i + 1) % r.length];
    s += a.longitude * b.latitude - b.longitude * a.latitude;
  }
  return s;
}

/// ~1 cm; keeps the stored JSON short.
double _round(double v) => (v * 1e7).roundToDouble() / 1e7;
