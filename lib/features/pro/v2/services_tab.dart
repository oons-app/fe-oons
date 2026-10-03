import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/areas_hours.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/request_specialty.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/services_state.dart';
import 'package:oons/features/pro/v2/t.dart';

/// خدماتي — Category → Specialty → Service, plus her areas and hours.
class ProServicesTab extends ConsumerStatefulWidget {
  const ProServicesTab({super.key, this.openSpecialtyPicker = false});

  /// Opened from حسابي so she can request several specialties in one go.
  final bool openSpecialtyPicker;

  @override
  ConsumerState<ProServicesTab> createState() => _ProServicesTabState();
}

class _ProServicesTabState extends ConsumerState<ProServicesTab> {
  @override
  void initState() {
    super.initState();
    ProNav.servicesSeg.addListener(_onSeg);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
      unawaited(ref.read(proServicesProvider.notifier).load());
      unawaited(refreshServiceCities(activeOnly: true, force: true).then((_) {
        if (mounted) setState(() {});
      }));
      if (widget.openSpecialtyPicker) unawaited(requestSpecialties(context, ref));
    });
  }

  @override
  void dispose() {
    ProNav.servicesSeg.removeListener(_onSeg);
    super.dispose();
  }

  void _onSeg() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final me = ref.watch(sessionProvider).provider;
    final seg = ProNav.servicesSeg.value;
    return ColoredBox(
      color: Ds.cream,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            Row(
              children: [
                Expanded(child: Text(t('svcTitle'), style: DsText.screenTitle)),
                _LinkPill(open: me?.linkOpen ?? true, label: (me?.linkOpen ?? true) ? t('linkOpenPill') : t('linkClosedPill'), onTap: () => context.push('/pro/link')),
              ],
            ),
            const SizedBox(height: Ds.s4),
            DsSegmented(
              labels: [t('segServices'), t('segAreas'), t('segHours')],
              index: seg,
              onChanged: (i) => ProNav.servicesSeg.value = i,
            ),
            const SizedBox(height: Ds.s4),
            if (seg == ProNav.segServices) const _ServicesHome() else if (seg == ProNav.segAreas) const ProAreasView() else const ProHoursView(),
          ],
        ),
      ),
    );
  }
}

class _LinkPill extends StatelessWidget {
  const _LinkPill({required this.open, required this.label, required this.onTap});
  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = open ? Ds.olive : Ds.terracotta;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Ds.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: Ds.s3),
          decoration: BoxDecoration(color: open ? Ds.white : Ds.terracottaBg, border: Border.all(color: c, width: Ds.rule)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, color: c),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: open ? Ds.oliveText : Ds.terracottaText)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicesHome extends ConsumerWidget {
  const _ServicesHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = pv2(ref);
    final ar = langOf(ref) == 'ar';
    final st = ref.watch(proServicesProvider);
    final groups = ref.watch(proGroupsProvider);

    if (!st.loaded) return const DsSkeletonRows(rows: 4);
    if (st.failed && groups.isEmpty) {
      return DsCard(
        padding: EdgeInsets.zero,
        child: DsEmptyState(
          icon: 'offline',
          title: t('loadFailTitle'),
          body: t('loadFailBody'),
          cta: t('retry'),
          onCta: () => ref.read(proServicesProvider.notifier).load(),
        ),
      );
    }
    if (groups.isEmpty) {
      return DsCard(
        padding: EdgeInsets.zero,
        child: DsEmptyState(
          icon: 'list',
          title: t('svcEmptyTitle'),
          body: t('svcEmptyBody'),
          cta: t('requestSpecialty'),
          onCta: () => requestSpecialties(context, ref),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups) ...[
          DsSectionHeader(
            verticalName(g.vertical, ar: ar),
            meta: t('catSummary', {'a': DsFormat.specialties(g.specialties.length, ar: ar), 'b': DsFormat.services(g.serviceCount, ar: ar)}),
          ),
          const SizedBox(height: Ds.s2),
          DsCard.rows(children: [
            for (final s in g.specialties) _SpecialtyRow(spec: s, ar: ar, t: t, onTap: () => context.push('/pro/specialty/${s.categoryId}')),
          ]),
          const SizedBox(height: Ds.s5),
        ],
        DsButton(label: t('requestSpecialty'), kind: DsButtonKind.secondary, icon: 'plus', onTap: () => requestSpecialties(context, ref)),
        const SizedBox(height: Ds.s2),
        Text(t('requestSpecialtyHint'), style: DsText.hint),
      ],
    );
  }
}

class _SpecialtyRow extends StatelessWidget {
  const _SpecialtyRow({required this.spec, required this.ar, required this.t, required this.onTap});
  final ProSpecialty spec;
  final bool ar;
  final String Function(String, [Map<String, Object>]) t;
  final VoidCallback onTap;

  String _meta() {
    switch (spec.status) {
      case SpecialtyStatus.pending:
        return t('showsAfterReview');
      case SpecialtyStatus.attention:
        return spec.decisionNote.isNotEmpty ? spec.decisionNote : t('attentionBanner');
      case SpecialtyStatus.approved:
        if (spec.serviceCount == 0) return t('noServicesYet');
        return t('specMeta', {'a': DsFormat.services(spec.serviceCount, ar: ar), 'b': DsFormat.digits(spec.visibleCount, ar: ar)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = spec.name.of(ar ? 'ar' : 'en');
    return Semantics(
      button: true,
      label: '$name · ${_meta()}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Ds.s3),
          child: Row(
            children: [
              DsIconTile(verticalIcon(spec.vertical)),
              const SizedBox(width: Ds.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DsText.itemName),
                    const SizedBox(height: 2),
                    Text(_meta(), style: DsText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (spec.status == SpecialtyStatus.pending) Padding(padding: const EdgeInsetsDirectional.only(end: Ds.s2), child: DsStatusBadge(t('inReview'), tone: DsTone.attention)),
              if (spec.status == SpecialtyStatus.attention) Padding(padding: const EdgeInsetsDirectional.only(end: Ds.s2), child: DsStatusBadge(t('needsChanges'), tone: DsTone.attention)),
              const OnsIcon('advance', size: 18, color: Ds.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
