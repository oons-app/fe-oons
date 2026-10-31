import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/format.dart' show areaName;
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/date_labels.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/features/subscribe/ar_eg.dart' show visitTypeForName;
import 'package:oons/features/subscribe/visit_ops.dart' show VisitCheckInScreen;

/// الزيارات — three stats, then a week strip she can page through the next
/// two months, with the selected day's visits under it; «اللي فاتت» is one
/// card of rows.
class ProVisitsTab extends ConsumerStatefulWidget {
  const ProVisitsTab({super.key, this.now});

  /// Test seam for "today".
  final DateTime Function()? now;

  @override
  ConsumerState<ProVisitsTab> createState() => _ProVisitsTabState();
}

class _ProVisitsTabState extends ConsumerState<ProVisitsTab> {
  int seg = 0; // 0 upcoming, 1 past
  /// The day she tapped; null until she does.
  DateTime? pickedDate;
  int weekOffset = 0;
  List<BookingBundle>? up;
  List<BookingBundle>? past;
  bool failed = false;
  Timer? poll;

  /// Today through the next 30 Cairo days (four week pages).
  static const horizonDays = 30;

  DateTime get _today => dateOnlyOf((widget.now ?? DateTime.now)());
  int get _maxWeek => ((horizonDays - 7) ~/ 7).clamp(0, 99);

  @override
  void initState() {
    super.initState();
    _load();
    poll = Timer.periodic(const Duration(seconds: 25), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final jobs = await ref.read(repoProvider).proJobs();
      if (!mounted) return;
      setState(() {
        up = jobs.upcoming;
        past = jobs.past;
        failed = false;
        if (!quiet) _syncWeekToNearestVisit();
      });
    } catch (_) {
      // Keep the last list when a refresh fails; only a first load shows the error.
      if (mounted && up == null) setState(() => failed = true);
    }
  }

  /// Until she picks a day, the strip opens on the nearest day that has a visit
  /// (today first), not on an empty today. Later weeks are used when this week
  /// is empty so a booking next month is not hidden.
  int get day {
    final week = _week;
    if (pickedDate != null) {
      final i = week.indexWhere((d) => sameDay(d, pickedDate!));
      if (i >= 0) return i;
    }
    for (var i = 0; i < week.length; i++) {
      if (_on(week[i]).isNotEmpty) return i;
    }
    return 0;
  }

  List<DateTime> get _horizon => [for (var i = 0; i < horizonDays; i++) _today.add(Duration(days: i))];

  List<DateTime> get _week {
    final start = (weekOffset * 7).clamp(0, horizonDays - 7);
    return _horizon.sublist(start, start + 7);
  }

  void _syncWeekToNearestVisit() {
    if (pickedDate != null) {
      final n = pickedDate!.difference(_today).inDays;
      weekOffset = n < 0 ? 0 : (n ~/ 7).clamp(0, _maxWeek);
      return;
    }
    if (_week.any((d) => _on(d).isNotEmpty)) return;
    for (var w = 0; w <= _maxWeek; w++) {
      final start = (w * 7).clamp(0, horizonDays - 7);
      final slice = _horizon.sublist(start, start + 7);
      if (slice.any((d) => _on(d).isNotEmpty)) {
        weekOffset = w;
        return;
      }
    }
  }

  void _shiftWeek(int delta) {
    final next = (weekOffset + delta).clamp(0, _maxWeek);
    if (next == weekOffset) return;
    setState(() {
      weekOffset = next;
      pickedDate = null;
    });
  }

  List<BookingBundle> _on(DateTime d) {
    final rows = [for (final b in up ?? const <BookingBundle>[]) if (sameDay(b.booking.slotStart.toLocal(), d)) b];
    rows.sort((a, b) => a.booking.slotStart.compareTo(b.booking.slotStart));
    return rows;
  }

  void _open(BookingBundle b, bool ar) {
    final bk = b.booking;
    if (bk.isPlanVisit) {
      final local = bk.slotStart.toLocal();
      final name = bk.serviceName.of('ar');
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => VisitCheckInScreen(
          visitId: bk.subscriptionVisitId!,
          area: b.clientArea ?? '',
          visitType: visitTypeForName(name),
          date: '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}',
          time: '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
          firstName: b.clientName?.of('ar') ?? '',
          address: b.clientLocked ? '' : (bk.address?.line1.of('ar') ?? ''),
          phone: '',
        ),
      ));
    } else {
      context.push('/pro/job/${bk.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final me = ref.watch(sessionProvider).provider;
    final loading = up == null && !failed;
    final thisWeek = _horizon.sublist(0, 7);
    final inWeek = [for (final d in thisWeek) ..._on(d)];
    final todayN = _on(_today).length;
    final expected = inWeek.fold<int>(0, (n, b) => n + b.booking.serviceEarning);

    Widget content;
    if (loading) {
      content = const DsSkeletonRows(rows: 3);
    } else if (failed) {
      content = DsCard(
        padding: EdgeInsets.zero,
        child: DsEmptyState(icon: 'offline', title: t('loadFailTitle'), body: t('loadFailBody'), cta: t('retry'), onCta: () {
          setState(() => failed = false);
          _load();
        }),
      );
    } else if (seg == 1) {
      content = _pastList(t, lang, ar);
    } else if ((up ?? const <BookingBundle>[]).isEmpty) {
      content = DsEmptyState(
        icon: 'calendar',
        title: t('weekEmptyTitle'),
        body: t('weekEmptyWhy'),
        cta: t('weekEmptyCta'),
        onCta: () => ProNav.goServices(seg: ProNav.segAreas),
        link: t('weekEmptyLink'),
        onLink: () => ProNav.goServices(seg: ProNav.segHours),
        padding: const EdgeInsets.fromLTRB(Ds.s4, 40, Ds.s4, Ds.s4),
      );
    } else {
      content = _upcoming(t, lang, ar, me);
    }

    return ColoredBox(
      color: Ds.cream,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Ds.plum,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
            children: [
              Text(t('tabVisits'), style: DsText.screenTitle),
              const SizedBox(height: Ds.s4),
              DsStatStrip(items: [
                DsStat(label: t('statToday'), value: DsFormat.digits(todayN, ar: ar)),
                DsStat(label: t('statWeek'), value: DsFormat.digits(inWeek.length, ar: ar)),
                DsStat(label: t('statExpected'), value: DsFormat.amount(expected / 100, ar: ar), accent: true),
              ]),
              const SizedBox(height: Ds.s4),
              DsSegmented(labels: [t('segUpcoming'), t('segPast')], index: seg, onChanged: (i) => setState(() => seg = i)),
              const SizedBox(height: Ds.s4),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcoming(String Function(String, [Map<String, Object>]) t, String lang, bool ar, ProviderP? me) {
    final week = _week;
    final selected = week[day.clamp(0, 6)];
    final visits = _on(selected);
    final off = me != null && me.workDays.isNotEmpty && !me.workDays.contains(selected.weekday);
    final from = week.first;
    final to = week.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _WeekShift(label: t('prevWeek'), enabled: weekOffset > 0, forward: false, onTap: () => _shiftWeek(-1)),
            Expanded(
              child: Text(
                '${dayMonth(from, ar: ar)} – ${dayMonth(to, ar: ar)}',
                textAlign: TextAlign.center,
                style: DsText.meta,
              ),
            ),
            _WeekShift(label: t('nextWeek'), enabled: weekOffset < _maxWeek, forward: true, onTap: () => _shiftWeek(1)),
          ],
        ),
        const SizedBox(height: Ds.s2),
        Container(
          decoration: Ds.card(),
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _DayCell(
                  date: week[i],
                  ar: ar,
                  selected: i == day,
                  hasVisits: _on(week[i]).isNotEmpty,
                  closed: me != null && me.workDays.isNotEmpty && !me.workDays.contains(week[i].weekday),
                  first: i == 0,
                  onTap: () => setState(() => pickedDate = week[i]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: Ds.s5),
        DsSectionHeader(dayTitle(selected, ar: ar), meta: visits.isEmpty ? null : DsFormat.visits(visits.length, ar: ar)),
        const SizedBox(height: Ds.s2),
        if (visits.isEmpty)
          Container(
            decoration: BoxDecoration(border: Border.all(color: Ds.divider, width: Ds.rule)),
            child: DsEmptyState(
              icon: 'calendar',
              title: off ? t('dayOffTitle') : t('dayEmptyTitle'),
              body: off ? t('dayOffWhy', {'day': dayFull(selected.weekday, ar: ar)}) : t('dayEmptyWhy'),
              padding: const EdgeInsets.all(Ds.s5),
            ),
          )
        else
          for (final v in visits) ...[
            _VisitCard(bundle: v, ar: ar, lang: lang, t: t, onTap: () => _open(v, ar)),
            const SizedBox(height: Ds.s2),
          ],
      ],
    );
  }

  Widget _pastList(String Function(String, [Map<String, Object>]) t, String lang, bool ar) {
    final rows = past ?? const <BookingBundle>[];
    if (rows.isEmpty) {
      return DsCard(padding: EdgeInsets.zero, child: DsEmptyState(icon: 'clock', title: t('pastEmptyTitle'), body: t('pastEmptyWhy')));
    }
    return DsCard.rows(children: [for (final b in rows) _PastRow(bundle: b, ar: ar, lang: lang, t: t, onTap: () => context.push('/pro/job/${b.booking.id}'))]);
  }
}

class _WeekShift extends StatelessWidget {
  const _WeekShift({required this.label, required this.enabled, required this.forward, required this.onTap});
  final String label;
  final bool enabled, forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = forward ? Icons.chevron_right : Icons.chevron_left;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: Ds.minTarget,
          height: Ds.minTarget,
          child: Icon(icon, color: enabled ? Ds.plum : Ds.textFaint, size: 28),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.ar, required this.selected, required this.hasVisits, required this.closed, required this.first, required this.onTap});
  final DateTime date;
  final bool ar, selected, hasVisits, closed, first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Ds.cream : Ds.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${dayTitle(date, ar: ar)}${hasVisits ? '' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: closed && !selected ? 0.4 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            decoration: BoxDecoration(color: selected ? Ds.plum : Ds.white, border: BorderDirectional(start: first ? BorderSide.none : Ds.dividerSide)),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayShort(date.weekday, ar: ar), style: TextStyle(fontSize: 11, color: fg)),
                Text(DsFormat.digits(date.day, ar: ar), style: DsText.num(size: 15, weight: FontWeight.w600, color: fg)),
                const SizedBox(height: 3),
                Container(width: 5, height: 5, color: hasVisits ? (selected ? Ds.cream : Ds.plum) : Colors.transparent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.bundle, required this.ar, required this.lang, required this.t, required this.onTap});
  final BookingBundle bundle;
  final bool ar;
  final String lang;
  final String Function(String, [Map<String, Object>]) t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = bundle.booking;
    final local = b.slotStart.toLocal();
    final time = DsFormat.time('${local.hour}:${local.minute}', ar: ar);
    final name = bundle.clientName?.of(lang) ?? '';
    final area = bundle.clientArea == null || bundle.clientArea!.isEmpty ? '' : areaName(bundle.clientArea!, lang);
    final street = bundle.clientLocked ? '' : (b.address?.line1.of(lang) ?? '');
    final price = DsFormat.pricePiastres(b.serviceEarning, ar: ar);
    final isPlan = b.isPlanVisit || (bundle.planTag ?? '').isNotEmpty;
    return Semantics(
      button: true,
      label: '$time · $name · ${b.serviceName.of(lang)} · $area · $price',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: Ds.card(),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: Ds.s3),
                  decoration: const BoxDecoration(color: Ds.surface, border: BorderDirectional(end: Ds.dividerSide)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(time, style: DsText.num(size: 15, weight: FontWeight.w600)),
                    Text(DsFormat.durationShort(b.durationMin, ar: ar), style: DsText.meta.copyWith(fontSize: 11.5)),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(name, style: DsText.itemName, overflow: TextOverflow.ellipsis)),
                        if (isPlan) ...[const SizedBox(width: 6), DsTag(t('planTag'))],
                      ]),
                      const SizedBox(height: 2),
                      Text(b.serviceName.of(lang), style: DsText.body),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (area.isNotEmpty) ...[
                          const OnsIcon('pin', size: 14, color: Ds.textMuted),
                          const SizedBox(width: 4),
                          Flexible(child: Text(area, style: DsText.meta, overflow: TextOverflow.ellipsis)),
                        ],
                        const Spacer(),
                        Text(price, style: DsText.num(size: 13.5, weight: FontWeight.w600)),
                      ]),
                      if (street.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(street, style: DsText.body),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.bundle, required this.ar, required this.lang, required this.t, required this.onTap});
  final BookingBundle bundle;
  final bool ar;
  final String lang;
  final String Function(String, [Map<String, Object>]) t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = bundle.booking;
    final done = b.status == 'completed' || b.status == 'released';
    final cancelled = b.status.startsWith('cancelled');
    final tone = done ? DsTone.olive : DsTone.neutral;
    final label = done ? t('statusDone') : cancelled ? t('statusCancelled') : t('statusOther');
    final area = bundle.clientArea == null || bundle.clientArea!.isEmpty ? '' : areaName(bundle.clientArea!, lang);
    final when = dayTitle(b.slotStart.toLocal(), ar: ar);
    final price = DsFormat.pricePiastres(b.serviceEarning, ar: ar);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Ds.s4, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(bundle.clientName?.of(lang) ?? '', style: DsText.itemName)),
            DsStatusBadge(label, tone: tone),
          ]),
          const SizedBox(height: 2),
          Text(b.serviceName.of(lang), style: DsText.body),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text([when, if (area.isNotEmpty) area].join(' · '), style: DsText.meta)),
            Text(
              price,
              style: DsText.num(size: 13.5, weight: FontWeight.w600, color: done ? Ds.ink : Ds.textFaint).copyWith(decoration: done ? TextDecoration.none : TextDecoration.lineThrough),
            ),
          ]),
        ]),
      ),
    );
  }
}
