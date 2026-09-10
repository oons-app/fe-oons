import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/pay/pay_checkout_frame.dart';
import 'package:oons/l10n/copy.dart';

/// Dedicated frame per payment method: card / mobile wallet / Fawry (legacy).
/// Closing the window (back / leave / tab hide) keeps the booking pending until hold expires.
class PaymentFrameScreen extends ConsumerStatefulWidget {
  const PaymentFrameScreen({
    super.key,
    required this.bookingId,
    required this.method,
  });

  final String bookingId;
  final String method;

  @override
  ConsumerState<PaymentFrameScreen> createState() => _PaymentFrameScreenState();
}

class _PaymentFrameScreenState extends ConsumerState<PaymentFrameScreen> with WidgetsBindingObserver {
  BookingBundle? data;
  String? checkoutUrl;
  String? error;
  bool starting = true;
  bool finishedPaid = false;
  bool abandoning = false;
  Timer? poll;

  String get method {
    final m = widget.method.toLowerCase().trim();
    if (m == 'instapay' || m == 'wallet') return 'instapay';
    if (m == 'fawry' || m == 'kiosk') return 'fawry';
    return 'card';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    // Fire-and-forget: tab closed / route disposed before pay completed.
    if (!finishedPaid && !abandoning) {
      unawaited(_abandonSilent());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mobile: app backgrounded / killed while Paymob sheet open.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (!finishedPaid) unawaited(_abandonSilent());
    }
    if (state == AppLifecycleState.resumed && !finishedPaid && !starting) {
      unawaited(_check());
    }
  }

  Future<void> _abandonSilent() async {
    if (abandoning || finishedPaid) return;
    abandoning = true;
    try {
      await ref.read(repoProvider).abandonPay(widget.bookingId, method);
    } catch (_) {}
  }

  Future<void> _leaveUnpaid() async {
    if (finishedPaid) {
      if (mounted) context.go('/booking/${widget.bookingId}');
      return;
    }
    await _abandonSilent();
    if (!mounted) return;
    final hold = data?.booking.paymentHoldUntil ?? data?.booking.fawryExpiresAt;
    final lang = langOf(ref);
    final msg = lang == 'ar'
        ? (hold != null
            ? 'الدفع ما اكتملش. الميعاد محجوز لحد ${_holdLabel(hold, lang)} — تقدري تكمّلي من الحجوزات.'
            : 'الدفع ما اكتملش. الميعاد لسه محجوز — كمّلي من الحجوزات.')
        : (hold != null
            ? 'Payment not finished. Slot held until ${_holdLabel(hold, lang)} — resume from Bookings.'
            : 'Payment not finished. Slot still held — resume from Bookings.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    context.go('/booking/${widget.bookingId}');
  }

  String _holdLabel(DateTime hold, String lang) {
    final local = hold.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _start() async {
    setState(() {
      starting = true;
      error = null;
      abandoning = false;
    });
    try {
      unawaited(AppAnalytics.addPaymentInfo(
        bookingId: widget.bookingId,
        method: method,
        value: data?.booking.total != null ? data!.booking.total / 100.0 : null,
      ));
      final launch = await ref.read(repoProvider).pay(widget.bookingId, method);
      if (!mounted) return;
      if (launch.bundle.booking.status == 'paid') {
        finishedPaid = true;
        context.go('/confirmed/${launch.bundle.booking.id}');
        return;
      }
      if (launch.bundle.booking.status == 'cancelled_client') {
        setState(() {
          starting = false;
          error = langOf(ref) == 'ar'
              ? 'انتهى وقت الحجز غير المدفوع. احجزي الميعاد تاني.'
              : 'The unpaid hold expired. Book the slot again.';
          data = launch.bundle;
        });
        return;
      }
      setState(() {
        data = launch.bundle;
        checkoutUrl = launch.checkoutUrl;
        starting = false;
      });
      _beginPoll();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isPayFail) {
        context.go('/payfail');
        return;
      }
      if (e.isOffline) {
        context.go('/offline');
        return;
      }
      setState(() {
        starting = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        starting = false;
        error = 'error';
      });
    }
  }

  void _beginPoll() {
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final b = await ref.read(repoProvider).checkPay(widget.bookingId);
      if (!mounted) return;
      setState(() => data = b);
      if (b.booking.status == 'paid') {
        finishedPaid = true;
        poll?.cancel();
        await ref.read(repoProvider).ensurePurchaseTracked(b, method);
        if (!mounted) return;
        context.go('/confirmed/${b.booking.id}');
        return;
      }
      if (b.booking.status == 'cancelled_client') {
        poll?.cancel();
        setState(() {
          error = langOf(ref) == 'ar'
              ? 'انتهى وقت الحجز غير المدفوع. احجزي الميعاد تاني.'
              : 'The unpaid hold expired. Book the slot again.';
        });
      }
    } catch (_) {}
  }

  String _title(String lang, Map co) {
    switch (method) {
      case 'instapay':
        return '${co['instapay']}';
      case 'fawry':
        return '${co['fawry']}';
      default:
        return '${co['card']}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final co = t['co'] as Map;
    final f = t['fawry'] as Map;
    final b = data?.booking;
    final hasFawryCode = b?.fawryCode != null && b!.fawryCode!.isNotEmpty;
    final showIframe = checkoutUrl != null && checkoutUrl!.isNotEmpty;
    final hold = b?.paymentHoldUntil ?? b?.fawryExpiresAt;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveUnpaid());
      },
      child: Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ClientBackHeader(
                title: _title(lang, co),
                onBack: () => unawaited(_leaveUnpaid()),
              ),
              if (b != null && b.status == 'pending_payment')
                Container(
                  width: double.infinity,
                  color: Client.warnTint,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    hold != null
                        ? (lang == 'ar'
                            ? 'لو قفلتِ النافذة، الحجز يفضل مستني الدفع لحد ${_holdLabel(hold, lang)}.'
                            : 'If you close this window, the booking stays unpaid until ${_holdLabel(hold, lang)}.')
                        : (lang == 'ar'
                            ? 'لو قفلتِ النافذة، تقدري ترجعي تكمّلي من الحجوزات.'
                            : 'If you close this window, resume anytime from Bookings.'),
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: Client.ink),
                  ),
                ),
              if (b != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        lang == 'ar' ? 'المبلغ' : 'Amount',
                        style: const TextStyle(fontSize: 13, color: Client.muted),
                      ),
                      const Spacer(),
                      Text(
                        money(b.total, lang),
                        style: const TextStyle(fontFamily: T.mono, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              const ClientDivider(),
              Expanded(
                child: starting
                    ? const Center(child: CircularProgressIndicator(color: Client.plum))
                    : error != null
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'ar' ? 'ما قدرناش نكمل الدفع' : 'Could not complete payment',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  error == 'error'
                                      ? (lang == 'ar' ? 'جرّبي تاني بعد شوية.' : 'Please try again in a moment.')
                                      : error!,
                                  style: const TextStyle(fontSize: 14, height: 1.45, color: Client.body),
                                ),
                                const Spacer(),
                                if (data?.booking.status == 'cancelled_client')
                                  ClientPrimaryButton(
                                    label: lang == 'ar' ? 'ارجعي للحجوزات' : 'Back to bookings',
                                    onTap: () => context.go('/bookings'),
                                  )
                                else
                                  ClientPrimaryButton(
                                    label: lang == 'ar' ? 'حاولي تاني' : 'Try again',
                                    onTap: _start,
                                  ),
                              ],
                            ),
                          )
                        : showIframe
                            ? Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                                    child: Text(
                                      method == 'instapay'
                                          ? (lang == 'ar'
                                              ? 'كمّلي دفع محفظة الموبايل في الإطار تحت. لو قفلتِ، الحجز يفضل مستني الدفع.'
                                              : 'Complete mobile wallet payment below. Closing keeps the booking pending.')
                                          : method == 'fawry'
                                              ? (lang == 'ar'
                                                  ? 'اتبعِي خطوات فوري في الإطار، أو ادفعِي بالكود لو ظهر.'
                                                  : 'Follow Fawry below, or pay with the code if shown.')
                                              : (lang == 'ar'
                                                  ? 'أدخلي بيانات البطاقة في الإطار الآمن. قفل النافذة مش بيلغي الحجز فوراً.'
                                                  : 'Enter card details in the secure frame. Closing does not cancel immediately.'),
                                      style: const TextStyle(fontSize: 13, height: 1.45, color: Client.body),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                      child: PayCheckoutFrame(url: checkoutUrl!, lang: lang),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                    child: ClientGhostButton(
                                      label: lang == 'ar' ? 'حدّث حالة الدفع' : 'Refresh payment status',
                                      onTap: _check,
                                    ),
                                  ),
                                  if (kIsWeb)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                      child: TextButton(
                                        onPressed: () => unawaited(_leaveUnpaid()),
                                        child: Text(
                                          lang == 'ar' ? 'قفلتِ الدفع — رجّعيني للحجز' : 'I closed payment — back to booking',
                                          style: const TextStyle(color: Client.muted, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : method == 'fawry' || hasFawryCode
                                ? _FawryFrameBody(
                                    booking: b,
                                    copy: f,
                                    lang: lang,
                                    onRefresh: _check,
                                    onCancel: () => context.push('/cancel/${widget.bookingId}'),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang == 'ar' ? 'بنتأكد من الدفع' : 'Confirming payment',
                                          style: Theme.of(context).textTheme.headlineMedium,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          lang == 'ar'
                                              ? 'بنحدّث الحالة تلقائي. لو قفلتِ صفحة بايموب، ارجعي هنا أو من الحجوزات.'
                                              : 'We refresh automatically. If you closed Paymob, return here or resume from Bookings.',
                                          style: const TextStyle(fontSize: 14, height: 1.45, color: Client.body),
                                        ),
                                        const Spacer(),
                                        ClientGhostButton(
                                          label: lang == 'ar' ? 'حدّث الآن' : 'Refresh now',
                                          onTap: _check,
                                        ),
                                        TextButton(
                                          onPressed: () => unawaited(_leaveUnpaid()),
                                          child: Text(
                                            lang == 'ar' ? 'كمّلي بعدين' : 'Finish later',
                                            style: const TextStyle(color: Client.muted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FawryFrameBody extends StatelessWidget {
  const _FawryFrameBody({
    required this.booking,
    required this.copy,
    required this.lang,
    required this.onRefresh,
    required this.onCancel,
  });

  final Booking? booking;
  final Map copy;
  final String lang;
  final Future<void> Function() onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final left = booking?.fawryExpiresAt?.difference(DateTime.now()) ??
        booking?.paymentHoldUntil?.difference(DateTime.now()) ??
        Duration.zero;
    String cd() {
      final s = left.isNegative ? Duration.zero : left;
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(s.inHours)}:${two(s.inMinutes % 60)}:${two(s.inSeconds % 60)}';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.warnTint),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, color: Client.terracotta),
            const SizedBox(width: 8),
            ClientKicker('${copy['badge']}', color: Client.ink),
          ]),
        ),
        const SizedBox(height: 16),
        Text('${copy['title']}', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text('${copy['body']}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClientKicker('${copy['codeLabel']}'),
                    const SizedBox(height: 8),
                    Ltr(
                      child: Text(
                        (booking?.fawryCode ?? '--------').split('').join(' '),
                        style: const TextStyle(fontFamily: T.mono, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const ClientDivider(),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClientKicker('${copy['expires']}'),
                    const Spacer(),
                    Text(cd(), style: const TextStyle(fontFamily: T.mono, fontSize: 16, fontWeight: FontWeight.w500, color: Client.terracotta)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...['s1', 's2', 's3'].asMap().entries.map(
              (e) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.bg),
                child: Row(
                  children: [
                    Text('${e.key + 1}'.padLeft(2, '0'), style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.plum)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${copy[e.value]}', style: const TextStyle(fontSize: 13, height: 1.45))),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 24),
        ClientGhostButton(label: '${copy['paid']}', onTap: onRefresh),
        TextButton(
          onPressed: onCancel,
          child: Text('${copy['cancel']}', style: const TextStyle(color: Client.muted)),
        ),
      ],
    );
  }
}
