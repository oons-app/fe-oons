import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/models.dart';
import 'package:oons/l10n/copy.dart';

class VisitMap extends StatefulWidget {
  const VisitMap({super.key, required this.booking, required this.lang});
  final Booking booking;
  final String lang;

  @override
  State<VisitMap> createState() => _VisitMapState();
}

class _VisitMapState extends State<VisitMap> {
  final map = MapController();
  bool ready = false;

  LatLng get dest {
    final addr = widget.booking.address;
    return LatLng(
      (addr?.lat ?? 0) == 0 ? 30.0444 : addr!.lat,
      (addr?.lng ?? 0) == 0 ? 31.2357 : addr!.lng,
    );
  }

  bool get hasPing {
    final lat = widget.booking.lastLat;
    final lng = widget.booking.lastLng;
    return lat != null && lng != null && lat != 0;
  }

  LatLng get here => hasPing ? LatLng(widget.booking.lastLat!, widget.booking.lastLng!) : dest;

  @override
  void didUpdateWidget(VisitMap old) {
    super.didUpdateWidget(old);
    final moved = old.booking.lastLat != widget.booking.lastLat || old.booking.lastLng != widget.booking.lastLng;
    if (ready && hasPing && moved) {
      try {
        map.move(here, map.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Copy.of(widget.lang)['profile'] as Map;
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: here,
              initialZoom: 14,
              onMapReady: () => ready = true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'oons',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: dest,
                    width: 28,
                    height: 28,
                    child: Container(decoration: BoxDecoration(color: T.trust, border: Border.all(color: T.ink, width: T.rule))),
                  ),
                  if (hasPing)
                    Marker(
                      point: here,
                      width: 28,
                      height: 28,
                      child: Container(decoration: BoxDecoration(color: T.action, border: Border.all(color: T.ink, width: T.rule))),
                    ),
                ],
              ),
            ],
          ),
          if (!hasPing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: T.ink,
                padding: const EdgeInsets.all(8),
                child: Text('${p['trackOff']}', style: const TextStyle(color: T.white, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}
