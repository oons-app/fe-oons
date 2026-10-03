import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/pro_service_editor_sheet.dart';
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/services_state.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/l10n/errors.dart';
import 'package:uuid/uuid.dart';

/// Everything a provider can do to a service. Small changes (hide/show) are
/// optimistic and roll back; bigger ones (bulk price, tiers, copy, delete) show
/// the server's real answer.

ProServiceDraft draftFromItem(ServiceItem it, {int? priceEgp}) => ProServiceDraft(
      id: it.id,
      categoryId: it.categoryId,
      name: it.name,
      catalogItemId: it.catalogItemId,
      kind: it.kind,
      duration: it.duration > 0 ? it.duration : 60,
      priceEgp: priceEgp ?? (it.price / 100).round(),
      travelEgp: (it.travelFee / 100).round(),
      active: it.active,
      sizeFromSqm: it.sizeFromSqm > 0 ? it.sizeFromSqm : 120,
      sizeToSqm: it.sizeToSqm,
      workerCount: it.workerCount > 0 ? it.workerCount : 1,
      excludedTaskIds: it.excludedTaskIds.toSet(),
      approvalState: it.approvalState,
      benefits: List.of(it.benefits),
    );

Map<String, dynamic> _updatePayload(ProServiceDraft d) {
  final p = d.toApiItem()..remove('id');
  d.dispose();
  return p;
}

/// Show/hide one service. Instant; put back with an error toast if refused.
Future<void> setServiceVisible(BuildContext context, WidgetRef ref, ServiceItem it, bool visible) async {
  final t = pv2(ref);
  final ctrl = ref.read(proServicesProvider.notifier);
  final ok = await ProAutosave(context, ref).request(
    'svc:${it.id}',
    () => ref.read(repoProvider).proSetServiceActive(it.id, visible),
    apply: () => ctrl.setActiveOverride(it.id, visible),
    rollback: () => ctrl.setActiveOverride(it.id, null),
    savedMessage: visible ? t('serviceShown') : t('serviceHidden'),
  );
  if (ok) ctrl.setActiveOverride(it.id, null);
}

/// A copy starts hidden and goes through review again, like any new service.
Future<bool> duplicateService(BuildContext context, WidgetRef ref, ServiceItem it) {
  final t = pv2(ref);
  final d = draftFromItem(it).copyAsNew('new-${const Uuid().v4().substring(0, 8)}');
  final payload = d.toApiItem()..remove('id');
  d.dispose();
  return ProAutosave(context, ref).request(
    'svc:copy:${it.id}',
    () => ref.read(repoProvider).proCreateService(payload),
    apply: () {},
    rollback: () {},
    savedMessage: t('copyMade'),
  );
}

Future<bool> confirmSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  required String yes,
  bool danger = true,
}) async {
  final t = pv2(ref);
  final r = await showDsSheet<bool>(
    context,
    title: title,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(body, style: DsText.body),
        const SizedBox(height: Ds.s5),
        DsButton(label: yes, kind: danger ? DsButtonKind.danger : DsButtonKind.primary, icon: danger ? 'alert' : null, onTap: () => Navigator.pop(ctx, true)),
        const SizedBox(height: Ds.s2),
        DsButton(label: t('cancel'), kind: DsButtonKind.secondary, onTap: () => Navigator.pop(ctx, false)),
      ],
    ),
  );
  return r == true;
}

/// Delete one service (asks first). The server refuses while upcoming bookings
/// point at it and says so — that message is shown as is.
Future<bool> deleteService(BuildContext context, WidgetRef ref, ServiceItem it) async {
  final t = pv2(ref);
  final yes = await confirmSheet(context, ref, title: t('deleteConfirmTitle'), body: t('deleteConfirmBody'), yes: t('delete'));
  if (!yes || !context.mounted) return false;
  return ProAutosave(context, ref).request(
    'svc:del:${it.id}',
    () => ref.read(repoProvider).proDeleteService(it.id),
    apply: () {},
    rollback: () {},
    savedMessage: t('serviceDeleted'),
  );
}

/// ±% on every service of THIS specialty only (nearest 5 pounds).
Future<bool> bulkChangePrices(BuildContext context, WidgetRef ref, ProSpecialty spec, double factor) async {
  final t = pv2(ref);
  final ctrl = ref.read(proServicesProvider.notifier);
  final targets = spec.items.where((i) => i.price > 0).toList();
  if (targets.isEmpty) return false;
  final next = {for (final i in targets) i.id: bulkPrice((i.price / 100).round(), factor)};
  unawaited(AppAnalytics.logEvent('pro_service_bulk_price', {'factor': factor}));
  final ok = await ProAutosave(context, ref).request(
    'bulk:${spec.categoryId}',
    () async {
      var last = <String, dynamic>{};
      for (final i in targets) {
        last = await ref.read(repoProvider).proUpdateService(i.id, _updatePayload(draftFromItem(i, priceEgp: next[i.id])));
      }
      return last;
    },
    apply: () {
      for (final i in targets) {
        ctrl.setPriceOverride(i.id, next[i.id]! * 100);
      }
    },
    rollback: () {
      for (final i in targets) {
        ctrl.setPriceOverride(i.id, null);
      }
      // Some updates may have gone through before one failed: re-read the truth.
      unawaited(ref.read(sessionProvider.notifier).refreshMe());
    },
    savedMessage: factor > 1 ? t('pricesUp') : t('pricesDown'),
  );
  if (ok) {
    for (final i in targets) {
      ctrl.setPriceOverride(i.id, null);
    }
  }
  return ok;
}

/// One row of the tiers sheet.
class TierEdit {
  TierEdit({this.source, required this.from, required this.to, required this.helpers, required this.priceEgp});
  final ServiceItem? source;
  int from;
  int to;
  int helpers;
  int priceEgp;

  factory TierEdit.fromItem(ServiceItem i) => TierEdit(
        source: i,
        from: i.sizeFromSqm,
        to: i.sizeToSqm ?? i.sizeFromSqm,
        helpers: i.workerCount > 0 ? i.workerCount : 1,
        priceEgp: (i.price / 100).round(),
      );

  TierEdit copy() => TierEdit(source: source, from: from, to: to, helpers: helpers, priceEgp: priceEgp);
}

/// Saves the tiers table: removed tiers are deleted, changed ones updated, new
/// ones created (cloned from the last tier so duration and included tasks match).
Future<bool> saveTiers(BuildContext context, WidgetRef ref, ProSpecialty spec, List<TierEdit> edits) async {
  final t = pv2(ref);
  final repo = ref.read(repoProvider);
  final before = spec.tiers;
  final keep = {for (final e in edits) if (e.source != null) e.source!.id};
  final template = before.isNotEmpty ? before.last : null;
  return ProAutosave(context, ref).request(
    'tiers:${spec.categoryId}',
    () async {
      var last = <String, dynamic>{};
      for (final i in before.where((i) => !keep.contains(i.id))) {
        last = await repo.proDeleteService(i.id);
      }
      for (final e in edits) {
        if (e.source != null) {
          final d = draftFromItem(e.source!, priceEgp: e.priceEgp)
            ..sizeFromSqm = e.from
            ..sizeToSqm = e.to
            ..workerCount = e.helpers;
          d.sizeFromCtrl.text = '${e.from}';
          d.sizeToCtrl.text = '${e.to}';
          last = await repo.proUpdateService(e.source!.id, _updatePayload(d));
        }
      }
      for (final e in edits.where((e) => e.source == null)) {
        if (template == null) continue;
        final d = draftFromItem(template, priceEgp: e.priceEgp).copyAsNew('new-${const Uuid().v4().substring(0, 8)}')
          ..sizeFromSqm = e.from
          ..sizeToSqm = e.to
          ..workerCount = e.helpers;
        d.sizeFromCtrl.text = '${e.from}';
        d.sizeToCtrl.text = '${e.to}';
        d.active = true;
        last = await repo.proCreateService(_updatePayload(d));
      }
      return last;
    },
    apply: () {},
    rollback: () => unawaited(ref.read(sessionProvider.notifier).refreshMe()),
    savedMessage: t('pricesSaved'),
  );
}

/// Add a service under [spec], or edit [existing], with the full editor.
Future<void> editOrAddService(BuildContext context, WidgetRef ref, ProSpecialty spec, {ServiceItem? existing}) async {
  final lang = langOf(ref);
  final st = ref.read(proServicesProvider);
  final row = st.categoryRows.firstWhere((r) => '${r['categoryId']}' == spec.categoryId, orElse: () => const {});
  final cats = row.isEmpty ? st.approvedRows : [row];
  final result = await showProServiceEditorSheet(
    context: context,
    lang: lang,
    approvedCategories: cats,
    repo: ref.read(repoProvider),
    existing: existing == null ? null : draftFromItem(existing),
    usedCategoryIds: const {},
    catalog: st.catalog,
    commissionRate: st.commissionRate,
  );
  if (result == null || !context.mounted) return;
  if (result.categoryId == '__delete__') {
    result.dispose();
    if (existing != null) await deleteService(context, ref, existing);
    return;
  }
  final t = pv2(ref);
  final payload = result.toApiItem()..remove('id');
  result.dispose();
  final repo = ref.read(repoProvider);
  await ProAutosave(context, ref).request(
    'svc:save:${existing?.id ?? 'new'}',
    () => existing == null ? repo.proCreateService(payload) : repo.proUpdateService(existing.id, payload),
    apply: () {},
    rollback: () {},
    savedMessage: existing == null ? t('sentForReview') : t('saved'),
  );
}

/// Used by tests and screens to turn a failure into the text people see.
String serviceErrorText(WidgetRef ref, Object e) => friendlyError(e, langOf(ref));
