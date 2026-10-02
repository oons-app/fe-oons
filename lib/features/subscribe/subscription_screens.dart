import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/api.dart' show ApiException;
import 'package:oons/features/book/book_pricing.dart' show cleaningTaskNames;
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/plan_card.dart';
import 'package:oons/features/subscribe/plan_models.dart';
import 'package:oons/features/subscribe/subscription_ui.dart';
import 'package:oons/features/system/empty_states.dart';

/// Loaded plan list for one provider (shared by S2 and S3).
class ProviderPlansResult {
  const ProviderPlansResult({required this.enabled, required this.plans});
  final bool enabled;
  final List<PlanData> plans;
}

Future<ProviderPlansResult> loadProviderPlans(CustomerSubApi sub, String providerId) async {
  final r = await sub.get('/providers/$providerId/plans');
  return ProviderPlansResult(enabled: r['enabled'] != false, plans: PlanData.listFrom(r['plans']));
}

/// S2 — the provider's plans. Loads by id (deep-linkable): /plans/:id?name=…
class CleaningPlansScreen extends ConsumerStatefulWidget {
  const CleaningPlansScreen({super.key, required this.providerId, this.providerName = ''});
  final String providerId;
  final String providerName;
  @override
  ConsumerState<CleaningPlansScreen> createState() => _CleaningPlansScreenState();
}

class _CleaningPlansScreenState extends ConsumerState<CleaningPlansScreen> {
  List<PlanData> plans = const [];
  bool loading = true;
  bool enabled = true;
  Object? error;
  int? selected;
  bool feeOpen = false;
  String name = '';

  @override
  void initState() {
    super.initState();
    name = widget.providerName;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await loadProviderPlans(ref.read(customerSubApiProvider), widget.providerId);
      if (!mounted) return;
      final rec = r.plans.indexWhere((p) => p.recommended);
      setState(() {
        plans = r.plans;
        enabled = r.enabled;
        selected = rec >= 0 ? rec : null;
        loading = false;
      });
      if (name.isEmpty) unawaited(_loadName());
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> _loadName() async {
    try {
      final r = await ref.read(customerSubApiProvider).get('/providers/${widget.providerId}');
      final p = ProviderP.fromJson(r);
      if (mounted) setState(() => name = p.name('ar'));
    } catch (_) {
      // The title just stays without the provider name.
    }
  }

  void _open(PlanData plan) {
    final q = 'providerId=${widget.providerId}&planId=${plan.id}${name.isEmpty ? '' : '&name=${Uri.encodeComponent(name)}'}';
    context.push('/plan/included?$q', extra: plan);
  }

  @override
  Widget build(BuildContext context) {
    final pilot = ref.watch(sessionProvider).subscriptionsPilot;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(
              title: CC.s2Title,
              subtitle: name.isEmpty ? null : '${CC.s2FromPrefix}$name',
              onBack: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
            Expanded(child: _body(pilot)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool pilot) {
    if (loading) {
      return ListView(
        key: const ValueKey('plans-skeleton'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: const [
          SubSkeletonCard(height: 190),
          SizedBox(height: 10),
          SubSkeletonCard(height: 170),
          SizedBox(height: 10),
          SubSkeletonCard(height: 170),
        ],
      );
    }
    if (error != null) {
      return OnsEmptyState(
        icon: 'alert',
        tone: EmptyTone.warn,
        title: CC.s2LoadFailedTitle,
        body: subErrorMessage(error!),
        cta: CC.s2Retry,
        onCta: _load,
      );
    }
    if (!pilot || !enabled || plans.isEmpty) {
      return OnsEmptyState(
        icon: 'calendar',
        title: CC.s2EmptyTitle,
        body: CC.s2EmptyBody,
        cta: CC.s2EmptyCta,
        onCta: () => context.push('/book/${widget.providerId}'),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            children: [
              for (var i = 0; i < plans.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PlanCard(
                    plan: plans[i],
                    selected: selected == i,
                    onTap: () => setState(() => selected = i),
                    onButton: () => _open(plans[i]),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.line))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Text(CC.s2PricesLine, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Client.body)),
                  FeeTipButton(open: feeOpen, size: 18, onTap: () => setState(() => feeOpen = !feeOpen)),
                  const Text(CC.s2AdvanceTail, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Client.body)),
                ],
              ),
              if (feeOpen) ...[
                const FeeTipPanel(),
                const SizedBox(height: 6),
              ],
              const Text(CC.s2Footnote, style: TextStyle(fontSize: 11, height: 1.55, color: Client.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// S3 — what is included. Loads by ids (deep-linkable):
/// /plan/included?providerId=…&planId=…
class PlanIncludedScreen extends ConsumerStatefulWidget {
  const PlanIncludedScreen({super.key, required this.providerId, required this.planId, this.providerName = '', this.initial});
  final String providerId;
  final String planId;
  final String providerName;

  /// Optional already-loaded plan (skips the skeleton); the screen still works from ids alone.
  final PlanData? initial;
  @override
  ConsumerState<PlanIncludedScreen> createState() => _PlanIncludedScreenState();
}

class _PlanIncludedScreenState extends ConsumerState<PlanIncludedScreen> {
  PlanData? plan;
  List<ServiceItem> items = const [];
  Object? error;
  bool loading = true;
  bool deepOpen = true;
  bool regularOpen = false;

  @override
  void initState() {
    super.initState();
    plan = widget.initial;
    loading = plan == null;
    _load();
  }

  Future<void> _load() async {
    if (plan == null) setState(() => loading = true);
    setState(() => error = null);
    try {
      final api = ref.read(customerSubApiProvider);
      final r = await loadProviderPlans(api, widget.providerId);
      final found = r.plans.where((p) => p.id == widget.planId).toList();
      if (!mounted) return;
      setState(() {
        plan = found.isEmpty ? plan : found.first;
        loading = false;
        if (plan == null) error = ApiException(404, 'الباقة دي مش موجودة.');
      });
      try {
        final pr = await api.get('/providers/${widget.providerId}');
        final p = ProviderP.fromJson(pr);
        if (mounted) setState(() => items = p.items);
      } catch (_) {
        // The prototype descriptions are used when the catalog is unavailable.
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = plan == null ? e : null;
          loading = false;
        });
      }
    }
  }

  ServiceItem? _itemFor(PlanLine? l) {
    if (l == null) return null;
    for (final it in items) {
      if ((l.catalogItemId.isNotEmpty && (it.id == l.catalogItemId || it.catalogItemId == l.catalogItemId))) return it;
    }
    return null;
  }

  void _toSchedule(PlanData p) {
    context.push('/plans/${p.id}/schedule?providerId=${widget.providerId}');
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(title: CC.s3Title, onBack: () => context.canPop() ? context.pop() : context.go('/plans/${widget.providerId}')),
            Expanded(
              child: loading
                  ? ListView(
                      key: const ValueKey('included-skeleton'),
                      padding: const EdgeInsets.all(16),
                      children: const [SubSkeletonCard(height: 120), SizedBox(height: 12), SubSkeletonCard(height: 60), SizedBox(height: 12), SubSkeletonCard(height: 60)],
                    )
                  : p == null
                      ? OnsEmptyState(
                          icon: 'alert',
                          tone: EmptyTone.warn,
                          title: CC.s2LoadFailedTitle,
                          body: subErrorMessage(error ?? ''),
                          cta: CC.s2Retry,
                          onCta: _load,
                        )
                      : _content(p),
            ),
            if (p != null) _cta(p),
          ],
        ),
      ),
    );
  }

  Widget _content(PlanData p) {
    PlanLine? firstOf(bool deep) {
      for (final l in p.ordered) {
        if (l.deep == deep) return l;
      }
      return null;
    }

    final deepLine = firstOf(true), regLine = firstOf(false);
    final deepItem = _itemFor(deepLine), regItem = _itemFor(regLine);
    List<ScopeRow> rows = prototypeScopeRows();
    if (deepItem != null && regItem != null && deepItem.isCleaning && regItem.isCleaning) {
      rows = scopeRowsFor(
        deepExcluded: deepItem.excludedTaskIds,
        regularExcluded: regItem.excludedTaskIds,
        taskNames: {for (final e in cleaningTaskNames.entries) e.key: e.value.ar},
      );
    }
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(color: Client.sand2, border: Border(bottom: BorderSide(color: Client.ink))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink)),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Client.line))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(CC.paygLabel, style: TextStyle(fontSize: 10.5, color: Client.muted2)),
                              Text(
                                egpUnit(p.paygPiastres),
                                key: const ValueKey('included-payg'),
                                style: const TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.muted2, decoration: TextDecoration.lineThrough),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Client.plumTint,
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(CC.subLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Client.plum)),
                              Text('${egpText(p.pricePiastres)} ج.م/شهر', key: const ValueKey('included-sub'), style: const TextStyle(fontFamily: T.mono, fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.showSave) ...[
                const SizedBox(height: 10),
                Text(CC.s3SaveLine(egpText(p.savePiastres), p.savePct), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Client.oliveInk)),
              ],
            ],
          ),
        ),
        if (deepLine != null)
          _Accordion(
            key: const ValueKey('acc-deep'),
            deep: true,
            chip: deepLine.fullName,
            heading: CC.s3DeepHeading,
            body: _bodyFor(deepItem, CC.s3DeepBody),
            open: deepOpen,
            onToggle: () => setState(() => deepOpen = !deepOpen),
          ),
        if (regLine != null)
          _Accordion(
            key: const ValueKey('acc-regular'),
            deep: false,
            chip: regLine.fullName,
            heading: CC.s3RegularHeading,
            body: _bodyFor(regItem, CC.s3RegularBody),
            open: regularOpen,
            onToggle: () => setState(() => regularOpen = !regularOpen),
          ),
        if (deepLine != null && regLine != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(CC.s3Diff, style: TextStyle(fontFamily: T.mono, fontSize: 11, letterSpacing: 1.3, color: Client.muted2)),
          ),
          _ScopeTable(rows: rows),
        ],
      ],
    );
  }

  String _bodyFor(ServiceItem? it, String fallback) {
    final lines = it == null ? const <String>[] : it.benefits.map((b) => b.ar.trim()).where((e) => e.isNotEmpty).toList();
    return lines.isEmpty ? fallback : lines.join('\n');
  }

  Widget _cta(PlanData p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink))),
      child: InkWell(
        onTap: () => _toSchedule(p),
        child: Container(
          height: 54,
          color: Client.plum,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: const Row(
            children: [
              Expanded(child: Text(CC.s3Cta, style: TextStyle(color: Client.bg, fontSize: 16, fontWeight: FontWeight.w700))),
              OnsIcon('advance', size: 20, color: Client.bg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Accordion extends StatelessWidget {
  const _Accordion({super.key, required this.deep, required this.chip, required this.heading, required this.body, required this.open, required this.onToggle});
  final bool deep;
  final String chip;
  final String heading;
  final String body;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tint = deep ? Client.plumTint : Client.sand2;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            expanded: open,
            label: '$chip · $heading',
            onTap: onToggle,
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                color: open ? tint : Client.bg,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: deep ? 3 : 2),
                      decoration: BoxDecoration(color: deep ? Client.plum : Client.card, border: deep ? null : Border.all(color: Client.ink)),
                      child: Text(chip, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: deep ? Client.bg : Client.ink)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(heading, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                    OnsIcon(open ? 'minus' : 'plus', size: 18, color: Client.muted),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Container(
              color: tint,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(body, style: const TextStyle(fontSize: 13, height: 1.6, color: Client.body)),
            ),
        ],
      ),
    );
  }
}

class _ScopeTable extends StatelessWidget {
  const _ScopeTable({required this.rows});
  final List<ScopeRow> rows;

  Widget _cell(Widget child, {bool border = true}) => Container(
        width: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: border ? const Border(right: BorderSide(color: Client.line)) : null),
        child: child,
      );

  Widget _mark(bool inside) => inside
      ? const OnsIcon('check', size: 17, color: Client.plum, semanticLabel: CC.s3Inside)
      : Semantics(label: CC.s3Outside, child: Container(width: 10, height: 2, color: const Color(0xFFC9C1BA)));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink)),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Client.sand2, border: Border(bottom: BorderSide(color: Client.ink))),
            child: Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Text(CC.s3ColWork, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Client.muted)),
                  ),
                ),
                _cell(const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Text(CC.s3ColDeep, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)))),
                _cell(const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Text(CC.s3ColRegular, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)))),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Client.line))),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text(rows[i].task, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ),
                    _cell(_mark(rows[i].deep)),
                    _cell(_mark(rows[i].regular)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
