import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/book/book_widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/me/me_screens.dart';
import 'package:oons/features/pay/pay_checkout_frame.dart';
import 'package:oons/features/subscribe/month_dates_copy.dart';
import 'package:oons/features/subscribe/plan_calendar.dart';
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/features/system/progress.dart';
import 'package:oons/l10n/copy.dart';
import 'package:url_launcher/url_launcher.dart';

/// What S4 hands to the pay flow. [scheduleBody] is the quote/hold body.
class PlanPayRequest {
  const PlanPayRequest({
    required this.providerId,
    required this.planId,
    required this.scheduleBody,
    required this.totalPiastres,
    required this.title,
  });
  final String providerId, planId, title;
  final Map<String, dynamic> scheduleBody;
  final int totalPiastres;
}

sealed class PlanPayResult {
  const PlanPayResult();
}

/// Customer closed the address/method sheet.
class PlanPayCancelled extends PlanPayResult {
  const PlanPayCancelled();
}

/// Paid (navigated to the plan) or the payment screen was opened.
class PlanPayLaunched extends PlanPayResult {
  const PlanPayLaunched();
}

/// 409 slot_taken: [index] is the visit that lost its slot.
class PlanPayConflict extends PlanPayResult {
  const PlanPayConflict(this.index, this.message);
  final int? index;
  final String message;
}

/// 409 hold_expired.
class PlanPayExpired extends PlanPayResult {
  const PlanPayExpired(this.message);
  final String message;
}

class PlanPayFailed extends PlanPayResult {
  const PlanPayFailed(this.message);
  final String message;
}

class _Choice {
  const _Choice(this.addressId, this.method);
  final String addressId, method;
}

const kSupportUrl = 'https://wa.me/201117198333';

/// Address + method -> hold (with that address) -> POST /subscriptions
/// {holdId, method} -> paid => /me/plan/:id, or the payment screen.
Future<PlanPayResult> runPlanPay(BuildContext context, WidgetRef ref, PlanPayRequest req) async {
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Client.bg,
    shape: const RoundedRectangleBorder(),
    builder: (_) => Directionality(textDirection: TextDirection.rtl, child: _PaySheet(total: req.totalPiastres)),
  );
  if (choice == null || !context.mounted) return const PlanPayCancelled();
  String? holdId;
  DateTime? until;
  try {
    // The hold carries the address and restarts the 15-minute window.
    final h = await subApi.post('/subscriptions/holds', data: {...req.scheduleBody, 'addressId': choice.addressId});
    holdId = '${h['holdId'] ?? h['subscriptionId'] ?? ''}';
    until = DateTime.tryParse('${h['expiresAt'] ?? ''}')?.toLocal();
    final r = await subApi.post('/subscriptions', data: {'holdId': holdId, 'addressId': choice.addressId, 'method': choice.method});
    if (!context.mounted) return const PlanPayLaunched();
    final sub = r['subscription'];
    final id = sub is Map && '${sub['id'] ?? ''}'.isNotEmpty ? '${sub['id']}' : holdId;
    if (r['paid'] == true || (r['payment'] is Map && (r['payment'] as Map)['paid'] == true)) {
      context.go('/me/plan/$id');
      return const PlanPayLaunched();
    }
    final url = '${r['checkoutUrl'] ?? ''}'.trim();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanPayingScreen(
        subscriptionId: id,
        method: choice.method,
        totalPiastres: req.totalPiastres,
        checkoutUrl: url.isEmpty ? null : url,
        holdUntil: until,
      ),
    ));
    return const PlanPayLaunched();
  } on ApiException catch (e) {
    if (e.isSlotTaken) return PlanPayConflict(e.conflictIndex, arMessage(e));
    if (e.code == 'hold_expired') return PlanPayExpired(arMessage(e));
    if (e.isPayFail && holdId != null && holdId.isNotEmpty && context.mounted) {
      // Declined at the gateway: slots are still held, offer the recovery screen.
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PlanPayingScreen(
          subscriptionId: holdId!,
          method: choice.method,
          totalPiastres: req.totalPiastres,
          holdUntil: until,
          startInError: true,
        ),
      ));
      return const PlanPayLaunched();
    }
    return PlanPayFailed(arMessage(e));
  } catch (_) {
    return const PlanPayFailed(MD.generic);
  }
}

// ── Address + method sheet ─────────────────────────────────────────────────

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.total});
  final int total;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  String? addressId;
  String method = 'card';

  Future<void> _addAddress() async {
    final saved = await Navigator.of(context).push<Address?>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AddressFormScreen(returnResult: true)),
    );
    if (!mounted) return;
    final now = ref.read(sessionProvider).user?.addresses ?? const <Address>[];
    final pick = saved ?? (now.isNotEmpty ? now.last : null);
    if (pick != null) setState(() => addressId = pick.id);
  }

  @override
  Widget build(BuildContext context) {
    final addrs = ref.watch(sessionProvider).user?.addresses ?? const <Address>[];
    final co = Copy.of('ar')['co'] as Map;
    final selected = addrs.where((a) => a.id == addressId).isNotEmpty
        ? addressId
        : (addrs.isEmpty ? null : addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first).id);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: addrs.isEmpty
            ? SingleChildScrollView(child: OnsEmpty.noAddress(lang: 'ar', onAdd: _addAddress))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ClientKicker('العنوان'),
                    const SizedBox(height: 8),
                    for (final a in addrs)
                      ClientSelectRow(
                        selected: a.id == selected,
                        title: a.label.of('ar').isEmpty ? a.label.en : a.label.of('ar'),
                        subtitle: a.line1.of('ar').isEmpty ? a.line1.en : a.line1.of('ar'),
                        onTap: () => setState(() => addressId = a.id),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _addAddress,
                        child: const Text('ضيفي عنوان تاني', style: TextStyle(color: Client.plum, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const ClientKicker('طريقة الدفع'),
                    const SizedBox(height: 8),
                    BookPayMethodTile(
                      selected: method == 'card',
                      kind: BookPayKind.card,
                      title: '${co['card']}',
                      note: '${co['cardNote']}',
                      onTap: () => setState(() => method = 'card'),
                    ),
                    BookPayMethodTile(
                      selected: method == 'instapay',
                      kind: BookPayKind.wallet,
                      title: '${co['instapay']}',
                      note: '${co['instapayNote']}',
                      onTap: () => setState(() => method = 'instapay'),
                    ),
                    const SizedBox(height: 12),
                    ClientPrimaryButton(
                      label: MD.cta(arFmt(widget.total / 100)),
                      enabled: selected != null,
                      onTap: () => Navigator.of(context).pop(_Choice(selected!, method)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Paying / recovery screen ───────────────────────────────────────────────

String _methodLabel(String m) => m == 'instapay' ? 'محفظة الهاتف' : 'البطاقة';

/// Frame + polling while the gateway runs, and the recoverable error branch
/// (nothing charged, slots still held with a countdown, retry / other
/// method / support) — mirrors PaymentFrameScreen.
class PlanPayingScreen extends ConsumerStatefulWidget {
  const PlanPayingScreen({
    super.key,
    required this.subscriptionId,
    required this.method,
    required this.totalPiastres,
    this.checkoutUrl,
    this.holdUntil,
    this.startInError = false,
  });
  final String subscriptionId, method;
  final int totalPiastres;
  final String? checkoutUrl;
  final DateTime? holdUntil;
  final bool startInError;

  @override
  ConsumerState<PlanPayingScreen> createState() => _PlanPayingScreenState();
}

class _PlanPayingScreenState extends ConsumerState<PlanPayingScreen> with WidgetsBindingObserver {
  late String method = widget.method;
  String? url;
  DateTime? hold;
  bool starting = false;
  bool failed = false;
  bool expired = false;
  bool done = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    url = widget.checkoutUrl;
    hold = widget.holdUntil;
    failed = widget.startInError;
    if (!failed) _beginPoll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !done && !failed) unawaited(_check());
  }

  void _beginPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final r = await subApi.get('/subscriptions/${widget.subscriptionId}');
      if (!mounted || done) return;
      final sub = r['subscription'] is Map ? r['subscription'] as Map : const {};
      final status = '${sub['status'] ?? ''}';
      if (status == 'active') {
        done = true;
        _poll?.cancel();
        context.go('/me/plan/${widget.subscriptionId}');
      } else if (status == 'expired' || status == 'slot_lost') {
        _poll?.cancel();
        setState(() {
          expired = true;
          failed = true;
        });
      } else if (status == 'payment_failed') {
        _poll?.cancel();
        setState(() => failed = true);
      }
    } catch (_) {}
  }

  /// POST /subscriptions/:id/pay {method}: new gateway session on the same hold.
  Future<void> _start() async {
    setState(() {
      starting = true;
      failed = false;
    });
    try {
      final r = await subApi.post('/subscriptions/${widget.subscriptionId}/pay', data: {'method': method});
      if (!mounted) return;
      if (r['paid'] == true) {
        done = true;
        context.go('/me/plan/${widget.subscriptionId}');
        return;
      }
      final u = '${r['checkoutUrl'] ?? ''}'.trim();
      setState(() {
        url = u.isEmpty ? null : u;
        starting = false;
      });
      _beginPoll();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        starting = false;
        failed = true;
        expired = e.code == 'hold_expired' || e.isSlotTaken;
      });
      if (expired) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(arMessage(e))));
    } catch (_) {
      if (mounted) {
        setState(() {
          starting = false;
          failed = true;
        });
      }
    }
  }

  void _leave() {
    _poll?.cancel();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _otherMethod() {
    setState(() => method = method == 'card' ? 'instapay' : 'card');
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final holdGone = expired || (hold != null && hold!.isBefore(DateTime.now()));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: Client.bg,
          body: SafeArea(
            child: Column(
              children: [
                ClientFlowHeader(title: _methodLabel(method), onBack: _leave),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      const Text('المبلغ', style: TextStyle(fontSize: 13, color: Client.muted)),
                      const Spacer(),
                      Text('${arFmt(widget.totalPiastres / 100)} ج.م', style: const TextStyle(fontFamily: T.mono, fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const ClientDivider(),
                Expanded(child: failed ? _errorBody(holdGone) : _payingBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _payingBody() {
    if (starting || url == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const InlineSpinner(size: 28),
              const SizedBox(height: 18),
              const Text('بنفتح صفحة الدفع…', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('مواعيدك محجوزة. لو الصفحة ما فتحتش هنرجّعك هنا بخيارات تانية.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.45, color: Client.muted)),
              if (hold != null) ...[
                const SizedBox(height: 16),
                HoldCountdown(deadline: hold!, label: MD.holdLabel, ar: true, onExpired: () => setState(() => expired = true)),
              ],
              const SizedBox(height: 16),
              ClientGhostButton(label: 'حدّثي حالة الدفع', onTap: _check),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            method == 'instapay' ? 'كمّلي الدفع بمحفظة الهاتف في الإطار اللي تحت.' : 'اكتبي بيانات البطاقة في الإطار الآمن اللي تحت.',
            style: const TextStyle(fontSize: 13, height: 1.45, color: Client.body),
          ),
        ),
        if (hold != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: HoldCountdown(deadline: hold!, label: MD.holdLabel, ar: true, onExpired: () => setState(() {
                expired = true;
                failed = true;
              })),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: PayCheckoutFrame(url: url!, lang: 'ar', onReturned: _check),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ClientGhostButton(label: 'حدّثي حالة الدفع', onTap: _check),
        ),
      ],
    );
  }

  Widget _errorBody(bool holdGone) {
    final other = method == 'card' ? 'محفظة الهاتف' : 'البطاقة';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(holdGone ? 'مهلة حجز المواعيد خلصت.' : 'الدفع ما كملش — ومواعيدك لسه محجوزة.', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 10),
          Text('بوابة الدفع بـ${_methodLabel(method)} ما ردّتش.', style: const TextStyle(fontSize: 14, height: 1.45, color: Client.body)),
          const SizedBox(height: 8),
          const Text('ما اتسحبش أي مبلغ.', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (holdGone)
            const Text('اختاري مواعيدك تاني من الأول.', style: TextStyle(fontSize: 13, height: 1.4, color: Client.muted, fontWeight: FontWeight.w600))
          else if (hold != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: HoldCountdown(deadline: hold!, label: MD.holdLabel, ar: true, onExpired: () => setState(() => expired = true)),
            ),
          const SizedBox(height: 8),
          const Text('غالبًا السبب من البنك أو الشبكة. لو اتكرر، كلّمينا ونحجزها لك بإيدينا.', style: TextStyle(fontSize: 12.5, height: 1.4, color: Client.muted)),
          const SizedBox(height: 24),
          if (holdGone)
            ClientPrimaryButton(label: 'اختاري مواعيدك', onTap: _leave)
          else ...[
            ClientPrimaryButton(label: 'جرّبي تاني بنفس الطريقة', onTap: _start),
            const SizedBox(height: 10),
            ClientGhostButton(label: 'جرّبي $other', onTap: _otherMethod),
            const SizedBox(height: 10),
            Material(
              color: Client.terracotta,
              child: InkWell(
                onTap: () => unawaited(launchUrl(Uri.parse(kSupportUrl), mode: LaunchMode.externalApplication)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 54),
                  alignment: Alignment.center,
                  child: const Text('كلّمي الدعم — بيردّوا في ٣٠ ثانية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.bg)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
