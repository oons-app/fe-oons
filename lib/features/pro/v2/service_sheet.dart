import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/format.dart' show Loc;
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/pro_service_editor_sheet.dart' show cleaningRoomsFromCatalog;
import 'package:oons/features/pro/v2/services_actions.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/services_state.dart';
import 'package:oons/features/pro/v2/t.dart';

/// One service: price, what she takes home, how long, what it includes — and the
/// four things she can do with it (edit, hide/show, copy, delete).
Future<void> showServiceSheet(BuildContext context, WidgetRef ref, ProSpecialty spec, ServiceItem item) {
  return showDsSheet<void>(
    context,
    title: spec.name.of(langOf(ref)),
    builder: (ctx) => _ServiceSheetBody(categoryId: spec.categoryId, itemId: item.id, hostContext: context, hostRef: ref),
  );
}

class _ServiceSheetBody extends ConsumerWidget {
  const _ServiceSheetBody({required this.categoryId, required this.itemId, required this.hostContext, required this.hostRef});
  final String categoryId;
  final String itemId;

  /// The screen under the sheet. Actions that outlive the sheet (copy, delete)
  /// must use ITS context and ref: the sheet's own are disposed when it closes.
  final BuildContext hostContext;
  final WidgetRef hostRef;

  /// "الخدمة بتشمل": the room-by-room tasks of a cleaning package, or the bullets
  /// of any other service.
  List<({String room, String text})> _includes(ServiceItem it, Map<String, dynamic> catalog, String lang, String Function(String, [Map<String, Object>]) t) {
    if (it.isCleaning) {
      final out = <({String room, String text})>[];
      for (final room in cleaningRoomsFromCatalog(catalog)) {
        final tasks = ((room['tasks'] as List?) ?? const []).whereType<Map>();
        final names = [
          for (final k in tasks)
            if (!it.excludedTaskIds.contains('${k['id']}')) (k['name'] is Map ? Loc.fromJson(k['name'] as Map).of(lang) : '${k['name']}'),
        ];
        if (names.isEmpty) continue;
        final rn = room['name'] is Map ? Loc.fromJson(room['name'] as Map).of(lang) : '${room['name']}';
        out.add((room: rn, text: names.join(lang == 'ar' ? '، ' : ', ')));
      }
      final w = it.workerCount > 0 ? it.workerCount : 1;
      out.add((room: '', text: lang == 'ar' ? (w == 1 ? 'عاملة واحدة' : w == 2 ? 'عاملتين' : '${DsFormat.digits(w, ar: true)} عاملات') : (w == 1 ? '1 worker' : '$w workers')));
      return out;
    }
    return [for (final b in it.benefits) (room: '', text: b.of(lang))];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final spec = ref.watch(proSpecialtyProvider(categoryId));
    final st = ref.watch(proServicesProvider);
    ServiceItem? it;
    for (final i in spec?.items ?? const <ServiceItem>[]) {
      if (i.id == itemId) it = i;
    }
    if (it == null) return const SizedBox.shrink();
    final item = it;
    final priceEgp = (item.price / 100).round();
    final includes = _includes(item, st.catalog, lang, t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(item.name.of(lang), style: DsText.subTitle.copyWith(fontSize: 22)),
        const SizedBox(height: Ds.s3),
        DsStatStrip(items: [
          DsStat(label: t('sheetPrice'), value: DsFormat.amount(priceEgp, ar: ar)),
          DsStat(label: t('sheetNet'), value: DsFormat.amount(netEgp(priceEgp, st.commissionRate), ar: ar), accent: true),
          DsStat(label: t('sheetDuration'), value: DsFormat.durationShort(item.duration, ar: ar)),
        ]),
        if (includes.isNotEmpty) ...[
          const SizedBox(height: Ds.s5),
          Text(t('includes'), style: DsText.section),
          const SizedBox(height: Ds.s2),
          for (final r in includes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 2), child: OnsIcon('check', size: 16, color: Ds.olive)),
                  const SizedBox(width: Ds.s2),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      if (r.room.isNotEmpty) TextSpan(text: '${r.room}: ', style: const TextStyle(fontWeight: FontWeight.w700, color: Ds.ink)),
                      TextSpan(text: r.text),
                    ]), style: DsText.body),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: Ds.s5),
        DsButton(
          label: t('editService'),
          icon: 'edit',
          onTap: spec == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  editOrAddService(hostContext, hostRef, spec, existing: item);
                },
        ),
        const SizedBox(height: Ds.s2),
        Row(
          children: [
            Expanded(
              child: DsButton(
                label: item.active ? t('hide') : t('show'),
                kind: DsButtonKind.secondary,
                compact: true,
                icon: '',
                onTap: () {
                  setServiceVisible(hostContext, hostRef, item, !item.active);
                },
              ),
            ),
            const SizedBox(width: Ds.s2),
            Expanded(
              child: DsButton(
                label: t('duplicate'),
                kind: DsButtonKind.secondary,
                compact: true,
                icon: '',
                onTap: () {
                  Navigator.of(context).pop();
                  duplicateService(hostContext, hostRef, item);
                },
              ),
            ),
            const SizedBox(width: Ds.s2),
            Expanded(
              child: DsButton(
                label: t('delete'),
                kind: DsButtonKind.danger,
                compact: true,
                icon: '',
                onTap: () async {
                  Navigator.of(context).pop();
                  await deleteService(hostContext, hostRef, item);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
