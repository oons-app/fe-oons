import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/tokens.dart';

class DeliveryPinMap extends StatefulWidget {
  const DeliveryPinMap({
    super.key,
    required this.lat,
    required this.lng,
    required this.onMoved,
    this.height = 240,
  });
  final double lat;
  final double lng;
  final ValueChanged<LatLng> onMoved;
  final double height;

  @override
  State<DeliveryPinMap> createState() => DeliveryPinMapState();
}

class DeliveryPinMapState extends State<DeliveryPinMap> {
  late final MapController osm = MapController();
  late LatLng center = LatLng(widget.lat, widget.lng);

  void moveTo(double lat, double lng) {
    final p = LatLng(lat, lng);
    center = p;
    try {
      osm.move(p, 17);
    } catch (_) {}
    widget.onMoved(p);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: osm,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                minZoom: 11,
                maxZoom: 19,
                onMapEvent: (e) {
                  if (e is MapEventMoveEnd) {
                    center = e.camera.center;
                    widget.onMoved(center);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'oons',
                ),
              ],
            ),
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Glyph(GlyphKind.pin, size: 36, color: T.action, fill: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
