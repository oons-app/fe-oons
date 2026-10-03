import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/format.dart' show Loc;
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/pro_earnings_screens.dart' show ProSettlementsScreen;
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/date_labels.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/l10n/copy.dart';

/// الأرباح — what she can withdraw and when, where the money goes, how often
/// she is paid, this cycle's movements and a split by specialty.
class ProEarningsTab extends ConsumerStatefulWidget {
  const ProEarningsTab({super.key, this.now});
  final DateTime Function()? now;
  @override
  ConsumerState<ProEarningsTab> createState() => _ProEarningsTabState();
}

const _cycles = ['weekly', 'biweekly', 'monthly'];

class _ProEarningsTabState extends ConsumerState<ProEarningsTab> {
  Map<String, dynamic>? summary;
  bool failed = false;
  String? chosenCycle; // what she just picked, before the server confirms

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(repoProvider).earningsSummary();
      if (!mounted) return;
      setState(() {
        summary = s;
        failed = false;
      });
    } catch (_) {
      if (mounted && summary == null) setState(() => failed = true);
    }
  }

  String get _cycle {
    if (chosenCycle != null) return chosenCycle!;
    final pending = summary?['pendingCadence'];
    if (pending != null && '$pending'.isNotEmpty) return '$pending';
    return '${summary?['cadence'] ?? 'weekly'}';
  }

  Future<void> _setCycle(String next) {
    final before = chosenCycle;
    final t = pv2(ref);
    return ProAutosave(context, ref).request(
      'cadence',
      () => ref.read(repoProvider).setSettlementCadence(next),
      apply: () => setState(() => chosenCycle = next),
      rollback: () {
        if (mounted) setState(() => chosenCycle = before);
      },
      savedMessage: t('cycleSetToast'),
    ).then((ok) async {
      if (ok) {
        await _load();
        if (mounted) setState(() => chosenCycle = null);
      }
    });
  }

  String _statusLabel(String st, String lang) {
    final p = Copy.of(lang)['pro'] as Map;
    switch (st) {
      case 'ready':
        return '${p['readyForSettle']}';
      case 'held':
        return '${p['paidToHold']}';
      case 'dispute':
        return '${p['onHoldDispute']}';
      case 'processing':
        return '${p['processing']}';
      case 'settled':
        return '${p['settled']}';
      default:
        return st;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final me = ref.watch(sessionProvider).provider;

    Widget body;
    if (summary == null && !failed) {
      body = const DsSkeletonRows(rows: 3);
    } else if (summary == null) {
      body = DsCard(
        padding: EdgeInsets.zero,
        child: DsEmptyState(icon: 'offline', title: t('loadFailTitle'), body: t('loadFailBody'), cta: t('retry'), onCta: () {
          setState(() => failed = false);
          _load();
        }),
      );
    } else {
      body = _content(t, lang, ar, me?.payoutHandle);
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
              Row(children: [
                Expanded(child: Text(t('earnTitle'), style: DsText.screenTitle)),
                DsTextLink(t('settlements'), small: true, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProSettlementsScreen()))),
              ]),
              const SizedBox(height: Ds.s2),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(String Function(String, [Map<String, Object>]) t, String lang, bool ar, String? handle) {
    final s = summary!;
    final hero = (s['heroAmount'] as num?)?.toInt() ?? 0;
    final next = DateTime.tryParse('${s['nextSettlementAt'] ?? ''}')?.toLocal();
    final start = DateTime.tryParse('${s['periodStart'] ?? ''}')?.toLocal();
    final end = DateTime.tryParse('${s['periodEnd'] ?? ''}')?.toLocal();
    final lines = ((s['cycleLines'] as List?) ?? const []).whereType<Map>().toList();
    final cats = ((s['categories'] as List?) ?? const []).whereType<Map>().toList();
    final total = cats.fold<int>(0, (n, c) => n + ((c['amount'] as num?)?.toInt() ?? 0));
    final number = (handle ?? '').trim().isNotEmpty ? handle!.trim() : '${s['payoutHandleMasked'] ?? ''}'.trim();
    final cycleLabels = {'weekly': t('cycleWeekly'), 'biweekly': t('cycleBiweekly'), 'monthly': t('cycleMonthly')};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s['feeWaived'] == true) ...[
          Container(
            padding: const EdgeInsets.all(Ds.s3),
            color: Ds.olive,
            child: Text('${(Copy.of(lang)['pro'] as Map)['feeWaiverBanner']}', style: const TextStyle(fontSize: 13, height: 1.45, color: Ds.cream, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: Ds.s2),
        ],
        // Hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Ds.plum, border: Border.all(color: Ds.ink, width: Ds.rule)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('availableToWithdraw'), style: const TextStyle(fontSize: 13, color: Color(0xFFD9CBD4))),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(DsFormat.amount(hero / 100, ar: ar), style: DsText.num(size: 38, weight: FontWeight.w600, color: Ds.cream)),
              const SizedBox(width: 8),
              Text(t('egp'), style: const TextStyle(fontSize: 15, color: Color(0xFFD9CBD4))),
            ]),
            if (next != null) ...[
              Container(height: 1, color: Ds.cream.withValues(alpha: 0.18), margin: const EdgeInsets.fromLTRB(0, 14, 0, 12)),
              Row(children: [
                Expanded(child: Text(t('nextSettlement'), style: const TextStyle(fontSize: 13, color: Color(0xFFD9CBD4)))),
                Text(dayTitle(next, ar: ar), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Ds.cream)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: Ds.s2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: Ds.olive,
          child: Row(children: [
            const OnsIcon('shieldCheck', size: 20, color: Ds.cream),
            const SizedBox(width: 10),
            Expanded(child: Text(t('payoutBanner'), style: const TextStyle(fontSize: 13, height: 1.5, color: Ds.cream))),
          ]),
        ),
        const SizedBox(height: Ds.s6),
        DsSectionHeader(t('transfer')),
        const SizedBox(height: Ds.s2),
        DsCard.rows(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const OnsIcon('wallet', size: 20, color: Ds.plum),
              const SizedBox(width: Ds.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('instapay'), style: DsText.meta),
                  const SizedBox(height: 1),
                  Text(number.isEmpty ? t('noPayoutYet') : DsFormat.digits(number, ar: ar), style: DsText.num(size: 14, weight: FontWeight.w600, color: number.isEmpty ? Ds.textFaint : Ds.ink)),
                ]),
              ),
              DsTextLink(t('edit'), small: true, onTap: () => context.push('/pro/profile')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t('cycle'), style: DsText.meta),
              const SizedBox(height: Ds.s2),
              DsSegmented(
                labels: [for (final c in _cycles) cycleLabels[c]!],
                index: _cycles.indexOf(_cycle).clamp(0, 2),
                onChanged: (i) {
                  if (_cycles[i] != _cycle) _setCycle(_cycles[i]);
                },
              ),
              const SizedBox(height: Ds.s2),
              Text(t('cycleNote'), style: DsText.hint),
            ]),
          ),
        ]),
        const SizedBox(height: Ds.s6),
        DsSectionHeader(
          t('currentCycle'),
          meta: start != null && end != null ? '${dayMonth(start, ar: ar)} – ${dayMonth(end.subtract(const Duration(days: 1)), ar: ar)}' : null,
        ),
        const SizedBox(height: Ds.s2),
        if (lines.isEmpty)
          DsCard(padding: EdgeInsets.zero, child: DsEmptyState(icon: 'wallet', title: t('noMovements'), body: t('noMovementsWhy'), padding: const EdgeInsets.all(Ds.s5)))
        else
          DsCard.rows(children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text([_loc(l['serviceName'], lang), '${l['clientName'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), style: DsText.itemName.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (DateTime.tryParse('${l['checkedOutAt'] ?? ''}')?.toLocal() case final d?) dayMonth(d, ar: ar),
                          _statusLabel('${l['status'] ?? ''}', lang),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: DsText.meta,
                      ),
                    ]),
                  ),
                  Text(DsFormat.pricePiastres((l['amount'] as num?)?.toInt() ?? 0, ar: ar), style: DsText.num(size: 14, weight: FontWeight.w600)),
                ]),
              ),
          ]),
        if (cats.isNotEmpty) ...[
          const SizedBox(height: Ds.s6),
          DsSectionHeader(t('byCategory')),
          const SizedBox(height: Ds.s2),
          DsCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (var i = 0; i < cats.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(_loc(cats[i]['name'], lang), style: const TextStyle(fontSize: 13.5, color: Ds.ink))),
                  Text(DsFormat.pricePiastres((cats[i]['amount'] as num?)?.toInt() ?? 0, ar: ar), style: DsText.num(size: 13.5, weight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                DsMeter(value: total == 0 ? 0 : ((cats[i]['amount'] as num?)?.toDouble() ?? 0) / total, height: 8),
              ],
            ]),
          ),
        ],
      ],
    );
  }

  String _loc(dynamic raw, String lang) => raw is Map ? Loc.fromJson(raw).of(lang) : '${raw ?? ''}';
}
