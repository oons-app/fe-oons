import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/book/book_draft.dart';
import 'package:oons/features/book/book_widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/l10n/copy.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  BookingBundle? data;
  String method = 'card';
  bool _checkoutTracked = false;
  bool _refundOpen = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).booking(widget.bookingId).then((b) {
      if (mounted) {
        setState(() => data = b);
        if (!_checkoutTracked) {
          _checkoutTracked = true;
          unawaited(AppAnalytics.checkoutStarted(
            bookingId: b.booking.id,
            value: b.booking.amountDue(processingFee: b.processingFeeFor('card')) / 100.0,
          ));
        }
      }
    });
    ref.read(sessionProvider.notifier).refreshMe();
  }

  Future<void> _backToDraft() async {
    if (_leaving) return;
    _leaving = true;
    final b = data?.booking;
    if (b != null && b.status == 'pending_payment') {
      try {
        await ref.read(repoProvider).cancel(b.id, 'none');
      } catch (_) {}
    }
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    final pid = b?.providerId ?? data?.provider?.id;
    if (pid != null) {
      context.go('/book/$pid');
    } else {
      context.go('/bookings');
    }
  }

  int _fee() {
    final b = data?.booking;
    if (b == null) return 0;
    if (b.paymentFeeAmount > 0) return b.paymentFeeAmount;
    return data!.processingFeeFor(method);
  }

  int _due() {
    final b = data?.booking;
    if (b == null) return 0;
    return b.amountDue(processingFee: _fee());
  }

  String _hairMod(String? hair, Map<String, String> bf) {
    switch (hair) {
      case 'short':
        return bf['hairShort'] ?? '';
      case 'long':
        return bf['hairLong'] ?? '';
      case 'medium':
        return bf['hairMedium'] ?? '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final bf = Copy.bookFlow(lang);
    final t = Copy.of(lang);
    final co = t['co'] as Map;
    final online = ref.watch(sessionProvider).online;
    final user = ref.watch(sessionProvider).user;
    final needsId = user?.needsIdentityCompletion ?? false;
    final steps = [bf['step1'] ?? '', bf['step2'] ?? '', bf['step3'] ?? ''];
    if (data == null) {
      return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
    }
    final b = data!.booking;
    final due = _due();
    final fee = _fee();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_backToDraft());
      },
      child: Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ClientFlowHeader(title: bf['title3'] ?? '', onBack: () => unawaited(_backToDraft())),
              ClientBookingStepper(
                step: 3,
                labels: steps,
                cartReady: true,
                onSegmentTap: (n) {
                  if (n < 3) unawaited(_backToDraft());
                },
              ),
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookMonoKicker(bf['cartHeading'] ?? ''),
                          const SizedBox(height: 12),
                          if (b.items.isNotEmpty)
                            ...b.items.map((it) {
                              final qty = it.count < 1 ? 1 : it.count;
                              final mod = _hairMod(it.hairLength, bf);
                              final label = qty > 1
                                  ? '${it.serviceName.of(lang)} ×${digits(qty, ar: lang == 'ar')}${mod.isNotEmpty ? ' · $mod' : ''}'
                                  : (mod.isNotEmpty ? '${it.serviceName.of(lang)} · $mod' : it.serviceName.of(lang));
                              return _moneyRow(label, money(it.lineTotal, lang));
                            })
                          else
                            ...b.lineItems.where((l) => l.key == 'service').map((l) => _moneyRow(localizeAreaSlugs(l.label.of(lang), lang), money(l.amount, lang))),
                          ...b.lineItems.where((l) => l.key != null && l.key != 'service').map((l) {
                            final label = l.key == 'tools' ? (bf['toolsLine'] ?? l.label.of(lang)) : localizeAreaSlugs(l.label.of(lang), lang);
                            return _moneyRow(label, money(l.amount, lang));
                          }),
                          if (fee > 0) _moneyRow(bf['feeLine'] ?? '', money(fee, lang), muted: true),
                          const SizedBox(height: 10),
                          const ClientDivider(),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bf['finalPrice'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                    Text(bf['finalSub'] ?? '', style: const TextStyle(fontSize: 11.5, height: 1.35, color: Client.muted)),
                                  ],
                                ),
                              ),
                              Text(money(due, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 21, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const ClientDivider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _recapRow(bf['when'] ?? '', formatSlot(b.slotStart, lang), bf['edit'] ?? '', () => unawaited(_backToDraft())),
                          _recapRow(
                            bf['where'] ?? '',
                            [
                              if (b.address != null) b.address!.label.of(lang),
                              if (b.address != null) b.address!.line1.of(lang),
                              if (b.address != null) areaName(b.address!.area, lang),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            bf['edit'] ?? '',
                            () => unawaited(_backToDraft()),
                          ),
                        ],
                      ),
                    ),
                    const ClientDivider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookMonoKicker(bf['payWith'] ?? ''),
                          const SizedBox(height: 12),
                          BookPayMethodTile(
                            selected: method == 'card',
                            card: true,
                            title: '${co['card']}',
                            note: '${co['cardNote']}',
                            onTap: () => setState(() => method = 'card'),
                          ),
                          BookPayMethodTile(
                            selected: method == 'instapay',
                            card: false,
                            title: '${co['instapay']}',
                            note: '${co['instapayNote']}',
                            onTap: () => setState(() => method = 'instapay'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: Client.olive,
                      padding: const EdgeInsets.all(16),
                      child: Text(bf['safety'] ?? '', style: const TextStyle(color: Client.bg, fontSize: 14, height: 1.45)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            button: true,
                            expanded: _refundOpen,
                            child: InkWell(
                              onTap: () => setState(() => _refundOpen = !_refundOpen),
                              child: Row(
                                children: [
                                  Text(_refundOpen ? '−' : '+', style: const TextStyle(fontFamily: T.mono, fontSize: 16, color: Client.muted)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(bf['refundTitle'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                                ],
                              ),
                            ),
                          ),
                          if (_refundOpen) ...[
                            const SizedBox(height: 8),
                            ...(t['policy'] as List).map((row) {
                              final r = row as Map;
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 78, child: Text('${r['when']}', style: const TextStyle(fontFamily: T.mono, fontSize: 11))),
                                    Expanded(child: Text('${r['what']}', style: const TextStyle(fontSize: 13, height: 1.4))),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => openLegal(context, 'cancellation'),
                              child: Text(
                                '${co['policyFull']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                              ),
                            ),
                          ],
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (needsId)
                InkWell(
                  onTap: () => context.push('/me/identity'),
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFFFF3CD),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      lang == 'ar'
                          ? 'لازم تكملي بياناتك وترفعي صورة البطاقة قبل تأكيد الحجز — اضغطي هنا'
                          : 'Complete your ID before confirming — tap here',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF533F03), height: 1.4),
                    ),
                  ),
                ),
              ClientStickyBar(
                label: bf['dueNow'] ?? '',
                sub: bf['barFeesIn'],
                price: money(due, lang),
                cta: '${bf['ctaPayNow'] ?? ''} · ${method == 'card' ? co['card'] : co['instapay']}',
                enabled: online && !needsId,
                onTap: () {
                  if (!online) return;
                  tapSuccess();
                  unawaited(AppAnalytics.addPaymentInfo(bookingId: b.id, method: method, value: due / 100.0));
                  context.push('/pay/${b.id}/$method');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moneyRow(String label, String amount, {bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, height: 1.35, color: muted ? Client.muted : Client.body))),
          Text(amount, style: TextStyle(fontFamily: T.mono, fontSize: 13, color: muted ? Client.muted : Client.ink)),
        ],
      ),
    );
  }

  Widget _recapRow(String kicker, String value, String edit, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 52, child: BookMonoKicker(kicker)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600))),
          Semantics(
            button: true,
            label: edit,
            child: InkWell(
              onTap: onEdit,
              child: Text(edit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum)),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmedScreen extends ConsumerWidget {
  const ConfirmedScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final bf = Copy.bookFlow(lang);
    return FutureBuilder<BookingBundle>(
      future: ref.read(repoProvider).booking(bookingId),
      builder: (context, snap) {
        final bundle = snap.data;
        final b = bundle?.booking;
        final p = bundle?.provider;
        final first = (p?.firstName.of(lang) ?? '').trim();
        final title = (bf['doneTitle'] ?? '').replaceAll('{name}', first.isEmpty ? (lang == 'ar' ? 'المتخصصة' : 'She') : first);
        final due = b == null ? 0 : b.amountDue(processingFee: bundle?.processingFeeFor(b.paymentMethod ?? 'card') ?? 0);
        final where = [
          if (b?.address != null) b!.address!.label.of(lang),
          if (b?.address != null) areaName(b!.address!.area, lang),
        ].where((e) => e.isNotEmpty).join(' · ');
        return Scaffold(
          backgroundColor: Client.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 96,
                    width: double.infinity,
                    color: Client.olive,
                    padding: const EdgeInsets.all(14),
                    alignment: AlignmentDirectional.bottomStart,
                    child: BookMonoKicker(bf['doneKicker'] ?? '', color: Client.bg),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: Client.ink)),
                  const SizedBox(height: 10),
                  Text(bf['doneBody'] ?? '', style: const TextStyle(fontSize: 15, height: 1.5, color: Client.body)),
                  const SizedBox(height: 18),
                  if (b != null) ...[
                    _row(bf['ref'] ?? '', b.ref),
                    _row(bf['whenRow'] ?? '', formatSlot(b.slotStart, lang)),
                    _row(bf['whereRow'] ?? '', where),
                    _row(bf['paidRow'] ?? '', '${money(due, lang)} · ${bf['heldTag'] ?? ''}'),
                  ],
                  if (b?.idUploadDeadline != null && ref.watch(sessionProvider).user?.hasIdPhoto != true) ...[
                    const SizedBox(height: 16),
                    ClientIDUploadBanner(deadline: b!.idUploadDeadline!, lang: lang, onTap: () => context.push('/me/identity')),
                  ],
                  const Spacer(),
                  ClientPrimaryButton(
                    label: bf['seeVisit'] ?? '',
                    onTap: () {
                      if (context.mounted) context.go('/visit/$bookingId');
                    },
                  ),
                  const SizedBox(height: 8),
                  ClientGhostButton(
                    label: bf['calendar'] ?? '',
                    onTap: b == null
                        ? null
                        : () {
                            final loc = [b.address?.line1.of(lang) ?? '', b.address?.city.of(lang) ?? ''].where((e) => e.isNotEmpty).join(', ');
                            unawaited(launchUrl(
                              googleCalendarUri(
                                start: b.slotStart,
                                durationMin: b.durationMin,
                                title: '${p?.name(lang) ?? ''} · ${b.serviceName.of(lang)}',
                                location: loc,
                              ),
                              mode: LaunchMode.externalApplication,
                            ));
                          },
                  ),
                  const SizedBox(height: 8),
                  ClientGhostButton(
                    label: bf['bookAgain'] ?? '',
                    onTap: () {
                      final pid = b?.providerId ?? p?.id;
                      if (pid != null) unawaited(clearBookDraft(pid));
                      if (pid != null) {
                        context.go('/book/$pid');
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
      child: Row(
        children: [
          SizedBox(width: 96, child: BookMonoKicker(k)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
