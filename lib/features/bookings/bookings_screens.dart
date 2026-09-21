import 'package:oons/core/icons/ons_icons.dart';
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
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/features/system/progress.dart';
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
                    left: '${b['upcoming']} · ${upcoming.length}',
                    right: '${b['past']} · ${past.length}',
                    index: tab,
                    onChanged: (i) => setState(() => tab = i),
                  ),
                  Expanded(
                    child: _BookingList(
                      scope: tab == 0 ? 'upcoming' : 'past',
                      lang: lang,
                      lastPast: past.isEmpty ? null : (past.toList()..sort((a, c) => c.booking.slotStart.compareTo(a.booking.slotStart))).first,
                    ),
                  ),
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
  const _BookingList({required this.scope, required this.lang, this.lastPast});

  final String scope;
  final String lang;
  final BookingBundle? lastPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<BookingBundle>>(
      future: ref.read(repoProvider).bookings(scope),
      builder: (context, snap) {
        final list = snap.data ?? [];
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(20), child: Skel(width: 200, height: 28));
        }
        if (list.isEmpty && scope == 'upcoming') {
          final last = lastPast;
          final pid = last?.booking.providerId ?? last?.provider?.id;
          return OnsEmpty.noUpcoming(
            lang: lang,
            lastProvider: last?.provider?.name(lang),
            lastDate: last == null ? null : DateFormat('d MMMM', lang).format(last.booking.slotStart.toLocal()),
            onRepeat: (last == null || pid == null || pid.isEmpty) ? null : () => context.push('/book/$pid'),
            onBrowse: () => context.push('/browse/beauty'),
          );
        }
        if (list.isEmpty) {
          return OnsEmpty.noPast(lang: lang, onBrowse: () => context.push('/browse/beauty'));
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
      final ec = Copy.of(lang)['empty'] as Map;
      return OnsBusyPage(caption: '${ec['loadingBooking']}');
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
                                OnsIcon(_statusIcon(b.status), size: 16, color: chip),
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
                        child: HoldCountdown(
                          deadline: (b.paymentHoldUntil ?? b.fawryExpiresAt)!,
                          label: Copy.bookFlow(lang)['holdLabel'] ?? '',
                          ar: lang == 'ar',
                        ),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        JourneyStages(
                          stages: [
                            '${timeline['booked']}',
                            '${timeline['confirmed']}',
                            '${timeline['on_the_way']}',
                            '${timeline['checked_in']}',
                            '${timeline['checked_out']}',
                          ],
                          current: _journeyCurrent(b.status),
                        ),
                        const SizedBox(height: 16),
                        ...b.timeline.map((tl) {
                        final label = '${timeline[tl.key] ?? tl.key.replaceAll('_', ' ')}';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              OnsIcon(
                                _timelineIcon(tl.key),
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
                      }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _kv('user', lang == 'ar' ? 'المتخصصة' : 'Professional', p?.name(lang) ?? '',
                            trailing: Face(id: p?.id, ini: p?.initials.of(lang) ?? '', size: 28, photo: p?.photo)),
                        _kv('wallet', lang == 'ar' ? 'المبلغ' : 'Amount', money(b.total, lang)),
                        if (paymentMethodLabel(b.paymentMethod, lang).isNotEmpty)
                          _kv(
                            'card',
                            lang == 'ar' ? 'طريقة الدفع' : 'Payment method',
                            paymentMethodLabel(b.paymentMethod, lang),
                          ),
                        _kv('shield', lang == 'ar' ? 'الحفظ' : 'Escrow', '${escrow[b.escrow] ?? b.escrow}'),
                        _kv('shieldCheck', lang == 'ar' ? 'الضمان' : 'Guarantee', lang == 'ar' ? 'صندوق أمانة · شغال' : 'Amana fund · active'),
                        if (b.address != null)
                          _kv(
                            'pin',
                            lang == 'ar' ? 'العنوان' : 'Address',
                            [
                              b.address!.line1.of(lang),
                              b.address!.city.of(lang),
                              if (b.address!.reachNotes.of(lang).trim().isNotEmpty) b.address!.reachNotes.of(lang),
                            ].join('\n'),
                          ),
                        if (b.notes != null && b.notes!.trim().isNotEmpty)
                          _kv('edit', lang == 'ar' ? 'التعليمات' : 'Notes', b.notes!),
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rateCopy['releaseDone']}')));
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

  Widget _kv(String icon, String k, String v, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
      child: Row(
        children: [
          OnsIcon(icon, size: 16, color: Client.plum),
          const SizedBox(width: 10),
          SizedBox(width: 88, child: ClientKicker(k)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

int _journeyCurrent(String status) {
  switch (status) {
    case 'paid':
      return 1;
    case 'on_the_way':
      return 2;
    case 'in_progress':
    case 'at_door':
      return 3;
    case 'completed':
    case 'refunded':
    case 'released':
      return 4;
    default:
      return 0;
  }
}

String _statusIcon(String status) {
  switch (status) {
    case 'pending_payment':
      return 'clock';
    case 'paid':
      return 'shieldCheck';
    case 'on_the_way':
      return 'advance';
    case 'in_progress':
    case 'at_door':
      return 'pin';
    case 'completed':
      return 'check';
    case 'disputed':
      return 'alert';
    case 'refunded':
      return 'retry';
    case 'cancelled_client':
    case 'cancelled_provider':
      return 'close';
    default:
      return 'info';
  }
}

String _timelineIcon(String key) {
  switch (key) {
    case 'booked':
      return 'calendar';
    case 'confirmed':
      return 'check';
    case 'on_the_way':
      return 'advance';
    case 'checked_in':
      return 'pin';
    case 'checked_out':
      return 'check';
    default:
      return 'clock';
  }
}
