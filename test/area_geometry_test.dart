import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/admin_v2/features/areas/area_geometry.dart';

void main() {
  // Rehab-ish box, drawn as four taps.
  const box = [
    LatLng(30.05, 31.47),
    LatLng(30.05, 31.49),
    LatLng(30.08, 31.49),
    LatLng(30.08, 31.47),
  ];

  test('a drawn ring encodes as the closed [lng, lat] Polygon the server validates', () {
    final g = ringToGeoJson(box)!;
    expect(g['type'], 'Polygon');
    final ring = (g['coordinates'] as List).single as List;
    expect(ring.length, 5, reason: '4 vertices + closing point');
    expect(ring.first, [31.47, 30.05], reason: 'GeoJSON is [lng, lat]');
    expect(ring.last, ring.first);
  });

  test('encode → decode gives back the same open ring', () {
    final back = ringFromGeoJson(ringToGeoJson(box))!;
    expect(back.ring, box);
    expect(back.holes, isFalse);
  });

  test('fewer than 3 points is circle-only, not a polygon', () {
    expect(ringToGeoJson(box.sublist(0, 2)), isNull);
    expect(ringToGeoJson(const []), isNull);
  });

  test('pasted GeoJSON: holes are reported, junk is rejected', () {
    final withHole = {
      'type': 'Polygon',
      'coordinates': [
        [[31.47, 30.05], [31.49, 30.05], [31.49, 30.08], [31.47, 30.08], [31.47, 30.05]],
        [[31.475, 30.06], [31.48, 30.06], [31.48, 30.07], [31.475, 30.06]],
      ],
    };
    expect(ringFromGeoJson(withHole)!.holes, isTrue);
    expect(ringFromGeoJson({'type': 'Point', 'coordinates': [31.4, 30.0]}), isNull);
    expect(ringFromGeoJson({'type': 'Polygon', 'coordinates': [[[31.4, 30.0], [31.5, 30.0]]]}), isNull);
    expect(ringFromGeoJson({'type': 'Polygon', 'coordinates': [[[200, 30.0], [31.5, 30.0], [31.5, 30.1], [200, 30.0]]]}), isNull);
    expect(ringFromGeoJson('not json'), isNull);
  });

  test('ringProblem: ok box, too few points, flat line, bow-tie', () {
    expect(ringProblem(box, ar: false), isNull);
    expect(ringProblem(box.sublist(0, 2), ar: false), contains('at least 3'));
    expect(ringProblem(const [LatLng(30, 31), LatLng(30, 31.1), LatLng(30, 31.2)], ar: false), contains('no area'));
    // Swap two corners: edges cross.
    final bowTie = [box[0], box[2], box[1], box[3]];
    expect(ringSelfIntersects(bowTie), isTrue);
    expect(ringProblem(bowTie, ar: true), contains('بتقطع'));
    expect(ringSelfIntersects(box), isFalse);
  });
}
