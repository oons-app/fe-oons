import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/month_dates_copy.dart';
import 'package:oons/features/subscribe/month_dates_widgets.dart';
import 'package:oons/features/subscribe/plan_calendar.dart';
import 'package:oons/features/subscribe/plan_models.dart';
import 'package:oons/features/subscribe/plan_pay_flow.dart';
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/features/system/progress.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Phase { loading, ready, failed, noPlan, noDays }

/// S4 — month dates calendar + subscribe. Loads the plan, availability and
/// every quote/hold from the API by ids (deep-link / refresh safe).
class PlanScheduleScreen extends ConsumerStatefulWidget {
  const PlanScheduleScreen({
    super.key,
    required this.providerId,
    required this.planId,
  });
  final String providerId;
  final String planId;

  @override
  ConsumerState<PlanScheduleScreen> createState() => _PlanScheduleScreenState();
}

class _PlanScheduleScreenState extends ConsumerState<PlanScheduleScreen> {
  _Phase phase = _Phase.loading;
  PlanData? plan;
  PlanCalendar? cal;
  double feeRate = 0.10;

  bool weekly = true;
  DateTime? start;
  String wTime = '';
  List<PlanVisit> visits = [];
  int active = 0;

  /// Blocking (terracotta) / informational (olive) lines.
  String? error;
  String? info;
  bool feeOpen = false;

  // Server quote (the authority) + debounce.
  Timer? _debounce;
  int _qSeq = 0;
  bool quoting = false;
  bool quoteOk = false;
  String? quoteError;
  String? quoteMessage;
  int? quoteTotalPiastres;
  bool holdFailed = false;

  // Hold (15 min, server deadline).
  String? holdId;
  DateTime? holdUntil;
  bool paying = false;

  int get count => plan?.visitCount ?? 0;
  List<String> get types => plan?.types ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── loading ───────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => phase = _Phase.loading);
    try {
      final res = await Future.wait([
        subApi.get('/providers/${widget.providerId}/plans'),
        subApi.get('/subscriptions/availability', query: {'providerId': widget.providerId, 'planId': widget.planId}),
      ]);
      if (!mounted) return;
      final plans = PlanData.listFrom(res[0]['plans']);
      final found = plans.where((p) => p.id == widget.planId);
      if (found.isEmpty || found.first.visitCount == 0) {
        setState(() => phase = _Phase.noPlan);
        return;
      }
      plan = found.first;
      feeRate = (res[0]['feeRate'] is num) ? (res[0]['feeRate'] as num).toDouble() : 0.10;
      cal = PlanCalendar.fromJson(res[1]);
      if (!_initialSchedule()) {
        setState(() => phase = _Phase.noDays);
        return;
      }
      setState(() => phase = _Phase.ready);
      _changed();
    } catch (_) {
      if (mounted) setState(() => phase = _Phase.failed);
    }
  }

  /// First start day (from tomorrow on) whose weekly run fits; prefers the morning.
  bool _initialSchedule() {
    final c = cal!;
    for (var i = c.leadDays; i <= c.horizonDays; i++) {
      final d = addDays(c.today, i);
      if (!c.bookable(d)) continue;
      final r = c.weeklyFrom(d, count, '');
      if (!r.ok) continue;
      final common = c.commonSlot(r.visits.map((v) => v.date), prefer: '09:00');
      final t = common ?? (c.slotHours.isNotEmpty ? c.slotHours.first : '09:00');
      start = d;
      wTime = t;
      visits = [for (final v in r.visits) v.copyWith(time: t)];
      active = 0;
      return true;
    }
    return false;
  }

  // ── interaction (instant, local rules; the server re-validates) ────────────

  void _applyWeekly(DateTime d) {
    final c = cal!;
    if (!c.bookable(d)) {
      setState(() {
        error = c.rejectMessage(d);
        info = null;
      });
      return;
    }
    final r = c.weeklyFrom(d, count, wTime);
    if (!r.ok) {
      setState(() {
        error = r.error;
        info = null;
      });
      return;
    }
    var t = wTime;
    String? note;
    final common = c.commonSlot(r.visits.map((v) => v.date), prefer: wTime);
    if (common != null && common != wTime) {
      note = msgWeeklyTimeFallback(wTime, common);
      t = common;
    }
    setState(() {
      start = d;
      wTime = t;
      visits = [for (final v in r.visits) v.copyWith(time: t)];
      error = null;
      info = note;
    });
    _changed();
  }

  void _onCell(CalCell cell) {
    final c = cal!;
    if (weekly) {
      _applyWeekly(cell.date);
      return;
    }
    if (cell.visitIndex != null) {
      setState(() {
        active = cell.visitIndex!;
        error = null;
        info = null;
      });
      return;
    }
    final r = c.placeCustom(visits, active, cell.date);
    if (!r.ok) {
      // Rejected: the date is NOT selected, the message says why.
      setState(() {
        error = r.error;
        info = null;
      });
      return;
    }
    setState(() {
      visits = r.visits;
      active = r.activeIndex;
      error = null;
      info = r.message;
    });
    _changed();
  }

  void _onTime(String t) {
    setState(() {
      if (weekly) {
        wTime = t;
        visits = [for (final v in visits) v.copyWith(time: t)];
      } else {
        visits = [for (var j = 0; j < visits.length; j++) j == active ? visits[j].copyWith(time: t) : visits[j]];
      }
      error = null;
      info = null;
    });
    _changed();
  }

  void _setWeekly() {
    if (weekly) return;
    final r = cal!.weeklyFrom(start!, count, wTime);
    setState(() {
      weekly = true;
      error = r.ok ? null : r.error;
      info = null;
      if (r.ok) visits = [for (final v in r.visits) v.copyWith(time: wTime)];
    });
    _changed();
  }

  void _setCustom() {
    if (!weekly) return;
    setState(() {
      weekly = false;
      active = 0;
      error = null;
      info = null;
    });
  }

  // ── server: quote (debounced) -> hold ─────────────────────────────────────

  Map<String, dynamic> _body({String? addressId}) => {
        'providerId': widget.providerId,
        'planId': widget.planId,
        'mode': weekly ? 'weekly' : 'custom',
        if (weekly) ...{'start': dateKey(start!), 'time': wTime} else ...{
          'visits': [for (final v in visits) v.toJson()],
          'activeIndex': active,
        },
        if (addressId != null) 'addressId': addressId,
      };

  String? get _defaultAddressId {
    final addrs = ref.read(sessionProvider).user?.addresses ?? const <Address>[];
    if (addrs.isEmpty) return null;
    return addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first).id;
  }

  void _changed() {
    quoteOk = false;
    quoting = true;
    holdFailed = false;
    quoteError = null;
    quoteMessage = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _quote);
    if (mounted) setState(() {});
  }

  Future<void> _quote() async {
    final seq = ++_qSeq;
    try {
      final r = await subApi.post('/subscriptions/quote', data: _body());
      if (!mounted || seq != _qSeq) return;
      final err = '${r['error'] ?? ''}'.trim();
      final ok = r['ok'] != false && err.isEmpty;
      final totals = r['totals'] is Map ? r['totals'] as Map : const {};
      setState(() {
        quoting = false;
        quoteOk = ok;
        quoteError = err.isEmpty ? null : arMessage(err);
        final m = '${r['message'] ?? ''}'.trim();
        quoteMessage = m.isEmpty ? null : m;
        final t = totals['totalPiastres'];
        if (t is num) quoteTotalPiastres = t.toInt();
      });
      if (ok) unawaited(_hold(seq));
    } catch (e) {
      if (!mounted || seq != _qSeq) return;
      setState(() {
        quoting = false;
        quoteOk = false;
        quoteError = arMessage(e);
      });
    }
  }

  /// Holds the current selection (replaces our previous hold). Needs an
  /// address on the server, so it only runs once the customer has one; the
  /// pay flow always re-holds with the chosen address before charging.
  Future<void> _hold(int seq, {bool renewed = false}) async {
    final addr = _defaultAddressId;
    if (addr == null) return;
    try {
      final r = await subApi.post('/subscriptions/holds', data: _body(addressId: addr));
      if (!mounted || seq != _qSeq) return;
      setState(() {
        holdId = '${r['holdId'] ?? ''}';
        holdUntil = DateTime.tryParse('${r['expiresAt'] ?? ''}')?.toLocal();
        holdFailed = false;
        if (renewed) info = MD.holdExpired;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _qSeq) return;
      _holdRejected(e);
    } catch (_) {}
  }

  void _holdRejected(ApiException e) {
    setState(() {
      holdId = null;
      holdUntil = null;
      holdFailed = e.isSlotTaken;
      error = arMessage(e);
      final i = e.conflictIndex;
      if (i != null && i >= 0 && i < visits.length) {
        active = i;
        weekly = false;
      }
    });
  }

  void _holdExpired() {
    setState(() {
      holdId = null;
      holdUntil = null;
    });
    if (quoteOk) unawaited(_hold(_qSeq, renewed: true));
  }

  // ── CTA ───────────────────────────────────────────────────────────────────

  bool get ready => visits.length == count && count > 0 && quoteOk && !quoting && !holdFailed && !paying;

  Future<void> _pay() async {
    setState(() => paying = true);
    final res = await runPlanPay(
      context,
      ref,
      PlanPayRequest(
        providerId: widget.providerId,
        planId: widget.planId,
        scheduleBody: _body(),
        totalPiastres: quoteTotalPiastres ?? plan?.totalPiastres ?? 0,
        title: plan?.title ?? '',
      ),
    );
    if (!mounted) return;
    setState(() => paying = false);
    switch (res) {
      case PlanPayConflict(:final index, :final message):
        setState(() {
          error = message;
          holdId = null;
          holdUntil = null;
          if (index != null && index >= 0 && index < visits.length) {
            weekly = false;
            active = index;
          }
        });
        _changed();
      case PlanPayExpired(:final message):
        setState(() {
          error = message;
          holdId = null;
          holdUntil = null;
        });
        _changed();
      case PlanPayFailed(:final message):
        setState(() => error = message);
      case PlanPayCancelled():
      case PlanPayLaunched():
        break;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScheduleHeader(
                title: MD.title,
                subtitle: plan?.title,
                onBack: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (phase) {
      case _Phase.loading:
        return const SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(top: 12),
            child: ServiceListSkeleton(heading: MD.loadingHeading, caption: MD.loadingCaption, rows: 5),
          ),
        );
      case _Phase.failed:
        return SingleChildScrollView(
          child: OnsEmpty.fetchFailed(lang: 'ar', onRetry: _load, onSupport: _support),
        );
      case _Phase.noPlan:
        return SingleChildScrollView(
          child: OnsEmptyState(
            icon: 'calendar',
            title: MD.planMissing,
            body: '',
            cta: MD.retry,
            onCta: _load,
          ),
        );
      case _Phase.noDays:
        return SingleChildScrollView(
          child: OnsEmptyState(
            icon: 'calendar',
            title: MD.noWeekdayTitle,
            body: MD.noWeekdayBody,
            cta: MD.retry,
            onCta: _load,
          ),
        );
      case _Phase.ready:
        return _ready();
    }
  }

  void _support() => unawaited(launchUrl(Uri.parse('https://wa.me/201117198333'), mode: LaunchMode.externalApplication));

  Widget _ready() {
    final c = cal!;
    final cyc = c.cycleBounds(visits);
    final cells = c.cells(visits: visits, activeIndex: active, weekly: weekly, cycle: null);
    final activeVisit = visits[active < visits.length ? active : visits.length - 1];
    final chips = c.timeChips(visits: visits, activeIndex: active, weekly: weekly, selected: weekly ? wTime : activeVisit.time);
    final totalPiastres = quoteTotalPiastres ?? plan?.totalPiastres ?? 0;
    final err = error ?? quoteError;
    final infoText = info ?? quoteMessage;
    final pct = arDigits((feeRate * 100).round());
    return Column(
      children: [
        ClientBookingStepper(step: 2, labels: MD.steps),
        ScheduleModeTabs(weekly: weekly, onWeekly: _setWeekly, onCustom: _setCustom),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('schedule-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(weekly ? MD.howWeekly : MD.howCustom, style: const TextStyle(fontSize: 12.5, height: 1.55, color: Client.body)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(c.monthLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Text(MD.cycleShort(cyc.start, cyc.end), style: const TextStyle(fontSize: 11.5, color: Client.muted)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ScheduleGrid(cells: cells, types: types, onTap: _onCell),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: ScheduleLegend()),
                if (err != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: ScheduleErrorLine(err)),
                if (infoText != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: ScheduleInfoLine(infoText)),
                if (holdUntil != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: HoldCountdown(deadline: holdUntil!, label: MD.holdLabel, ar: true, onExpired: _holdExpired),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: ScheduleKicker(weekly ? MD.listWeekly : MD.listCustom),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ScheduleVisitList(
                    visits: visits,
                    types: types,
                    activeIndex: active,
                    interactive: !weekly,
                    onSelect: (i) => setState(() {
                      active = i;
                      error = null;
                      info = null;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    weekly ? MD.timeWeekly : MD.timeCustom(active, activeVisit.date),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Client.plum),
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: ScheduleTimeChips(chips: chips, onPick: _onTime)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Text(MD.rules, style: TextStyle(fontSize: 11.5, height: 1.6, color: Client.muted)),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: Client.bg, border: Border(top: BorderSide(color: Client.ink, width: Client.rule))),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(MD.feeIncl(pct), style: const TextStyle(fontSize: 10.5, color: Client.muted2))),
                            FeeTipButton(open: feeOpen, onTap: () => setState(() => feeOpen = !feeOpen)),
                          ],
                        ),
                        Text(MD.cycleLong(cyc.start, cyc.end), style: const TextStyle(fontSize: 11.5, color: Client.muted)),
                      ],
                    ),
                  ),
                  Text('${arFmt(totalPiastres / 100)} ج.م', key: const Key('bar-total'), style: const TextStyle(fontFamily: T.mono, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              if (feeOpen) const Padding(padding: EdgeInsets.only(top: 6), child: FeeTipPanel()),
              const SizedBox(height: 8),
              ScheduleCta(label: MD.cta(arFmt(totalPiastres / 100)), enabled: ready, busy: paying, onTap: _pay),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Reschedule ONE visit (opened from S5 «باقتي»). Same calendar + time chips in
// custom mode; the other visits are fixed constraints; stays in the cycle.
// ═════════════════════════════════════════════════════════════════════════

class RescheduleVisitScreen extends ConsumerStatefulWidget {
  const RescheduleVisitScreen({
    super.key,
    required this.subscriptionId,
    required this.visitId,
  });
  final String subscriptionId;
  final String visitId;

  @override
  ConsumerState<RescheduleVisitScreen> createState() => _RescheduleVisitScreenState();
}

class _RescheduleVisitScreenState extends ConsumerState<RescheduleVisitScreen> {
  _Phase phase = _Phase.loading;
  PlanCalendar? cal;
  ({DateTime start, DateTime end})? cycle;
  List<PlanVisit> visits = [];
  List<String> types = [];
  int active = 0;
  PlanVisit? original;
  bool canMove = true;
  String title = '';
  String? error;
  String? info;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => phase = _Phase.loading);
    try {
      final r = await subApi.get('/subscriptions/${widget.subscriptionId}');
      final sub = r['subscription'] is Map ? Map<String, dynamic>.from(r['subscription'] as Map) : <String, dynamic>{};
      final cyc = r['cycle'] is Map ? r['cycle'] as Map : (sub['cycle'] is Map ? sub['cycle'] as Map : const {});
      final raw = [for (final v in (r['visits'] as List? ?? sub['visits'] as List? ?? const [])) if (v is Map) v];
      final snap = sub['planSnapshot'] is Map ? sub['planSnapshot'] as Map : const {};
      final providerId = '${sub['providerId'] ?? ''}';
      final planId = '${snap['planId'] ?? ''}';
      final cs = parseDateKey('${cyc['startsOn'] ?? ''}');
      final ce = parseDateKey('${cyc['endsOn'] ?? ''}');
      if (providerId.isEmpty || planId.isEmpty) throw StateError('no plan');
      final target = raw.where((v) => '${v['id']}' == widget.visitId);
      if (target.isEmpty) {
        if (mounted) setState(() => phase = _Phase.noPlan);
        return;
      }
      final av = await subApi.get('/subscriptions/availability', query: {'providerId': providerId, 'planId': planId});
      if (!mounted) return;
      final live = <Map>[];
      for (final v in raw) {
        final st = '${v['status']}';
        if (!const {'booked', 'done', 'held'}.contains(st) || parseDateKey('${v['date']}') == null) continue;
        live.add(v);
      }
      live.sort((a, b) {
        final c = parseDateKey('${a['date']}')!.compareTo(parseDateKey('${b['date']}')!);
        return c != 0 ? c : ((a['sequence'] as num?) ?? 0).compareTo((b['sequence'] as num?) ?? 0);
      });
      final calendar = PlanCalendar.fromJson(av);
      visits = [for (final v in live) PlanVisit(date: parseDateKey('${v['date']}')!, time: '${v['time']}')];
      types = [for (final v in live) '${v['type']}'];
      active = live.indexWhere((v) => '${v['id']}' == widget.visitId);
      if (active < 0) {
        setState(() => phase = _Phase.noPlan);
        return;
      }
      original = visits[active];
      canMove = target.first['canReschedule'] != false;
      cal = calendar;
      cycle = (cs != null && ce != null) ? (start: cs, end: ce) : calendar.cycleBounds(visits);
      title = '${sub['title'] ?? ''}';
      setState(() => phase = _Phase.ready);
    } catch (_) {
      if (mounted) setState(() => phase = _Phase.failed);
    }
  }

  bool get dirty => original != null && visits[active] != original!.copyWith(shifted: visits[active].shifted);

  void _onCell(CalCell cell) {
    final c = cal!;
    if (cell.visitIndex != null) return; // other visits are fixed
    final cyc = cycle!;
    if (c.bookable(cell.date) && (cell.date.isBefore(cyc.start) || cell.date.isAfter(cyc.end))) {
      setState(() {
        error = MD.reOutOfCycle;
        info = null;
      });
      return;
    }
    final r = c.placeCustom(visits, active, cell.date);
    if (!r.ok) {
      setState(() {
        error = r.error;
        info = null;
      });
      return;
    }
    setState(() {
      visits = r.visits;
      active = visits.indexWhere((v) => dateKey(v.date) == dateKey(cell.date));
      error = null;
      info = r.message;
    });
  }

  void _onTime(String t) {
    setState(() {
      visits = [for (var j = 0; j < visits.length; j++) j == active ? visits[j].copyWith(time: t) : visits[j]];
      error = null;
      info = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    final v = visits[active];
    try {
      await subApi.post('/subscriptions/${widget.subscriptionId}/visits/${widget.visitId}/reschedule', data: {'date': dateKey(v.date), 'time': v.time});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(MD.reDone)));
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/me/plan/${widget.subscriptionId}');
      }
    } catch (e) {
      if (mounted) setState(() => error = arMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ScheduleHeader(
                title: MD.reTitle,
                subtitle: title,
                onBack: () => context.canPop() ? context.pop() : context.go('/me/plan/${widget.subscriptionId}'),
              ),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (phase) {
      case _Phase.loading:
        return const SingleChildScrollView(
          child: Padding(padding: EdgeInsets.only(top: 12), child: ServiceListSkeleton(heading: MD.reLoading, caption: MD.loadingCaption, rows: 5)),
        );
      case _Phase.failed:
        return SingleChildScrollView(child: OnsEmpty.fetchFailed(lang: 'ar', onRetry: _load, onSupport: () => unawaited(launchUrl(Uri.parse('https://wa.me/201117198333'), mode: LaunchMode.externalApplication))));
      case _Phase.noPlan:
      case _Phase.noDays:
        return SingleChildScrollView(child: OnsEmptyState(icon: 'calendar', title: MD.reMissing, body: '', cta: MD.retry, onCta: _load));
      case _Phase.ready:
        return _ready();
    }
  }

  Widget _ready() {
    final c = cal!;
    final cyc = cycle!;
    final cells = c.cells(visits: visits, activeIndex: active, weekly: false, cycle: cyc);
    final cur = visits[active];
    final chips = c.timeChips(visits: visits, activeIndex: active, weekly: false, selected: cur.time);
    final err = !canMove ? MD.reTooLate : error;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('schedule-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(MD.reHowCustom, style: TextStyle(fontSize: 12.5, height: 1.55, color: Client.body)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.monthLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      Text(MD.cycleShort(cyc.start, cyc.end), style: const TextStyle(fontSize: 11.5, color: Client.muted)),
                    ],
                  ),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: ScheduleGrid(cells: cells, types: types, onTap: _onCell)),
                const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: ScheduleLegend()),
                if (err != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: ScheduleErrorLine(err)),
                if (info != null) Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: ScheduleInfoLine(info!)),
                const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 6), child: ScheduleKicker(MD.listCustom)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ScheduleVisitList(
                    visits: visits,
                    types: types,
                    activeIndex: active,
                    interactive: false,
                    highlightActive: true,
                    onSelect: (_) {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(MD.timeCustom(active, cur.date), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Client.plum)),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: ScheduleTimeChips(chips: chips, onPick: _onTime)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Text(MD.reRules, style: TextStyle(fontSize: 11.5, height: 1.6, color: Client.muted)),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: Client.bg, border: Border(top: BorderSide(color: Client.ink, width: Client.rule))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (original != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(MD.reFrom('${dLabel(original!.date)} · ${periodLabel(original!.time)}'), style: const TextStyle(fontSize: 11.5, color: Client.muted)),
                ),
              ScheduleCta(label: MD.reCta, enabled: canMove && dirty, busy: busy, onTap: _save),
            ],
          ),
        ),
      ],
    );
  }
}
