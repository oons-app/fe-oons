import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/buttons.dart';

/// Where an area is, as the editor sees it. [ring] is open (no repeated first
/// point); empty means "circle only".
class AreaShape {
  const AreaShape({required this.center, required this.radiusM, this.ring = const []});
  final LatLng center;
  final int radiusM;
  final List<LatLng> ring;
}

enum _Mode { centre, draw }

/// Map editor for an area: the centre pin and its circle, plus an optional
/// drawn boundary. Tap the map to move the centre (Centre mode) or add a
/// point (Draw mode); drag the pin or any point; long-press a point to delete
/// it. Same OpenStreetMap tiles as the live map.
class AreaMapEditor extends StatefulWidget {
  const AreaMapEditor({super.key, required this.shape, required this.onChanged, required this.ar, this.height = 340});
  final AreaShape shape;
  final ValueChanged<AreaShape> onChanged;
  final bool ar;
  final double height;

  @override
  State<AreaMapEditor> createState() => _AreaMapEditorState();
}

class _AreaMapEditorState extends State<AreaMapEditor> {
  late _Mode mode = widget.shape.ring.isEmpty ? _Mode.centre : _Mode.draw;
  final map = MapController();
  bool dragging = false;

  AreaShape get s => widget.shape;

  void _emit({LatLng? center, List<LatLng>? ring}) =>
      widget.onChanged(AreaShape(center: center ?? s.center, radiusM: s.radiusM, ring: ring ?? s.ring));

  void _onTap(TapPosition _, LatLng p) {
    if (mode == _Mode.centre) {
      _emit(center: p);
    } else {
      _emit(ring: [...s.ring, p]);
    }
  }

  /// Drag a marker by screen delta, without the map panning underneath.
  Widget _handle({required Widget child, required LatLng at, required ValueChanged<LatLng> onMove, VoidCallback? onLongPress}) {
    return Builder(builder: (ctx) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => dragging = true),
        onPanEnd: (_) => setState(() => dragging = false),
        onPanCancel: () => setState(() => dragging = false),
        onPanUpdate: (d) {
          final cam = MapCamera.of(ctx);
          final p = cam.latLngToScreenPoint(at);
          onMove(cam.pointToLatLng(math.Point(p.x + d.delta.dx, p.y + d.delta.dy)));
        },
        onLongPress: onLongPress,
        child: child,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.ar;
    final ring = s.ring;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _modeBtn(_Mode.centre, ar ? 'حرّكي المركز' : 'Move centre'),
          _modeBtn(_Mode.draw, ar ? 'ارسمي الحدود' : 'Draw boundary'),
          V2Btn.ghost(ar ? 'تراجعي عن نقطة' : 'Undo point',
              onPressed: ring.isEmpty ? null : () => _emit(ring: ring.sublist(0, ring.length - 1)), size: V2BtnSize.sm),
          V2Btn.ghost(ar ? 'امسحي الحدود (دايرة بس)' : 'Clear boundary → circle only',
              onPressed: ring.isEmpty ? null : () => _emit(ring: const []), size: V2BtnSize.sm),
        ]),
        const SizedBox(height: 6),
        Text(
          mode == _Mode.centre
              ? (ar ? 'دوسي على الخريطة أو اسحبي الدبوس عشان تحطي المركز.' : 'Tap the map or drag the pin to set the centre.')
              : (ar
                  ? 'دوسي لإضافة نقطة. اسحبي أي نقطة لتحريكها، وضغطة طويلة تمسحها. الحدود بتتقفل لوحدها.'
                  : 'Tap to add a point. Drag a point to move it; long-press to delete it. The shape closes itself.'),
          style: const TextStyle(fontSize: 12, color: Ops.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Ops.radiusCard),
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter: s.center,
                initialZoom: 13,
                onTap: _onTap,
                interactionOptions: InteractionOptions(
                  flags: dragging ? InteractiveFlag.all & ~InteractiveFlag.drag : InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'oons.ops',
                ),
                CircleLayer(circles: [
                  CircleMarker(
                    point: s.center,
                    radius: s.radiusM.toDouble(),
                    useRadiusInMeter: true,
                    color: Ops.plum.withValues(alpha: ring.length >= 3 ? 0.04 : 0.12),
                    borderColor: Ops.plum.withValues(alpha: ring.length >= 3 ? 0.3 : 0.8),
                    borderStrokeWidth: 1.5,
                  ),
                ]),
                if (ring.length >= 3)
                  PolygonLayer(polygons: [
                    Polygon(points: ring, color: Ops.plum.withValues(alpha: 0.18), borderColor: Ops.plum, borderStrokeWidth: 2),
                  ])
                else if (ring.length == 2)
                  PolylineLayer(polylines: [Polyline(points: ring, color: Ops.plum, strokeWidth: 2)]),
                MarkerLayer(markers: [
                  for (var i = 0; i < ring.length; i++)
                    Marker(
                      point: ring[i],
                      width: 22,
                      height: 22,
                      child: _handle(
                        at: ring[i],
                        onMove: (p) => _emit(ring: [...ring]..[i] = p),
                        onLongPress: () => _emit(ring: [...ring]..removeAt(i)),
                        child: Container(
                          decoration: BoxDecoration(color: Ops.card, border: Border.all(color: Ops.plum, width: 2)),
                        ),
                      ),
                    ),
                  Marker(
                    point: s.center,
                    width: 30,
                    height: 30,
                    child: _handle(
                      at: s.center,
                      onMove: (p) => _emit(center: p),
                      child: const Icon(Icons.place, color: Ops.plum, size: 30),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeBtn(_Mode m, String label) => mode == m
      ? V2Btn.primary(label, onPressed: () {}, size: V2BtnSize.sm)
      : V2Btn.ghost(label, onPressed: () => setState(() => mode = m), size: V2BtnSize.sm);
}
