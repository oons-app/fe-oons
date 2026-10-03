import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/t.dart';

/// المناطق — one card per city. Every tap saves by itself («اتحفظ»); a refused
/// change goes back with an error toast. She always keeps at least one area.
class ProAreasView extends ConsumerStatefulWidget {
  const ProAreasView({super.key});
  @override
  ConsumerState<ProAreasView> createState() => _ProAreasViewState();
}

class _ProAreasViewState extends ConsumerState<ProAreasView> {
  final areas = <String>{};
  String? primedFor;

  void _prime(ProviderP? me) {
    if (me == null || primedFor == me.id) return;
    primedFor = me.id;
    areas
      ..clear()
      ..addAll(me.areas);
  }

  void _error(String msg) => DsToast.show(context, msg, error: true);

  Future<void> _change(Set<String> next) {
    final before = Set<String>.of(areas);
    return ProAutosave(context, ref).patchMe(
      'areas',
      () => {'areas': areas.toList()},
      apply: () => setState(() => areas
        ..clear()
        ..addAll(next)),
      rollback: () {
        if (mounted) {
          setState(() => areas
            ..clear()
            ..addAll(before));
        }
      },
    );
  }

  void _toggle(String id) {
    final t = pv2(ref);
    final next = Set<String>.of(areas);
    next.contains(id) ? next.remove(id) : next.add(id);
    if (next.isEmpty) return _error(t('needOneArea'));
    _change(next);
  }

  void _setCity(ServiceCity c, bool on) {
    final t = pv2(ref);
    final next = Set<String>.of(areas);
    on ? next.addAll(c.areas) : next.removeAll(c.areas);
    if (next.isEmpty) return _error(t('needOneArea'));
    _change(next);
  }

  Future<void> _addCity(List<ServiceCity> others) async {
    final t = pv2(ref);
    final lang = langOf(ref);
    if (others.isEmpty) {
      DsToast.show(context, t('noMoreCities'));
      return;
    }
    final picked = await showDsSheet<ServiceCity>(
      context,
      title: t('addCity'),
      builder: (ctx) => DsCard.rows(children: [
        for (final c in others) DsListRow(label: c.name.of(lang), onTap: () => Navigator.pop(ctx, c)),
      ]),
    );
    if (picked != null && mounted) _change({...areas, ...picked.areas});
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    _prime(ref.watch(sessionProvider).provider);
    final cities = serviceCities;
    final mine = [for (final c in cities) if (c.areas.any(areas.contains)) c];
    final others = [for (final c in cities) if (!mine.contains(c)) c];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('areasHint'), style: DsText.body),
        const SizedBox(height: Ds.s3),
        for (final c in mine) ...[
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.name.of(lang), style: DsText.itemName)),
                    Text('${DsFormat.digits(c.areas.where(areas.contains).length, ar: ar)} / ${DsFormat.digits(c.areas.length, ar: ar)}', style: DsText.num(size: 13)),
                  ],
                ),
                const SizedBox(height: Ds.s3),
                Wrap(spacing: Ds.s2, runSpacing: Ds.s2, children: [
                  for (final a in c.areas) DsChip(label: areaName(a, lang), on: areas.contains(a), onTap: () => _toggle(a)),
                ]),
                const SizedBox(height: Ds.s1),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsTextLink(
                    c.areas.every(areas.contains) ? t('clearAll') : t('selectAll'),
                    small: true,
                    onTap: () => _setCity(c, !c.areas.every(areas.contains)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Ds.s3),
        ],
        DsButton(label: t('addCity'), kind: DsButtonKind.secondary, icon: 'plus', onTap: () => _addCity(others)),
      ],
    );
  }
}

/// المواعيد — work days and booking hours, auto-saved the same way.
class ProHoursView extends ConsumerStatefulWidget {
  const ProHoursView({super.key});
  @override
  ConsumerState<ProHoursView> createState() => _ProHoursViewState();
}

/// Sat-first, like the Egyptian week; the number is the server's (1 = Mon … 7 = Sun).
const proWorkDayOrder = [6, 7, 1, 2, 3, 4, 5];
const _dayShortAr = {6: 'سبت', 7: 'حد', 1: 'اتنين', 2: 'تلات', 3: 'أربع', 4: 'خميس', 5: 'جمعة'};
const _dayShortEn = {6: 'Sat', 7: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri'};

class _ProHoursViewState extends ConsumerState<ProHoursView> {
  final days = <int>{};
  final hours = <String>{};
  String? primedFor;

  void _prime(ProviderP? me) {
    if (me == null || primedFor == me.id) return;
    primedFor = me.id;
    days
      ..clear()
      ..addAll(me.workDays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : me.workDays);
    hours
      ..clear()
      ..addAll((me.slotHours.isEmpty ? defaultLocalSlotHours : me.slotHours.map(utcHourToLocal)));
  }

  void _error(String msg) => DsToast.show(context, msg, error: true);

  Future<void> _changeDays(Set<int> next) {
    final before = Set<int>.of(days);
    return ProAutosave(context, ref).patchMe(
      'days',
      () => {'workDays': (days.toList()..sort())},
      apply: () => setState(() => days
        ..clear()
        ..addAll(next)),
      rollback: () {
        if (mounted) {
          setState(() => days
            ..clear()
            ..addAll(before));
        }
      },
    );
  }

  Future<void> _changeHours(Set<String> next) {
    final before = Set<String>.of(hours);
    return ProAutosave(context, ref).patchMe(
      'hours',
      () => {'slotHours': (hours.toList()..sort()).map(localHourToUtc).toList()},
      apply: () => setState(() => hours
        ..clear()
        ..addAll(next)),
      rollback: () {
        if (mounted) {
          setState(() => hours
            ..clear()
            ..addAll(before));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final ar = langOf(ref) == 'ar';
    _prime(ref.watch(sessionProvider).provider);
    final allHours = defaultLocalSlotHours.every(hours.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('hoursHint'), style: DsText.body),
        const SizedBox(height: Ds.s3),
        DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(t('workDays'), style: DsText.itemName)),
                Text(DsFormat.days(days.length, ar: ar), style: DsText.meta),
              ]),
              const SizedBox(height: Ds.s3),
              Row(children: [
                for (var i = 0; i < proWorkDayOrder.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: DsChip(
                      compact: true,
                      label: (ar ? _dayShortAr : _dayShortEn)[proWorkDayOrder[i]]!,
                      on: days.contains(proWorkDayOrder[i]),
                      onTap: () {
                        final d = proWorkDayOrder[i];
                        final next = Set<int>.of(days);
                        next.contains(d) ? next.remove(d) : next.add(d);
                        if (next.isEmpty) return _error(t('needOneDay'));
                        _changeDays(next);
                      },
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(height: Ds.s3),
        DsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(t('bookingHours'), style: DsText.itemName)),
                // She always keeps at least one hour, so "clear all" only appears
                // as "select all" until everything is on.
                if (!allHours) DsTextLink(t('selectAll'), small: true, onTap: () => _changeHours(defaultLocalSlotHours.toSet())),
              ]),
              const SizedBox(height: Ds.s3),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Ds.s2,
                crossAxisSpacing: Ds.s2,
                childAspectRatio: 1.9,
                children: [
                  for (final h in defaultLocalSlotHours)
                    DsChip(
                      mono: true,
                      compact: true,
                      label: DsFormat.time(h, ar: ar),
                      on: hours.contains(h),
                      onTap: () {
                        final next = Set<String>.of(hours);
                        next.contains(h) ? next.remove(h) : next.add(h);
                        if (next.isEmpty) return _error(t('needOneHour'));
                        _changeHours(next);
                      },
                    ),
                ],
              ),
              const SizedBox(height: Ds.s3),
              Text(t('hoursAvailable', {'n': DsFormat.digits(hours.length, ar: ar)}), style: DsText.meta),
            ],
          ),
        ),
      ],
    );
  }
}
