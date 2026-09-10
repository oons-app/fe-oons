import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/pay/pending_pay_route.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final b = Copy.of(lang)['bookings'] as Map;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              lang == 'ar' ? 'حجوزاتي' : 'Bookings',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Client.ink),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<List<BookingBundle>>>(
            future: Future.wait([ref.read(repoProvider).bookings('upcoming'), ref.read(repoProvider).bookings('past')]),
            builder: (context, countsSnap) {
              final upcoming = countsSnap.data != null ? countsSnap.data![0] : <BookingBundle>[];
              final past = countsSnap.data != null ? countsSnap.data![1] : <BookingBundle>[];
              return Column(
                children: [
                  ClientSegmentTabs(
                    left: lang == 'ar' ? 'الجاية · ${upcoming.length}' : 'Upcoming · ${upcoming.length}',
                    right: lang == 'ar' ? 'اللي فات · ${past.length}' : 'Past · ${past.length}',
                    index: tab,
                    onChanged: (i) => setState(() => tab = i),
                  ),
                  Expanded(child: _BookingList(scope: tab == 0 ? 'upcoming' : 'past', lang: lang, empty: '${b['empty']}')),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.scope, required this.lang, required this.empty});

  final String scope;
  final String lang;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<BookingBundle>>(
      future: ref.read(repoProvider).bookings(scope),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(20), child: Skel(width: 200, height: 28));
        }
        if (list.isEmpty) {
          return ClientEmptyState(
            title: scope == 'upcoming'
                ? (lang == 'ar' ? 'مفيش حجوزات جاية' : 'No upcoming bookings')
                : (lang == 'ar' ? 'مفيش حجوزات سابقة' : 'No past bookings'),
            body: scope == 'upcoming'
                ? (lang == 'ar' ? 'احجزي خدمة من الرئيسية ولما تتأكدي هتظهر هنا.' : 'Book a service from Home — confirmed visits show up here.')
                : empty,
            cta: lang == 'ar' ? 'تصفحي الخدمات' : 'Browse services',
            onCta: () => context.push('/browse/beauty'),
          );
        }
        return ListView(
          children: [
            ...list.map((x) => _BookingCard(bundle: x, lang: lang)),
            if (scope == 'past')
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Client.sand2, border: Border.all(color: Client.line, width: Client.rule)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'ar' ? 'حابة تكرري زيارة فاتت؟ خدي نفس المتخصصة ونفس الخدمة في دقايق.' : 'Want to repeat a past visit? Same pro, same service in minutes.',
                        style: const TextStyle(fontSize: 12.5, height: 1.55, color: Client.body),
                      ),
                      const SizedBox(height: 10),
                      ClientGhostButton(label: lang == 'ar' ? 'كرري زيارة' : 'Repeat a visit', onTap: () => context.push('/browse/beauty')),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.bundle, required this.lang});

  final BookingBundle bundle;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final b = bundle.booking;
    final p = bundle.provider;
    final states = Copy.of(lang)['states'] as Map;
    final st = (states[b.status] as Map?) ?? {};
    final status = '${st['code'] ?? b.status}';
    final hint = '${st['hint'] ?? st['cta'] ?? ''}';
    return Material(
      color: Client.bg,
      child: InkWell(
        onTap: () => context.push('/booking/${b.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
                    child: Text(p?.initials.of(lang) ?? '', style: const TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.name(lang) ?? '', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Client.ink)),
                        Text(formatSlot(b.slotStart, lang), style: const TextStyle(fontSize: 12.5, color: Client.muted)),
                        Text(
                          [
                            b.serviceName.of(lang),
                            if (b.status != 'pending_payment' && paymentMethodLabel(b.paymentMethod, lang).isNotEmpty)
                              paymentMethodLabel(b.paymentMethod, lang),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12.5, color: Client.muted),
                        ),
                      ],
                    ),
                  ),
                  ClientStatusChip(status, olive: b.status == 'paid' || b.status == 'released'),
                ],
              ),
              if (hint.isNotEmpty && hint != 'null') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(color: Client.sand2, border: Border.all(color: Client.line, width: Client.rule)),
                  child: Text(hint, style: const TextStyle(fontSize: 12.5, height: 1.55, color: Client.body)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  BookingBundle? data;
  Timer? poll;
  bool releasing = false;

  @override
  void initState() {
    super.initState();
    _load();
    poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await ref.read(repoProvider).booking(widget.bookingId);
    if (!mounted) return;
    setState(() => data = b);
    if (!b.poll) poll?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final timeline = t['timeline'] as Map;
    final escrow = t['escrow'] as Map;
    final states = t['states'] as Map;
    final b = data?.booking;
    final p = data?.provider;
    if (b == null) {
      return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
    }
    final st = (states[b.status] as Map?) ?? {'code': b.status, 'cta': ''};
    final rateCopy = Copy.of(lang)['rate'] as Map;
    final alarm = ['disputed', 'cancelled_client', 'cancelled_provider'].contains(b.status);
    final pending = b.status == 'pending_payment';
    final good = ['completed', 'refunded', 'paid', 'in_progress'].contains(b.status);
    final bg = alarm ? T.danger : pending ? Client.warnTint : good ? Client.oliveTint : Client.sand;
    final fg = alarm ? Client.bg : Client.ink;
    final chip = alarm ? Client.bg : pending ? Client.terracotta : good ? Client.olive : Client.plum;

    void go() {
      switch (b.status) {
        case 'pending_payment':
          context.go(pendingPayRoute(b.id, paymentMethod: b.paymentMethod, fawryCode: b.fawryCode));
        case 'completed':
          context.go('/rate/${b.id}');
        case 'cancelled_provider':
          context.go('/pcancel/${b.id}');
        case 'disputed':
          context.go('/dispute/${b.id}');
        case 'paid':
        case 'on_the_way':
        case 'in_progress':
        case 'rescheduled':
          context.go('/visit/${b.id}');
        default:
          context.go('/browse/beauty');
      }
    }

    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: b.ref, onBack: () => context.go('/bookings')),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bg,
                      border: const Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Face(id: p?.id, ini: p?.initials.of(lang) ?? '', size: 64, photo: p?.photo),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(glyphStatus(b.status), size: 16, color: chip),
                                const SizedBox(width: 8),
                                ClientKicker('${st['code']}', color: fg),
                              ]),
                              const SizedBox(height: 10),
                              Text(
                                p == null ? b.serviceName.of(lang) : '${formatSlot(b.slotStart, lang)} · ${p.name(lang)}',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, height: 1.18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${money(b.total, lang)} · ${escrow[b.escrow] ?? b.escrow}',
                                style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pending) ...[
                    Container(
                      width: double.infinity,
                      color: Client.warnTint,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Text(
                        '${st['hint'] ?? (lang == 'ar' ? 'الدفع ما اكتملش — الميعاد لسه محجوز. اضغطي عشان تكمّلي.' : 'Payment not finished — slot still held. Tap below to resume.')}',
                        style: const TextStyle(fontSize: 13, height: 1.45, color: Client.ink),
                      ),
                    ),
                    if (b.paymentHoldUntil != null || b.fawryExpiresAt != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Text(
                          () {
                            final hold = (b.paymentHoldUntil ?? b.fawryExpiresAt)!.toLocal();
                            final h = hold.hour.toString().padLeft(2, '0');
                            final m = hold.minute.toString().padLeft(2, '0');
                            return lang == 'ar' ? 'ينتهي الحجز غير المدفوع حوالي $h:$m' : 'Unpaid hold ends around $h:$m';
                          }(),
                          style: const TextStyle(fontSize: 12, color: Client.muted),
                        ),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: b.timeline.map((tl) {
                        final label = '${timeline[tl.key] ?? tl.key.replaceAll('_', ' ')}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(
                                glyphTimeline(tl.key),
                                size: 18,
                                color: tl.done ? Client.olive : const Color(0xFFA79FA5),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: tl.done ? FontWeight.w800 : FontWeight.w500,
                                    color: tl.done ? Client.ink : const Color(0xFFA79FA5),
                                  ),
                                ),
                              ),
                              Text(
                                tl.at == null ? '—' : DateFormat.Hm().format(tl.at!.toLocal()),
                                style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Client.muted),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _kv(Icons.person_outline, lang == 'ar' ? 'المتخصصة' : 'Professional', p?.name(lang) ?? '',
                            trailing: Face(id: p?.id, ini: p?.initials.of(lang) ?? '', size: 28, photo: p?.photo)),
                        _kv(Icons.payments_outlined, lang == 'ar' ? 'المبلغ' : 'Amount', money(b.total, lang)),
                        if (paymentMethodLabel(b.paymentMethod, lang).isNotEmpty)
                          _kv(
                            Icons.credit_card_outlined,
                            lang == 'ar' ? 'طريقة الدفع' : 'Payment method',
                            paymentMethodLabel(b.paymentMethod, lang),
                          ),
                        _kv(Icons.lock_outline, lang == 'ar' ? 'الحفظ' : 'Escrow', '${escrow[b.escrow] ?? b.escrow}'),
                        _kv(Icons.verified_user_outlined, lang == 'ar' ? 'الضمان' : 'Guarantee', lang == 'ar' ? 'صندوق أمانة · شغال' : 'Amana fund · active'),
                        if (b.address != null)
                          _kv(
                            Icons.place_outlined,
                            lang == 'ar' ? 'العنوان' : 'Address',
                            [
                              b.address!.line1.of(lang),
                              b.address!.city.of(lang),
                              if (b.address!.reachNotes.of(lang).trim().isNotEmpty) b.address!.reachNotes.of(lang),
                            ].join('\n'),
                          ),
                        if (b.notes != null && b.notes!.trim().isNotEmpty)
                          _kv(Icons.notes_outlined, lang == 'ar' ? 'التعليمات' : 'Notes', b.notes!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ClientPrimaryButton(label: '${st['cta']}', onTap: go),
                  if (b.canReleasePay) ...[
                    const SizedBox(height: 8),
                    ClientPrimaryButton(
                      label: '${rateCopy['releaseCta']}',
                      enabled: !releasing,
                      onTap: () async {
                        setState(() => releasing = true);
                        try {
                          final updated = await ref.read(repoProvider).releasePayment(b.id);
                          if (!mounted) return;
                          setState(() {
                            data = updated;
                            releasing = false;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => releasing = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${rateCopy['releaseNote']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4), textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: 4),
                  ClientGhostButton(label: lang == 'ar' ? 'الرئيسية' : 'Back to home', onTap: () => context.go('/home')),
                  if (b.status == 'paid')
                    TextButton(
                      onPressed: () => context.push('/cancel/${b.id}'),
                      child: Text(lang == 'ar' ? 'الغي الزيارة' : 'Cancel visit', style: const TextStyle(color: T.danger)),
                    ),
                  if (b.status == 'completed')
                    TextButton(
                      onPressed: () => context.push('/dispute/${b.id}'),
                      child: Text('${(Copy.of(lang)['dispute'] as Map)['cta']}', style: const TextStyle(color: T.danger)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(IconData icon, String k, String v, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Client.plum),
          const SizedBox(width: 10),
          SizedBox(width: 88, child: ClientKicker(k)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
