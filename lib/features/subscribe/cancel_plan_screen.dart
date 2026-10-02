import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/subscription_ui.dart';
import 'package:oons/features/system/empty_states.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

const _fallbackReasons = [
  ('price', 'السعر'),
  ('schedule', 'المواعيد مش مناسبة'),
  ('quality', 'مش مبسوطة من الخدمة'),
  ('moving', 'هنتنقل أو مسافرة'),
  ('other', 'سبب تاني'),
];

/// Cancel flow: cancel-preview (exact refund) → reason + note → POST cancel.
/// Route: /me/plan/:id/cancel (loads from the id).
class CancelPlanScreen extends ConsumerStatefulWidget {
  const CancelPlanScreen({super.key, required this.subscriptionId});
  final String subscriptionId;
  @override
  ConsumerState<CancelPlanScreen> createState() => _CancelPlanScreenState();
}

class _CancelPlanScreenState extends ConsumerState<CancelPlanScreen> {
  Map<String, dynamic>? preview;
  Object? error;
  bool loading = true;
  bool busy = false;
  String? reason;
  String? submitError;
  int? refunded;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ref
          .read(customerSubApiProvider)
          .get('/subscriptions/${widget.subscriptionId}/cancel-preview');
      if (mounted) {
        setState(() {
          preview = r;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  List<(String, String)> get reasons {
    final raw = preview?['reasons'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final r in raw)
          if (r is Map) ('${r['key']}', '${r['label']}')
      ];
    }
    return _fallbackReasons;
  }

  Future<void> _submit() async {
    if (reason == null || busy) return;
    setState(() {
      busy = true;
      submitError = null;
    });
    try {
      final r = await ref.read(customerSubApiProvider).post(
        '/subscriptions/${widget.subscriptionId}/cancel',
        data: {
          'reason': reason,
          if (note.text.trim().isNotEmpty) 'note': note.text.trim()
        },
      );
      if (mounted) {
        setState(() => refunded = r['refundedPiastres'] != null ? _i(r['refundedPiastres']) : _i(preview?['totalPiastres']));
      }
    } catch (e) {
      if (mounted) setState(() => submitError = subErrorMessage(e));
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
                title: CC.cancelTitle,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/me/plan')),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (refunded != null) {
      return OnsEmptyState(
        icon: 'check',
        title: CC.cancelDone,
        body: '${CC.cancelRefundLabel} ${egpUnit(refunded!)}',
        cta: CC.s5NoPlanCta,
        onCta: () => context.go('/home'),
      );
    }
    if (loading) {
      return ListView(
          key: const ValueKey('cancel-skeleton'),
          padding: const EdgeInsets.all(16),
          children: const [
            SubSkeletonCard(height: 120),
            SizedBox(height: 12),
            SubSkeletonCard(height: 160)
          ]);
    }
    if (error != null) {
      return OnsEmptyState(
          icon: 'alert',
          tone: EmptyTone.warn,
          title: CC.s2LoadFailedTitle,
          body: subErrorMessage(error!),
          cta: CC.s5RetryLoad,
          onCta: _load);
    }
    final p = preview!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Client.sand2, border: Border.all(color: Client.ink)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(CC.cancelRefundLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Client.oliveInk)),
                    const SizedBox(height: 4),
                    Text(egpUnit(_i(p['totalPiastres'])),
                        key: const ValueKey('cancel-refund'),
                        style: const TextStyle(
                            fontFamily: T.mono,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(CC.cancelRefundLine(_i(p['refundableVisits'])),
                        style: const TextStyle(
                            fontSize: 12.5, color: Client.body)),
                    const SizedBox(height: 10),
                    _row(CC.s6PlanPrice, egpUnit(_i(p['servicePiastres']))),
                    _row(CC.s6Fee, egpUnit(_i(p['feePiastres']))),
                    const SizedBox(height: 6),
                    const Text(CC.cancelFootnote,
                        style: TextStyle(
                            fontSize: 11.5, height: 1.5, color: Client.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(CC.cancelReasonLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final r in reasons) _reasonRow(r.$1, r.$2),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: CC.cancelNoteHint,
                  filled: true,
                  fillColor: Client.card,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: const BorderSide(color: Client.ink)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: const BorderSide(color: Client.ink)),
                ),
              ),
              if (submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(submitError!,
                      key: const ValueKey('cancel-error'),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Client.terracotta)),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Client.ink))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: reason == null || busy ? null : _submit,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  color: reason == null || busy ? Client.line : Client.plum,
                  child: Text(CC.cancelConfirm,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: reason == null || busy
                              ? Client.muted2
                              : Client.bg)),
                ),
              ),
              InkWell(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/me/plan'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: const Text(CC.cancelKeep,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Client.plum)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(a,
                  style: const TextStyle(fontSize: 12.5, color: Client.muted))),
          Text(b, style: const TextStyle(fontFamily: T.mono, fontSize: 12.5))
        ]),
      );

  Widget _reasonRow(String key, String label) {
    final on = reason == key;
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: on,
      label: label,
      onTap: () => setState(() => reason = key),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() => reason = key),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Client.line))),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border.all(color: Client.ink),
                    color: on ? Client.plum : Client.card),
                child: on
                    ? const OnsIcon('check',
                        size: 12, color: Client.bg, strokeWidth: 3)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }
}
