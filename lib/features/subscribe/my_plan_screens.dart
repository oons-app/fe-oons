import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/month_dates_screen.dart';
import 'package:oons/features/subscribe/my_plan_logic.dart';
import 'package:oons/features/subscribe/subscription_ui.dart';
import 'package:oons/features/system/empty_states.dart';

export 'package:oons/features/subscribe/cancel_plan_screen.dart';
export 'package:oons/features/subscribe/plan_bill_screen.dart';

const _onPlumMuted = Color(0xFFD9CBD4);
const _plumRule = Color(0xFF5A3A50);

/// S5 — my plan. Loads by id (or the first live subscription): /me/plan, /me/plan/:id.
class MyPlanScreen extends ConsumerStatefulWidget {
  const MyPlanScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends ConsumerState<MyPlanScreen> {
  MyPlan? plan;
  bool loading = true;
  bool empty = false;
  Object? error;
  bool busy = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = plan == null;
      error = null;
    });
    try {
      final api = ref.read(customerSubApiProvider);
      var id = widget.id;
      if (id == null || id.isEmpty) {
        final list = await api.get('/subscriptions');
        final rows = (list['subscriptions'] as List?) ?? const [];
        if (rows.isEmpty) {
          if (mounted) {
            setState(() {
              empty = true;
              loading = false;
            });
          }
          return;
        }
        id = '${(rows.first as Map)['id']}';
      }
      final r = await api.get('/subscriptions/$id');
      if (!mounted) return;
      setState(() {
        plan = MyPlan.fromResponse(r);
        empty = false;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() f, {String? ok}) async {
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await f();
      if (!mounted) return;
      notice = ok;
      await _load();
    } catch (e) {
      if (mounted) setState(() => notice = subErrorMessage(e, fallback: CC.s5Failed));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _skip(MyPlan p) async {
    final v = p.skippable;
    if (v == null) return;
    final deadline = p.makeupDeadline == null ? null : dateLabelAr(p.makeupDeadline!);
    final yes = await showSubConfirm(context, title: CC.s5SkipTitle, body: CC.s5SkipBody(deadline), confirmLabel: CC.s5Confirm, cancelLabel: CC.s5Keep);
    if (!yes || !mounted) return;
    await _act(() async {
      await ref.read(customerSubApiProvider).post('/subscriptions/${p.id}/visits/${v.id}/skip');
    }, ok: CC.s5Done);
  }

  Future<void> _pauseOrResume(MyPlan p) async {
    final resuming = p.paused || p.pauseScheduled;
    final yes = await showSubConfirm(
      context,
      title: resuming ? CC.s5ResumeTitle : CC.s5PauseTitle,
      body: resuming ? CC.s5ResumeBody : CC.s5PauseBody,
      confirmLabel: CC.s5Confirm,
      cancelLabel: CC.s5Keep,
    );
    if (!yes || !mounted) return;
    await _act(() async {
      await ref.read(customerSubApiProvider).post('/subscriptions/${p.id}/${resuming ? 'resume' : 'pause'}');
    }, ok: CC.s5Done);
  }

  void _reschedule(MyPlan p, MyVisit v) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => RescheduleVisitScreen(subscriptionId: p.id, visitId: v.id)))
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canBack = context.canPop();
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (canBack)
              SubHeader(title: CC.s5Title, onBack: () => context.pop())
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(CC.s5Title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (loading) {
      return ListView(
        key: const ValueKey('plan-skeleton'),
        padding: const EdgeInsets.all(16),
        children: const [SubSkeletonCard(height: 190), SizedBox(height: 14), SubSkeletonCard(height: 60), SizedBox(height: 8), SubSkeletonCard(height: 60)],
      );
    }
    if (error != null) {
      return OnsEmptyState(icon: 'alert', tone: EmptyTone.warn, title: CC.s2LoadFailedTitle, body: subErrorMessage(error!), cta: CC.s5RetryLoad, onCta: _load);
    }
    final p = plan;
    if (empty || p == null) {
      return OnsEmptyState(icon: 'calendar', title: CC.s5NoPlanTitle, body: CC.s5NoPlanBody, cta: CC.s5NoPlanCta, onCta: () => context.go('/home'));
    }
    return Column(
      children: [
        Expanded(child: _content(p)),
        _actions(p),
      ],
    );
  }

  Widget _content(MyPlan p) {
    final next = p.nextVisit;
    return ListView(
      children: [
        if (p.status == 'pending_payment')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Client.warnTint,
              child: Text(
                p.receiptWaiting
                    ? 'وصلتنا صورة التحويل. بنراجعها، والمواعيد محجوزة لحد ما الباقة تتأكد.'
                    : 'الباقة لسه مستنية الدفع. حوّلي بإنستاباي وارفعي صورة التحويل.',
                style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Client.plum, border: Border.all(color: Client.ink)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 4, color: Client.terracotta),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: const TextStyle(color: Client.bg, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (p.providerName.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(CC.s5With(p.providerName), style: const TextStyle(color: _onPlumMuted, fontSize: 12)),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const OnsIcon('calendar', size: 18, color: Client.bg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(CC.s5NextVisit, style: TextStyle(color: _onPlumMuted, fontSize: 10.5)),
                              Text(next?.when ?? CC.s5NoNext, key: const ValueKey('next-visit'), style: const TextStyle(color: Client.bg, fontSize: 14.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _plumRule))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.usedLabel, style: const TextStyle(color: Client.bg, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < p.minimum; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(child: Container(height: 6, color: i < p.used ? Client.bg : _plumRule)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${p.cycleLong}${p.status == 'pending_payment' ? '' : CC.s5PaidAdvance}', style: const TextStyle(color: _onPlumMuted, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(CC.s5VisitsLabel, style: TextStyle(fontFamily: T.mono, fontSize: 11, letterSpacing: 1.3, color: Client.muted2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink))),
          child: Column(children: [for (final v in p.visits) _visitRow(v)]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(CC.s5Note, style: TextStyle(fontSize: 11.5, height: 1.55, color: Client.muted)),
        ),
        if (p.pendingMakeup != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _outlined(CC.s5PlaceMakeup, () => _reschedule(p, p.pendingMakeup!)),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () => context.push('/me/plan/${p.id}/bill'),
            child: const Text(CC.s5Bill, style: TextStyle(color: Client.plum, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _visitRow(MyVisit v) {
    final t = v.tag;
    final (bg, fg, border) = switch (t) {
      VisitTag.done => (Client.olive, Client.bg, Client.olive),
      VisitTag.next || VisitTag.needsDate => (Client.plumTint, Client.plum, Client.plum),
      _ => (Client.sand, Client.muted, Client.line),
    };
    final muted = t == VisitTag.skipped || t == VisitTag.forfeited || t == VisitTag.cancelled;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.when, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: muted ? Client.muted2 : Client.ink)),
                Text(v.typeLine, style: const TextStyle(fontSize: 11, color: Client.muted2)),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 70),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, border: Border.all(color: border)),
            child: Text(visitTagLabel(t), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }

  Widget _outlined(String label, VoidCallback? onTap) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink)),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onTap == null ? Client.muted2 : Client.ink)),
      ),
    );
  }

  Widget _actions(MyPlan p) {
    final next = p.nextVisit;
    final canMove = next != null && p.status == 'active';
    final resuming = p.paused || p.pauseScheduled;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(notice!, key: const ValueKey('plan-notice'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Client.terracotta)),
            ),
          InkWell(
            onTap: busy || !canMove ? null : () => _reschedule(p, next),
            child: Container(
              height: 54,
              color: canMove ? Client.plum : Client.line,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OnsIcon('calendar', size: 18, color: canMove ? Client.bg : Client.muted2),
                  const SizedBox(width: 9),
                  Flexible(child: Text(CC.s5Reschedule, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: canMove ? Client.bg : Client.muted2))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _outlined(CC.s5Skip, p.skippable == null ? null : () => _skip(p))),
              const SizedBox(width: 8),
              Expanded(child: _outlined(resuming ? CC.s5Resume : CC.s5Pause, () => _pauseOrResume(p))),
            ],
          ),
          Center(
            child: InkWell(
              onTap: busy ? null : () => context.push('/me/plan/${p.id}/cancel'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(CC.s5Cancel, style: TextStyle(fontSize: 13, color: Client.muted2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
