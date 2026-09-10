import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

class VettingScreen extends ConsumerStatefulWidget {
  const VettingScreen({super.key});

  @override
  ConsumerState<VettingScreen> createState() => _VettingScreenState();
}

class _VettingScreenState extends ConsumerState<VettingScreen> {
  List<Map<String, dynamic>> pending = [];
  Map<String, dynamic>? sla;
  bool loading = true;
  String? error;

  static const _slaTargetHours = 72;

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
      final data = await staffClient.get('/admin/vetting-sla');
      final list = asMapList(data['pending'] ?? data['pendingProviders']);
      list.sort((a, b) => asDouble(b['waitHours']).compareTo(asDouble(a['waitHours'])));
      setState(() {
        pending = list;
        sla = data;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _reindex() async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'إعادة بناء الفهرس؟' : 'Rebuild provider search index?',
      body: lang == 'ar' ? 'قد يتأخر البحث نحو دقيقة.' : 'Search may lag for about a minute.',
      confirmLabel: lang == 'ar' ? 'إعادة الفهرسة' : 'Reindex',
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/search/reindex');
      if (mounted) v2Toast(context, lang == 'ar' ? 'وُضعت في الطابور' : 'Reindex queued');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _vet(Map p) async {
    final lang = ref.read(localeCodeProvider);
    final name = personName(p['name'] ?? p, lang, fallbackId: idOf(p));
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'التحقق من $name؟' : 'Vet $name?',
      body: lang == 'ar' ? 'يجعل الملف موثّقاً وقابلاً للحجز.' : 'Marks the profile vetted and makes it bookable.',
      confirmLabel: lang == 'ar' ? 'تحقّق' : 'Vet',
      roleLabel: roleLabel(ref.read(staffSessionProvider).effectiveRole),
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/providers/${idOf(p)}/vet', data: {'sexMarkerConfirmed': true});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم التحقق من $name' : '$name vetted');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'vetting')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canVet = staffCan(role, 'providers.vet');

    final longestH = pending.isEmpty ? 0.0 : asDouble(pending.first['waitHours']);
    final breaching = pending.where((p) => asDouble(p['waitHours']) > _slaTargetHours).length;
    String wait(double h) => h >= 24 ? '${(h / 24).floor()}d' : '${h.toStringAsFixed(0)}h';

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(lang == 'ar' ? 'في الطابور' : 'In queue', '${pending.length}', lang == 'ar' ? 'بانتظار قرار' : 'awaiting a decision'),
              _stat(lang == 'ar' ? 'أطول انتظار' : 'Longest wait', wait(longestH), lang == 'ar' ? 'الهدف ٣ أيام' : 'SLA target 3d'),
              _stat(lang == 'ar' ? 'تجاوز المهلة' : 'Breaching SLA', '$breaching', lang == 'ar' ? 'أكثر من ٣ أيام' : 'over 3 days'),
            ],
          ),
          const SizedBox(height: 16),
          if (loading && pending.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: V2Loading())
          else if (error != null)
            V2ErrorBanner(message: error!, onRetry: _load)
          else
            Container(
              decoration: BoxDecoration(
                color: Ops.card,
                borderRadius: BorderRadius.circular(Ops.radiusCard),
                border: Border.all(color: Ops.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.borderSoft))),
                    child: Row(
                      children: [
                        Text(lang == 'ar' ? 'طابور الانتظار' : 'Pending queue',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        V2Btn.ghost(lang == 'ar' ? 'إعادة فهرسة البحث' : 'Reindex search', onPressed: _reindex, size: V2BtnSize.sm),
                      ],
                    ),
                  ),
                  if (pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 38),
                      child: Center(
                        child: Text(lang == 'ar' ? 'الطابور فارغ' : 'Queue is clear',
                            style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      ),
                    )
                  else
                    for (final p in pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(personName(p['name'] ?? p, lang, fallbackId: idOf(p)),
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  Text(
                                    p['hasId'] == true && p['hasFish'] == true
                                        ? (lang == 'ar' ? 'المستندات مرفوعة، بحاجة لمراجعة' : 'Docs uploaded, needs review')
                                        : (lang == 'ar' ? 'مستندات ناقصة' : 'Documents missing'),
                                    style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text('${wait(asDouble(p['waitHours']))} ',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: Ops.mono,
                                      color: asDouble(p['waitHours']) > _slaTargetHours ? Ops.terracottaInk : Ops.inkSoft)),
                            ),
                            V2Btn.ghost(lang == 'ar' ? 'مراجعة' : 'Review',
                                onPressed: () => context.go(V2Paths.provider(idOf(p))), size: V2BtnSize.row),
                            const SizedBox(width: 6),
                            if (canVet)
                              V2Btn(label: lang == 'ar' ? 'تحقّق' : 'Vet', onPressed: () => _vet(p), kind: V2BtnKind.primary, size: V2BtnSize.row),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String note) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 11.5, color: Ops.faint)),
        ],
      ),
    );
  }
}
