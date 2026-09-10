class GeoHit {
  const GeoHit({required this.label, required this.line, required this.lat, required this.lng});
  final String label;
  final String line;
  final double lat;
  final double lng;

  factory GeoHit.fromJson(Map j) => GeoHit(
        label: '${j['label'] ?? ''}',
        line: '${j['line'] ?? j['label'] ?? ''}',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );
}
