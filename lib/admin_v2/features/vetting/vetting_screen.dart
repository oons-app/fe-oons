import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

class VettingScreen extends ConsumerStatefulWidget {
  const VettingScreen({super.key});
  @override
  ConsumerState<VettingScreen> createState() => _VettingScreenState();
}

class _VettingScreenState extends ConsumerState<VettingScreen> {
  List<Map<String, dynamic>> pending = [];
  Map<String, dynamic>? slaStats;
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
      final sla = await staffClient.get('/admin/vetting-sla');
      setState(() {
        pending = asMapList(sla['pending'] ?? sla['pendingProviders']);
        slaStats = sla;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _review(String id) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post('/admin/providers/$id/review');
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم النقل للمراجعة' : 'Moved to review'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _vet(String id, bool sexMarkerConfirmed) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post('/admin/providers/$id/vet', data: {'sexMarkerConfirmed': sexMarkerConfirmed});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحقق' : 'Vetted'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'vetting')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final avg = pending.isEmpty ? 0.0 : pending.map((p) => asDouble(p['waitHours'])).fold<double>(0, (a, b) => a + b) / pending.length;
    final canVet = staffCan(staffState.effectiveRole, 'providers.vet');
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(title: lang == 'ar' ? 'مهلة التحقق' : 'Vetting SLA', lang: lang, resultCount: loading ? null : pending.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              V2KpiTile(label: lang == 'ar' ? 'متوسط الانتظار' : 'Avg wait', value: '${avg.toStringAsFixed(0)}h'),
              V2KpiTile(label: lang == 'ar' ? 'الطابور' : 'Backlog', value: '${pending.length}'),
              V2KpiTile(label: lang == 'ar' ? 'أطول انتظار' : 'Longest wait', value: '${slaStats?['longestWait'] ?? '0h'}'),
              V2KpiTile(label: lang == 'ar' ? 'هذا الأسبوع' : 'This week', value: '${asInt(slaStats?['thisWeekVetted'])}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : pending.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'المهنية' : 'Provider',
                      lang == 'ar' ? 'الهاتف' : 'Phone',
                      lang == 'ar' ? 'الانتظار' : 'Wait',
                      lang == 'ar' ? 'المستندات' : 'Docs',
                      if (canVet) lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final p in pending)
                        [
                          identityCell(personName(p['name'] ?? p, lang, fallbackId: idOf(p)), shortId(idOf(p))),
                          Text('${p['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                          Text('${asDouble(p['waitHours']).toStringAsFixed(0)}h', style: const TextStyle(fontFamily: Ops.mono)),
                          Text('${p['hasId'] == true ? 'ID' : '—'} / ${p['hasFish'] == true ? 'Fish' : '—'}'),
                          if (canVet)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              TextButton(onPressed: () => context.go(V2Paths.provider(idOf(p))), child: Text(lang == 'ar' ? 'فتح' : 'Open')),
                              TextButton(onPressed: () => _review(idOf(p)), child: Text(lang == 'ar' ? 'مراجعة' : 'Review')),
                              PopupMenuButton<String>(
                                child: TextButton(onPressed: null, child: Text(lang == 'ar' ? 'تحقق' : 'Vet')),
                                onSelected: (action) {
                                  if (action == 'vet_confirmed') {
                                    _vet(idOf(p), true);
                                  } else if (action == 'vet_unconfirmed') {
                                    _vet(idOf(p), false);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'vet_confirmed',
                                    child: Text(lang == 'ar' ? 'تحقق (مع تأكيد الجنس)' : 'Vet (sexMarkerConfirmed)'),
                                  ),
                                  PopupMenuItem(
                                    value: 'vet_unconfirmed',
                                    child: Text(lang == 'ar' ? 'تحقق (بدون تأكيد)' : 'Vet (without confirmation)'),
                                  ),
                                ],
                              ),
                            ]),
                        ],
                    ],
                  )),
                  const SizedBox(height: 24),
                ]),
        ),
      ]),
    );
  }
}
