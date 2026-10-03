import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/request_specialty.dart';
import 'package:oons/features/pro/v2/service_sheet.dart';
import 'package:oons/features/pro/v2/services_actions.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/services_state.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/features/pro/v2/tiers_sheet.dart';

/// One specialty: its area prices (cleaning), a filterable list of services, and
/// the actions on them. Reached from خدماتي; back returns there.
class ProSpecialtyScreen extends ConsumerStatefulWidget {
  const ProSpecialtyScreen({super.key, required this.categoryId});
  final String categoryId;
  @override
  ConsumerState<ProSpecialtyScreen> createState() => _ProSpecialtyScreenState();
}

class _ProSpecialtyScreenState extends ConsumerState<ProSpecialtyScreen> {
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(proServicesProvider).loaded) ref.read(proServicesProvider.notifier).load();
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/pro/services');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final st = ref.watch(proServicesProvider);
    final spec = ref.watch(proSpecialtyProvider(widget.categoryId));
    final body = <Widget>[];

    if (!st.loaded) {
      body.add(const DsSkeletonRows(rows: 3));
    } else if (spec == null) {
      body.add(DsCard(
        padding: EdgeInsets.zero,
        child: DsEmptyState(icon: 'list', title: t('loadFailTitle'), body: t('loadFailBody'), cta: t('back'), onCta: _back),
      ));
    } else {
      final approved = spec.status == SpecialtyStatus.approved;
      final services = spec.services;
      final shown = services.where((s) => filter == 'all' || (filter == 'on' ? s.active : !s.active)).toList();
      body
        ..add(Text(spec.name.of(lang), style: DsText.subTitle))
        ..add(const SizedBox(height: Ds.s3));
      if (!approved) {
        body.add(_Banner(text: spec.status == SpecialtyStatus.pending ? t('pendingBanner') : (spec.decisionNote.isNotEmpty ? spec.decisionNote : t('attentionBanner'))));
        body.add(const SizedBox(height: Ds.s4));
      }
      if (spec.hasTiers) {
        body
          ..add(DsSectionHeader(t('areaPrices'), actionLabel: approved ? t('edit') : null, onAction: approved ? () => showTiersSheet(context, ref, spec) : null))
          ..add(const SizedBox(height: Ds.s2))
          ..add(DsCard.rows(children: [
            for (final tier in spec.tiers) _TierRow(tier: tier, ar: ar, t: t, commission: st.commissionRate),
          ]))
          ..add(const SizedBox(height: Ds.s5));
      }
      body.add(DsSectionHeader(t('servicesHeader'), actionLabel: approved && spec.items.isNotEmpty ? t('editAllPrices') : null, onAction: approved && spec.items.isNotEmpty ? () => showBulkSheet(context, ref, spec) : null));
      body.add(const SizedBox(height: Ds.s2));
      if (services.isNotEmpty) {
        body
          ..add(Wrap(spacing: Ds.s2, runSpacing: Ds.s2, children: [
            for (final f in [('all', t('filterAll'), services.length), ('on', t('filterOn'), services.where((s) => s.active).length), ('off', t('filterOff'), services.where((s) => !s.active).length)])
              DsChip(label: '${f.$2} ${DsFormat.digits(f.$3, ar: ar)}', on: filter == f.$1, onTap: () => setState(() => filter = f.$1)),
          ]))
          ..add(const SizedBox(height: Ds.s3));
      }
      if (shown.isEmpty) {
        final none = services.isEmpty;
        body.add(DsCard(
          padding: EdgeInsets.zero,
          child: DsEmptyState(
            icon: 'list',
            title: none ? t('specEmptyNone', {'name': spec.name.of(lang)}) : t('specEmptyFilter'),
            body: none ? (approved ? t('specEmptyNoneBody') : (spec.status == SpecialtyStatus.pending ? t('pendingBanner') : t('attentionBanner'))) : t('specEmptyFilterBody'),
            cta: none && approved ? t('newServiceIn', {'name': spec.name.of(lang)}) : (none && spec.status == SpecialtyStatus.attention ? t('resubmit') : null),
            onCta: none && approved ? () => editOrAddService(context, ref, spec) : (none && spec.status == SpecialtyStatus.attention ? () => resubmitSpecialty(context, ref, spec) : null),
          ),
        ));
      } else {
        for (final s in shown) {
          body
            ..add(_ServiceCard(item: s, ar: ar, lang: lang, t: t, commission: st.commissionRate, onOpen: () => showServiceSheet(context, ref, spec, s), onToggle: (v) => setServiceVisible(context, ref, s, v)))
            ..add(const SizedBox(height: Ds.s2));
        }
        if (approved) {
          body
            ..add(const SizedBox(height: Ds.s2))
            ..add(DsButton(label: t('newServiceIn', {'name': spec.name.of(lang)}), icon: 'plus', onTap: () => editOrAddService(context, ref, spec)));
        }
      }
    }

    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            DsBackHeader(
              crumb: spec == null ? t('svcTitle') : '${t('svcTitle')} · ${verticalName(spec.vertical, ar: ar)}',
              onBack: _back,
            ),
            const SizedBox(height: Ds.s3),
            ...body,
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Ds.s3),
        decoration: BoxDecoration(color: Ds.terracottaBg, border: Border.all(color: Ds.terracotta, width: Ds.rule)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: OnsIcon('alert', size: 18, color: Ds.terracottaText)),
            const SizedBox(width: Ds.s2),
            Expanded(child: Text(text, style: DsText.body.copyWith(color: Ds.terracottaText, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.ar, required this.t, required this.commission});
  final ServiceItem tier;
  final bool ar;
  final String Function(String, [Map<String, Object>]) t;
  final double commission;

  @override
  Widget build(BuildContext context) {
    final price = (tier.price / 100).round();
    final range = DsFormat.range(tier.sizeFromSqm, tier.sizeToSqm ?? tier.sizeFromSqm, ar: ar, unit: 'م²');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Ds.s3, vertical: Ds.s3),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(range, style: DsText.num(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(helpersLabel(tier.workerCount > 0 ? tier.workerCount : 1, t, ar), style: DsText.meta),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(DsFormat.price(price, ar: ar), style: DsText.num(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${t('net')} ${DsFormat.amount(netEgp(price, commission), ar: ar)}', style: DsText.meta),
        ]),
      ]),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item, required this.ar, required this.lang, required this.t, required this.commission, required this.onOpen, required this.onToggle});
  final ServiceItem item;
  final bool ar;
  final String lang;
  final String Function(String, [Map<String, Object>]) t;
  final double commission;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final price = (item.price / 100).round();
    final meta = [
      DsFormat.duration(item.duration, ar: ar),
      if (item.benefits.isNotEmpty) t('tasksCount', {'n': DsFormat.digits(item.benefits.length, ar: ar)}),
    ].where((e) => e.isNotEmpty).join(' · ');
    final name = item.name.of(lang);
    return Opacity(
      opacity: item.active ? 1 : 0.55,
      child: Semantics(
        button: true,
        label: '$name · $meta · ${DsFormat.price(price, ar: ar)}',
        excludeSemantics: false,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: Ds.card(),
            padding: const EdgeInsetsDirectional.fromSTEB(Ds.s3, Ds.s3, Ds.s1, Ds.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, style: DsText.itemName)),
                      if (item.isPendingApproval) Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: DsStatusBadge(t('inReview'), tone: DsTone.attention)),
                    ]),
                    if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta, style: DsText.meta)),
                    const SizedBox(height: Ds.s2),
                    Row(children: [
                      Text(DsFormat.price(price, ar: ar), style: DsText.num(size: 15, weight: FontWeight.w600)),
                      const SizedBox(width: Ds.s2),
                      Text('${t('net')} ${DsFormat.amount(netEgp(price, commission), ar: ar)}', style: DsText.meta),
                    ]),
                  ]),
                ),
                DsSwitch(on: item.active, label: '$name — ${item.active ? t('filterOn') : t('filterOff')}', onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
