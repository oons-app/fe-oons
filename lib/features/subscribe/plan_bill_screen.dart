import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/my_plan_logic.dart';
import 'package:oons/features/subscribe/subscription_ui.dart';
import 'package:oons/features/system/empty_states.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// S6 — billing for the current cycle. Route /me/plan/:id/bill (loads by id).
class PlanBillScreen extends ConsumerStatefulWidget {
  const PlanBillScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PlanBillScreen> createState() => _PlanBillScreenState();
}

class _PlanBillScreenState extends ConsumerState<PlanBillScreen> {
  MyPlan? plan;
  Map<String, dynamic> sub = const {};
  Map<String, dynamic> cycle = const {};
  Map<String, dynamic> receipt = const {};
  Object? error;
  bool loading = true;
  bool feeOpen = false;
  bool busy = false;
  String? notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(customerSubApiProvider);
      final r = await api.get('/subscriptions/${widget.id}');
      final mp = MyPlan.fromResponse(r);
      var rc = <String, dynamic>{};
      if (mp.cycleId.isNotEmpty) {
        try {
          rc = await api
              .get('/subscriptions/${widget.id}/cycles/${mp.cycleId}/receipt');
        } catch (_) {
          // The cycle record below still gives the amounts.
        }
      }
      if (!mounted) return;
      setState(() {
        plan = mp;
        sub = r['subscription'] is Map
            ? Map<String, dynamic>.from(r['subscription'] as Map)
            : {};
        cycle = r['cycle'] is Map
            ? Map<String, dynamic>.from(r['cycle'] as Map)
            : {};
        receipt = rc;
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

  int _amt(String receiptKey, String cycleKey) {
    if (receipt[receiptKey] != null) return _i(receipt[receiptKey]);
    if (cycle[cycleKey] != null) return _i(cycle[cycleKey]);
    final snap =
        sub['planSnapshot'] is Map ? sub['planSnapshot'] as Map : const {};
    return _i(snap[cycleKey]);
  }

  Future<void> _download() async {
    final p = plan;
    if (p == null || busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await ref
          .read(customerSubApiProvider)
          .get('/subscriptions/${p.id}/cycles/${p.cycleId}/receipt');
      final url = '${r['url'] ?? r['receiptUrl'] ?? ''}';
      if (url.isEmpty) {
        if (mounted) setState(() => notice = CC.s6ReceiptFailed);
      } else {
        await ref.read(externalOpenerProvider)(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => notice = subErrorMessage(e, fallback: CC.s6ReceiptFailed));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(
                title: CC.s6Title,
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/me/plan/${widget.id}')),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (loading) {
      return ListView(
          key: const ValueKey('bill-skeleton'),
          padding: const EdgeInsets.all(20),
          children: const [
            SubSkeletonCard(height: 110),
            SizedBox(height: 12),
            SubSkeletonCard(height: 80),
            SizedBox(height: 12),
            SubSkeletonCard(height: 160)
          ]);
    }
    if (error != null || plan == null) {
      return OnsEmptyState(
          icon: 'alert',
          tone: EmptyTone.warn,
          title: CC.s2LoadFailedTitle,
          body: subErrorMessage(error ?? ''),
          cta: CC.s5RetryLoad,
          onCta: _load);
    }
    return Column(
      children: [
        Expanded(child: _content(plan!)),
        _footer(),
      ],
    );
  }

  Widget _content(MyPlan p) {
    final snap =
        sub['planSnapshot'] is Map ? sub['planSnapshot'] as Map : const {};
    final price = _amt('price', 'pricePiastres');
    final fee = _amt('fee', 'feePiastres');
    final total = receipt['total'] != null || cycle['totalPiastres'] != null
        ? _amt('total', 'totalPiastres')
        : price + fee;
    final payg = _i(snap['paygPiastres']);
    final save = payg - price;
    final paidAt = parseYmd(cycle['paidAt']);
    final method = paymentMethodLabel('${sub['paymentMethod'] ?? ''}', 'ar');
    const mono = TextStyle(fontFamily: T.mono, fontSize: 13);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(CC.s6PaidAdvance,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Client.oliveInk)),
                        const SizedBox(height: 3),
                        Text(p.title,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(egpUnit(total),
                      key: const ValueKey('bill-total-head'),
                      style: const TextStyle(
                          fontFamily: T.mono,
                          fontSize: 22,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Client.line))),
                child: Column(
                  children: [
                    _info(
                        CC.s6Cycle,
                        p.cycleStart != null && p.cycleEnd != null
                            ? '${dateShortAr(p.cycleStart!)} – ${dateShortAr(p.cycleEnd!)}'
                            : '—'),
                    _info(CC.s6PayDate,
                        paidAt == null ? '—' : dateLabelAr(paidAt)),
                    if (method.isNotEmpty)
                      _info(CC.s6Method, method, last: true, icon: 'card')
                    else
                      const SizedBox(height: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (save > 0)
          Container(
            width: double.infinity,
            color: Client.olive,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CC.s6Saved(egpText(save)),
                    key: const ValueKey('bill-saved'),
                    style: const TextStyle(
                        color: Client.bg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(CC.paygLabel,
                              style: TextStyle(color: Client.bg, fontSize: 12)),
                          Text(egpUnit(payg),
                              style: mono.copyWith(
                                  color: Client.bg,
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(CC.subLabel,
                              style: TextStyle(color: Client.bg, fontSize: 12)),
                          Text(egpUnit(price),
                              style: mono.copyWith(
                                  color: Client.bg,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 7),
          child: Text(CC.s6Visits,
              style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 11,
                  letterSpacing: 1.3,
                  color: Client.muted2)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Client.card, border: Border.all(color: Client.ink)),
          child: Column(
            children: [
              for (final v in p.visits.where((v) => !v.isMakeup))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Client.line))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: v.type == 'deep' ? Client.plum : Client.card,
                            border: Border.all(
                                color: v.type == 'deep'
                                    ? Client.plum
                                    : Client.ink)),
                        child: Text(v.typeName,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color:
                                    v.type == 'deep' ? Client.bg : Client.ink)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(v.when,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              _line(CC.s6PlanPrice, egpText(price), border: Client.line),
              _line(CC.s6Fee, egpText(fee),
                  border: feeOpen ? Client.line : Client.ink,
                  tip: FeeTipButton(
                      open: feeOpen,
                      onTap: () => setState(() => feeOpen = !feeOpen),
                      size: 20)),
              if (feeOpen)
                Container(
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Client.ink))),
                  child: const FeeTipPanel(long: true),
                ),
              Container(
                color: Client.sand2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    const Expanded(
                        child: Text(CC.s6Total,
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Text(egpUnit(total),
                        key: const ValueKey('bill-total'),
                        style: const TextStyle(
                            fontFamily: T.mono,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: const DashedBox(
            color: Client.muted2,
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CC.s6DraftLabel,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Client.muted2)),
                SizedBox(height: 4),
                Text(CC.s6DraftBody,
                    style: TextStyle(
                        fontSize: 12, height: 1.6, color: Client.body)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(String a, String b, {bool last = false, String? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Client.line))),
        child: Row(
          children: [
            Expanded(
                child: Text(a,
                    style: const TextStyle(fontSize: 13, color: Client.muted))),
            if (icon != null) ...[
              OnsIcon(icon, size: 17, color: Client.ink),
              const SizedBox(width: 8)
            ],
            Text(b,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _line(String a, String b, {required Color border, Widget? tip}) =>
      Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: border))),
        child: Row(
          children: [
            Text(a, style: const TextStyle(fontSize: 13, color: Client.body)),
            if (tip != null) tip,
            const Spacer(),
            Text(b,
                style: const TextStyle(
                    fontFamily: T.mono, fontSize: 13, color: Client.body)),
          ],
        ),
      );

  Widget _footer() {
    Widget btn(String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: busy ? null : onTap,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Client.card, border: Border.all(color: Client.ink)),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Client.ink))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(notice!,
                  key: const ValueKey('bill-notice'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Client.terracotta)),
            ),
          Row(
            children: [
              btn(CC.s6Receipt, _download),
              const SizedBox(width: 8),
              btn(CC.s6ChangeCard, () => context.push('/me/pay')),
            ],
          ),
        ],
      ),
    );
  }
}
