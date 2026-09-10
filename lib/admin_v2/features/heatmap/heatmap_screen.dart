import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
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
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/heatmap');
      setState(() { cells = asMapList(data['cells'] ?? data['areas']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Color _tileColor(int demand, int supply) {
    if (supply == 0 && demand > 0) return Ops.terracottaTint;
    if (demand == 0) return Ops.greyTint;
    final fill = supply / (demand == 0 ? 1 : demand);
    if (fill < 0.5) return Ops.goldTint;
    if (fill < 1) return Ops.blueTint;
    return Ops.greenTint;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'heatmap')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(title: lang == 'ar' ? 'الخريطة الحرارية' : 'Heatmap', lang: lang, resultCount: loading ? null : cells.length,
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : cells.isEmpty
              ? const V2Empty()
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: cells.length,
                  itemBuilder: (ctx, i) {
                    final cell = cells[i];
                    final demand = asInt(cell['demand']);
                    final supply = asInt(cell['supply']);
                    final fillRate = cell['fillRate'] != null
                        ? asDouble(cell['fillRate'])
                        : (demand == 0 ? (supply > 0 ? 1.0 : 0.0) : supply / demand);
                    final undersupplied = cell['undersupplied'] == true || supply < demand;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _tileColor(demand, supply),
                        borderRadius: BorderRadius.circular(Ops.radiusCard),
                        border: Border.all(
                          color: undersupplied ? Ops.terracotta : Ops.border,
                          width: undersupplied ? 2 : 1,
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(areaName('${cell['area'] ?? ''}', lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const Spacer(),
                        Text('${lang == 'ar' ? 'طلب' : 'Demand'}: $demand', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                        Text('${lang == 'ar' ? 'عرض' : 'Supply'}: $supply', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                        Text(
                          '${lang == 'ar' ? 'تغطية' : 'Fill'}: ${(fillRate * 100).clamp(0, 999).toStringAsFixed(0)}%',
                          style: const TextStyle(fontFamily: Ops.mono, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        V2StatusPill(
                          label: undersupplied ? (lang == 'ar' ? 'نقص عرض' : 'Undersupplied') : (lang == 'ar' ? 'متوازن' : 'Covered'),
                          tone: undersupplied ? V2Tone.warn : V2Tone.ok,
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
