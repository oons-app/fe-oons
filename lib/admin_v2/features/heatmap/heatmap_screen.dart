import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  List<Map<String, dynamic>> cells = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/heatmap');
      setState(() {
        cells = asMapList(data['cells'] ?? data['areas']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  (String, V2Tone, Color) _state(double fill, bool under) {
    if (under || fill < 0.6) return ('Undersupplied', V2Tone.bad, Ops.barCancelled);
    if (fill < 1) return ('Tight', V2Tone.warn, Ops.barPending);
    return ('Healthy', V2Tone.ok, Ops.barCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'heatmap')) return const V2Gate(allowed: false, child: SizedBox.shrink());

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          if (loading && cells.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading())
          else if (error != null)
            V2ErrorBanner(message: error!, onRetry: _load)
          else
            V2SectionCard(
              title: lang == 'ar' ? 'العرض والطلب حسب المنطقة' : 'Supply & demand by area',
              subtitle: lang == 'ar'
                  ? 'المهنيات النشطات مقابل الطلبات المفتوحة في آخر ٧ أيام'
                  : 'Active pros against open requests in the last 7 days',
              child: LayoutBuilder(builder: (context, box) {
                final cols = (box.maxWidth / 210).floor().clamp(1, 4);
                if (cells.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(lang == 'ar' ? 'لا بيانات' : 'No data yet', style: const TextStyle(color: Ops.muted)),
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in cells)
                      Builder(builder: (_) {
                        final demand = asInt(c['demand']);
                        final supply = asInt(c['supply']);
                        final fill = c['fillRate'] != null
                            ? asDouble(c['fillRate'])
                            : (demand == 0 ? (supply > 0 ? 1.0 : 0.0) : supply / demand);
                        final under = c['undersupplied'] == true || supply < demand;
                        final (label, tone, barColor) = _state(fill, under);
                        return SizedBox(
                          width: (box.maxWidth - (cols - 1) * 12) / cols,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Ops.cardAlt,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: label == 'Undersupplied' ? const Color(0xFFE0C9A8) : Ops.borderSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(areaName('${c['area'] ?? ''}', lang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    ),
                                    V2StatusPill(label: label, tone: tone),
                                  ],
                                ),
                                const SizedBox(height: 11),
                                Row(
                                  children: [
                                    _stat(lang == 'ar' ? 'مهنيات' : 'Pros', '$supply'),
                                    const SizedBox(width: 16),
                                    _stat(lang == 'ar' ? 'طلب' : 'Demand', '$demand'),
                                    const SizedBox(width: 16),
                                    _stat(lang == 'ar' ? 'التغطية' : 'Fill rate', '${(fill * 100).clamp(0, 999).toStringAsFixed(0)}%'),
                                  ],
                                ),
                                const SizedBox(height: 11),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(Ops.radiusPill),
                                  child: Container(
                                    height: 8,
                                    color: Ops.track,
                                    child: FractionallySizedBox(
                                      alignment: AlignmentDirectional.centerStart,
                                      widthFactor: fill.clamp(0, 1),
                                      child: Container(color: barColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Ops.muted)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
      ],
    );
  }
}
