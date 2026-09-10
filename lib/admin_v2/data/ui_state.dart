import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live text in the console header search box. Screens watch this to filter
/// their list; the shell clears it whenever the route changes so search never
/// leaks between screens (mirrors the prototype resetting `q` on `go`).
final v2QueryProvider = StateProvider<String>((ref) => '');

/// Per-screen header extras (a `+ New …` action, a live-visit count) published
/// by the active screen for the shell-owned header to render.
class V2HeaderConfig {
  const V2HeaderConfig({this.newLabel, this.onNewRecord, this.liveCount});
  final String? newLabel;
  final void Function()? onNewRecord;
  final int? liveCount;
}

final v2HeaderConfigProvider = StateProvider<V2HeaderConfig>((ref) => const V2HeaderConfig());

/// Sidebar nav badge counts keyed by nav id (`providers`, `payouts`, `claims`,
/// `bookings`, `categoryRequests`). Populated from `/admin/home` aggregates.
final v2NavBadgesProvider = StateProvider<Map<String, int>>((ref) => const {});
