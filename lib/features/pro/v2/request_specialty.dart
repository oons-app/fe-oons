import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/pro_service_editor_sheet.dart';
import 'package:oons/features/pro/v2/services_actions.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/services_state.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/l10n/errors.dart';
import 'package:uuid/uuid.dart';

/// «اطلبي تخصص جديد»: pick one or more specialties (any vertical), then set up
/// the services for each. A single call per specialty sends the specialty and
/// its services to Oons together, so review happens in one pass.
Future<void> requestSpecialties(BuildContext context, WidgetRef ref) async {
  final t = pv2(ref);
  final lang = langOf(ref);
  final ar = lang == 'ar';
  final st = ref.read(proServicesProvider);
  List<Map<String, dynamic>> all = [];
  try {
    all = await ref.read(repoProvider).categories(activeOnly: true);
  } catch (_) {}
  // Only a live or waiting grant blocks asking again — a rejected one is
  // resubmitted from its own page.
  const blocking = {'active', 'pending_addition_approval', 'pending_initial_vetting'};
  final mine = st.categoryRows.where((c) => blocking.contains('${c['status']}')).map((c) => '${c['categoryId']}').toSet();
  final available = all.where((c) {
    final id = '${c['id'] ?? c['_id'] ?? ''}';
    return id.isNotEmpty && !mine.contains(id);
  }).toList();
  if (!context.mounted) return;
  if (available.isEmpty) {
    DsToast.show(context, t('noNewSpecialties'));
    return;
  }
  final picked = await showDsSheet<List<Map<String, dynamic>>>(
    context,
    title: t('pickSpecialtiesTitle'),
    builder: (ctx) => _PickSheet(available: available, t: t, ar: ar, lang: lang, onDone: (c) => Navigator.pop(ctx, c)),
  );
  if (picked == null || picked.isEmpty) return;
  for (final cat in picked) {
    if (!context.mounted) return;
    await _stageAndSubmit(context, ref, cat, const []);
  }
}

/// A rejected / changes-requested specialty: her earlier services are staged
/// again so nothing she typed is lost, and the whole bundle is re-sent.
Future<void> resubmitSpecialty(BuildContext context, WidgetRef ref, ProSpecialty spec) {
  final staged = [
    for (final i in spec.items)
      if (i.approvalState == 'rejected' || i.approvalState == 'changes_requested')
        draftFromItem(i).copyAsNew('new-${const Uuid().v4().substring(0, 8)}')..active = true,
  ];
  final row = ref.read(proServicesProvider).categoryRows.firstWhere((r) => '${r['categoryId']}' == spec.categoryId, orElse: () => {'categoryId': spec.categoryId, 'name': spec.name.toJson()});
  return _stageAndSubmit(context, ref, {...row, 'id': spec.categoryId}, staged);
}

Future<void> _stageAndSubmit(BuildContext context, WidgetRef ref, Map<String, dynamic> category, List<ProServiceDraft> initial) async {
  final t = pv2(ref);
  final lang = langOf(ref);
  final catId = '${category['id'] ?? category['categoryId'] ?? ''}';
  if (catId.isEmpty) return;
  final st = ref.read(proServicesProvider);
  final result = await showDsSheet<List<ProServiceDraft>>(
    context,
    title: t('stageTitle', {'name': _catName(category, lang)}),
    isDismissible: false,
    builder: (ctx) => _StageSheet(
      category: category,
      initial: initial,
      lang: lang,
      repo: ref.read(repoProvider),
      catalog: st.catalog,
      commissionRate: st.commissionRate,
      t: t,
      onSubmit: (d) => Navigator.pop(ctx, d),
    ),
  );
  if (result == null || result.isEmpty || !context.mounted) return;
  try {
    await ref.read(repoProvider).proAddCategoryWithServices(catId, [for (final d in result) d.toApiItem()]);
    for (final d in result) {
      d.dispose();
    }
    if (!context.mounted) return;
    DsToast.show(context, t('sentForReview'));
    await ref.read(proServicesProvider.notifier).load(quiet: true);
    unawaited(ref.read(sessionProvider.notifier).refreshMe());
  } on ApiException catch (e) {
    if (context.mounted) DsToast.show(context, friendlyError(e, lang), error: true);
  } catch (e) {
    if (context.mounted) DsToast.show(context, friendlyError(e, lang), error: true);
  }
}

String _catName(Map<String, dynamic> c, String lang) {
  final n = c['name'];
  return n is Map ? Loc.fromJson(n).of(lang) : '${n ?? c['slug'] ?? ''}';
}

class _Check extends StatelessWidget {
  const _Check(this.on);
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? Ds.plum : Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
        child: on ? const OnsIcon('check', size: 16, color: Ds.cream) : null,
      );
}

class _PickSheet extends StatefulWidget {
  const _PickSheet({required this.available, required this.t, required this.ar, required this.lang, required this.onDone});
  final List<Map<String, dynamic>> available;
  final String Function(String, [Map<String, Object>]) t;
  final bool ar;
  final String lang;
  final void Function(List<Map<String, dynamic>>) onDone;
  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final picked = <String>{};
  String _id(Map<String, dynamic> c) => '${c['id'] ?? c['_id'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final chosen = widget.available.where((c) => picked.contains(_id(c))).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('pickSpecialtiesBody'), style: DsText.body),
        const SizedBox(height: Ds.s3),
        DsCard.rows(children: [
          for (final c in widget.available)
            DsListRow(
              label: _catName(c, widget.lang),
              value: verticalName('${c['vertical'] ?? ''}', ar: widget.ar),
              showChevron: false,
              trailing: _Check(picked.contains(_id(c))),
              onTap: () => setState(() => picked.contains(_id(c)) ? picked.remove(_id(c)) : picked.add(_id(c))),
            ),
        ]),
        const SizedBox(height: Ds.s5),
        DsButton(
          label: chosen.isEmpty ? t('pickAtLeastOne') : t('continueN', {'n': DsFormat.digits(chosen.length, ar: widget.ar)}),
          onTap: chosen.isEmpty ? null : () => widget.onDone(chosen),
        ),
      ],
    );
  }
}

class _StageSheet extends StatefulWidget {
  const _StageSheet({
    required this.category,
    required this.initial,
    required this.lang,
    required this.repo,
    required this.catalog,
    required this.commissionRate,
    required this.t,
    required this.onSubmit,
  });
  final Map<String, dynamic> category;
  final List<ProServiceDraft> initial;
  final String lang;
  final Repo repo;
  final Map<String, dynamic> catalog;
  final double commissionRate;
  final String Function(String, [Map<String, Object>]) t;
  final void Function(List<ProServiceDraft>) onSubmit;
  @override
  State<_StageSheet> createState() => _StageSheetState();
}

class _StageSheetState extends State<_StageSheet> {
  late final staged = List<ProServiceDraft>.of(widget.initial);
  bool submitting = false;
  bool get ar => widget.lang == 'ar';

  Future<void> _edit({ProServiceDraft? existing}) async {
    final r = await showProServiceEditorSheet(
      context: context,
      lang: widget.lang,
      approvedCategories: [widget.category],
      repo: widget.repo,
      existing: existing,
      usedCategoryIds: const {},
      catalog: widget.catalog,
      commissionRate: widget.commissionRate,
    );
    if (r == null || !mounted) return;
    setState(() {
      if (r.categoryId == '__delete__') {
        if (existing != null) {
          staged.remove(existing);
          existing.dispose();
        }
        return;
      }
      final i = existing == null ? -1 : staged.indexOf(existing);
      i >= 0 ? staged[i] = r : staged.add(r);
    });
  }

  bool get _canSubmit =>
      !submitting && staged.isNotEmpty && staged.every((d) => (d.name.en.trim().isNotEmpty || d.name.ar.trim().isNotEmpty) && d.priceEgp > 0);

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final cat = _catName(widget.category, widget.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('stageBody'), style: DsText.body),
        const SizedBox(height: Ds.s3),
        if (staged.isEmpty)
          DsCard(child: Text(t('stageEmpty'), style: DsText.meta))
        else
          DsCard.rows(children: [
            for (final d in staged)
              DsListRow(
                label: d.name.of(widget.lang).isEmpty ? cat : d.name.of(widget.lang),
                subtitle: d.isCleaning
                    ? cleaningSizeMeta(fromSqm: d.sizeFromSqm, toSqm: d.sizeToSqm, workers: d.workerCount, ar: ar)
                    : '${DsFormat.duration(d.duration, ar: ar)} · ${DsFormat.price(d.priceEgp, ar: ar)}',
                icon: 'edit',
                onTap: () => _edit(existing: d),
              ),
          ]),
        const SizedBox(height: Ds.s3),
        DsButton(label: t('stageAdd'), kind: DsButtonKind.secondary, icon: 'plus', onTap: () => _edit()),
        const SizedBox(height: Ds.s3),
        DsButton(
          label: t('stageSubmit'),
          busy: submitting,
          onTap: _canSubmit
              ? () {
                  setState(() => submitting = true);
                  widget.onSubmit(staged);
                }
              : null,
        ),
        const SizedBox(height: Ds.s1),
        DsTextLink(t('cancel'), onTap: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}
