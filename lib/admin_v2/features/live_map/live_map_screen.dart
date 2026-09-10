import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

/// Approximate Cairo area centroids for map markers.
const _areaCentroids = <String, LatLng>{
  'zamalek': LatLng(30.0626, 31.2197),
  'dokki': LatLng(30.0385, 31.2126),
  'mohandeseen': LatLng(30.0500, 31.2000),
  'maadi': LatLng(29.9602, 31.2569),
  'nasr_city': LatLng(30.0511, 31.3656),
  'heliopolis': LatLng(30.0872, 31.3241),
  'garden_city': LatLng(30.0400, 31.2300),
  'downtown': LatLng(30.0444, 31.2357),
};

const _cairoDefault = LatLng(30.0444, 31.2357);

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> cells = [];
  List<Map<String, dynamic>> liveVisits = [];
  bool loading = true;
  String? error;
  Timer? _timer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_paused) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (!_paused) _load(silent: true);
  }

  LatLng _centroidFor(String slug) => _areaCentroids[slug] ?? _cairoDefault;

  LatLng? _visitLatLng(Map visit) {
    final addr = asMap(visit['address']);
    if (addr != null) {
      final lat = asDouble(addr['lat']);
      final lng = asDouble(addr['lng']);
      if (lat != 0 && lng != 0) return LatLng(lat, lng);
      final area = '${addr['area'] ?? ''}'.trim();
      if (area.isNotEmpty) return _centroidFor(area);
    }
    final area = '${visit['area'] ?? visit['areaName'] ?? ''}'.trim();
    if (area.isNotEmpty) return _centroidFor(area);
    return null;
  }

  Future<void> _load({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          loading = true;
          error = null;
        });
      }
      final heat = await staffClient.get('/admin/heatmap');
      final live = await staffClient.get('/admin/bookings', query: {'live': '1'});
      if (!mounted) return;
      setState(() {
        cells = asMapList(heat['cells'] ?? heat['areas']);
        liveVisits = asMapList(live['bookings']);
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) loading = false;
        error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'liveMap')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    if (loading && cells.isEmpty && liveVisits.isEmpty) {
      return const V2Loading();
    }

    final circleMarkers = <CircleMarker>[
      for (final cell in cells)
        CircleMarker(
          point: _centroidFor('${cell['area'] ?? ''}'),
          radius: 18 + (asDouble(cell['demand']) * 2).clamp(0, 40),
          color: (cell['undersupplied'] == true ? Ops.terracotta : Ops.plum).withValues(alpha: 0.28),
          borderColor: cell['undersupplied'] == true ? Ops.terracotta : Ops.plum,
          borderStrokeWidth: 1.5,
          useRadiusInMeter: false,
        ),
    ];

    final visitMarkers = <Marker>[
      for (final v in liveVisits)
        if (_visitLatLng(v) != null)
          Marker(
            point: _visitLatLng(v)!,
            width: 28,
            height: 28,
            child: Tooltip(
              message: '${v['ref'] ?? shortId(idOf(v))} · ${v['status'] ?? ''}',
              child: Container(
                decoration: BoxDecoration(
                  color: Ops.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Ops.card, width: 2),
                ),
                child: const Icon(Icons.place, size: 14, color: Ops.ink),
              ),
            ),
          ),
    ];

    return ColoredBox(
      color: Ops.page,
      child: Column(
        children: [
          V2PageHeader(
            title: lang == 'ar' ? 'الخريطة المباشرة' : 'Live map',
            lang: lang,
            resultCount: liveVisits.length,
            actions: [IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh))],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: V2ErrorBanner(message: error!, onRetry: () => _load()),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Ops.radiusCard),
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: _cairoDefault,
                    initialZoom: 11.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'oons.ops',
                    ),
                    CircleLayer(circles: circleMarkers),
                    MarkerLayer(markers: visitMarkers),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
