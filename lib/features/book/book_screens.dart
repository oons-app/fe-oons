import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/features/me/me_screens.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, required this.providerId, this.itemId});
  final String providerId;
  final String? itemId;
  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _GuestDraft {
  _GuestDraft({required this.name});
  final TextEditingController name;
  final TextEditingController phone = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final Map<String, int> serviceCounts = {};

  int totalSelected() => serviceCounts.values.fold(0, (a, b) => a + b);

  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
  }
}

class _BookScreenState extends ConsumerState<BookScreen> {
  ProviderP? p;
  int day = 1;
  int slot = 2;
  final notes = TextEditingController();
  final homeSqm = TextEditingController();
  final coupon = TextEditingController();
  String? instructionId;
  bool saveInstr = false;
  bool _couponBusy = false;
  bool _couponOk = false;
  String? _appliedCouponCode;
  int _couponDiscount = 0;
  String? _couponMessage;
  List<Map<String, dynamic>> days = [];
  bool busy = false;
  String? addressId;
  String? formError;
  final guests = <_GuestDraft>[];
  bool _flowStarted = false;
  bool _notesTracked = false;
  String? _lastServiceTracked;
  int? _lastSlotTracked;
  String? _lastAddressTracked;

  @override
  void dispose() {
    notes.removeListener(_onNotesChanged);
    notes.dispose();
    homeSqm.dispose();
    coupon.dispose();
    for (final g in guests) {
      g.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    notes.addListener(_onNotesChanged);
    _load();
  }

  void _onNotesChanged() {
    if (_notesTracked || notes.text.trim().isEmpty || p == null) return;
    _notesTracked = true;
    unawaited(AppAnalytics.bookingNotesAdded(providerId: p!.id));
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final lang = langOf(ref);
    await ref.read(sessionProvider.notifier).refreshMe();
    final boot = await repo.bookBootstrap(widget.providerId);
    final prov = boot.provider;
    final av = boot.days;
    if (!mounted) return;
    if (!_flowStarted) {
      _flowStarted = true;
      unawaited(AppAnalytics.beginCheckout(
        providerId: prov.id,
        serviceItemId: widget.itemId,
        value: prov.priceFrom / 100,
        entryPoint: AppAnalytics.bookingEntryPoint,
        providerName: prov.name('en'),
        serviceName: prov.service,
      ));
    }
    setState(() {
      p = prov;
      days = av;
      guests.clear();
      final you = _GuestDraft(name: TextEditingController(text: lang == 'ar' ? 'إنتي' : 'You'));
      if (prov.items.isNotEmpty) {
        final pref = widget.itemId != null ? prov.items.where((e) => e.id == widget.itemId).toList() : const <ServiceItem>[];
        final first = pref.isNotEmpty ? pref.first : prov.items.first;
        you.serviceCounts[first.id] = 1;
        _lastServiceTracked = first.id;
        unawaited(AppAnalytics.bookingServiceSelected(
          providerId: prov.id,
          serviceItemId: first.id,
          value: first.price / 100,
          serviceName: first.name.en.isNotEmpty ? first.name.en : first.name.ar,
        ));
      }
      guests.add(you);
    });
  }

  DateTime slotTime() {
    if (days.isEmpty) return DateTime.now().toUtc();
    final dayMap = days[day];
    final slots = dayMap['slots'] as List;
    return availabilitySlotUtc(dayMap, slots[slot] as Map);
  }

  ServiceItem? _itemById(String id) {
    if (p == null) return null;
    for (final it in p!.items) {
      if (it.id == id) return it;
    }
    return null;
  }

  int _guestServicesMoney(_GuestDraft g) {
    var t = 0;
    for (final entry in g.serviceCounts.entries) {
      final it = _itemById(entry.key);
      if (it != null) t += it.price * entry.value;
    }
    return t;
  }

  bool get _hasCleaningItems => p?.items.any((e) => e.isCleaning) ?? false;

  Address? _selectedAddress() {
    final addrs = ref.read(sessionProvider).user?.addresses ?? const <Address>[];
    for (final a in addrs) {
      if (addressId != null && a.id == addressId) return a;
    }
    if (addrs.isEmpty) return null;
    final defaults = addrs.where((a) => a.isDefault);
    return defaults.isEmpty ? addrs.first : defaults.first;
  }

  Future<void> _applyCoupon() async {
    final code = coupon.text.trim();
    final lang = langOf(ref);
    if (code.isEmpty || p == null || busy) return;
    setState(() {
      _couponBusy = true;
      _couponMessage = null;
    });
    int servicesTotal = 0;
    for (final g in guests) {
      servicesTotal += _guestServicesMoney(g);
    }
    final categoryIds = <String>{};
    for (final g in guests) {
      for (final id in g.serviceCounts.keys) {
        final it = _itemById(id);
        if (it?.categoryId != null && it!.categoryId!.isNotEmpty) categoryIds.add(it.categoryId!);
      }
    }
    try {
      final r = await ref.read(repoProvider).validateCoupon(
            code: code,
            providerId: p!.id,
            serviceTotal: servicesTotal,
            vertical: p!.service,
            area: _selectedAddress()?.area,
            categoryIds: categoryIds.toList(),
          );
      if (!mounted) return;
      final ok = r['ok'] == true;
      final label = r['label'];
      setState(() {
        _couponOk = ok;
        _appliedCouponCode = ok ? code : null;
        _couponDiscount = ok ? ((r['discount'] as num?)?.toInt() ?? 0) : 0;
        _couponMessage = ok
            ? (label is Map ? '${label[lang] ?? label['en'] ?? ''}' : (lang == 'ar' ? 'تم تطبيق الكوبون' : 'Coupon applied'))
            : ('${r['message'] ?? (lang == 'ar' ? 'الكوبون مش شغال' : 'This coupon isn\'t valid')}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _couponOk = false;
        _appliedCouponCode = null;
        _couponDiscount = 0;
        _couponMessage = friendlyError(e, lang);
      });
    } finally {
      if (mounted) setState(() => _couponBusy = false);
    }
  }

  int? get _parsedHomeSqm {
    final n = int.tryParse(toWesternDigits(homeSqm.text.trim()).replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null || n <= 0) return null;
    return n;
  }

  ServiceItem? _matchCleaningTier(int sqm) {
    if (p == null) return null;
    for (final it in p!.items) {
      if (!it.isCleaning || !it.active) continue;
      if (cleaningSqmMatches(sqm: sqm, fromSqm: it.sizeFromSqm, toSqm: it.sizeToSqm)) return it;
    }
    return null;
  }

  void _applyHomeSqmToGuests({bool track = true}) {
    final sqm = _parsedHomeSqm;
    if (p == null) return;
    final match = sqm == null ? null : _matchCleaningTier(sqm);
    for (final g in guests) {
      g.serviceCounts.removeWhere((id, _) {
        final it = _itemById(id);
        return it != null && it.isCleaning;
      });
      if (match != null) {
        g.serviceCounts[match.id] = 1;
      }
    }
    if (track && match != null && _lastServiceTracked != match.id) {
      _lastServiceTracked = match.id;
      unawaited(AppAnalytics.bookingServiceSelected(
        providerId: p!.id,
        serviceItemId: match.id,
        value: match.price / 100,
        serviceName: match.name.en.isNotEmpty ? match.name.en : match.name.ar,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final b = t['book'] as Map;
    final stepsMap = t['steps'] as Map;
    final steps = ['${stepsMap['service']}', '${stepsMap['details']}', '${stepsMap['payment']}'];
    final bar = t['ctaBar'] as Map;
    final addrs = ref.watch(sessionProvider).user?.addresses ?? const <Address>[];
    final addr = _selectedAddress();
    if (p == null) {
      return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
    }
    int servicesTotal = 0;
    for (final g in guests) {
      servicesTotal += _guestServicesMoney(g);
    }
    // Trust fee is permanently 0 (server-side kill switch) — kept as a real
    // read, not a hardcoded 0, so nothing here silently drifts if that
    // ever changes.
    final trustFee = ref.watch(sessionProvider).trustFee;
    final discount = _couponOk ? _couponDiscount : 0;
    final rawTotal = servicesTotal + trustFee - discount;
    final total = rawTotal < 0 ? 0 : rawTotal;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: lang == 'ar' ? 'حجزك' : 'Your booking', onBack: () => context.pop()),
            ClientBookingStepper(step: 1, labels: steps),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${b['service']}'),
                        const SizedBox(height: 12),
                        Text(
                          lang == 'ar' ? 'اختاري الخدمات لكل ضيفة من قسم الضيوف تحت.' : 'Choose each guest services from the guests section below.',
                          style: const TextStyle(fontSize: 12, color: Client.muted),
                        ),
                      ],
                    ),
                  ),
                  const ClientDivider(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${b['slot']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(days.length.clamp(0, 5), (i) {
                            final on = day == i;
                            final date = DateTime.tryParse('${days[i]['date']}') ?? DateTime.now();
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => day = i);
                                    if (p != null) {
                                      unawaited(AppAnalytics.bookingSlotSelected(
                                        providerId: p!.id,
                                        slotStart: slotTime().toIso8601String(),
                                      ));
                                      _lastSlotTracked = slot;
                                    }
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 56),
                                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.ink : Client.card),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          weekdayLabel(date, lang),
                                          style: TextStyle(fontFamily: T.mono, fontSize: 10, color: on ? Client.bg : Client.ink),
                                        ),
                                        Text('${date.day}'.padLeft(2, '0'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? Client.bg : Client.ink)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        if (days.isNotEmpty)
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 2.2,
                            children: List.generate((days[day]['slots'] as List).length, (i) {
                              final s = (days[day]['slots'] as List)[i] as Map;
                              final avail = s['available'] != false;
                              final on = slot == i;
                              return Opacity(
                                opacity: avail ? 1 : 0.35,
                                child: InkWell(
                                  onTap: avail
                                      ? () {
                                          tapLight();
                                          setState(() => slot = i);
                                          if (p != null && _lastSlotTracked != i) {
                                            _lastSlotTracked = i;
                                            unawaited(AppAnalytics.bookingSlotSelected(
                                              providerId: p!.id,
                                              slotStart: slotTime().toIso8601String(),
                                            ));
                                          }
                                        }
                                      : null,
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule),
                                      color: on ? Client.plum : Client.card,
                                    ),
                                    child: Text(availabilitySlotLabel(s, lang), style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w500, color: on ? Client.bg : Client.ink)),
                                  ),
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
                  const ClientDivider(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${b['address']}'),
                        const SizedBox(height: 12),
                        ...addrs.map((a) {
                          final on = addr?.id == a.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () async {
                                setState(() => addressId = a.id);
                                await ref.read(sessionProvider.notifier).patchMe(defaultAddressId: a.id);
                                if (_lastAddressTracked != a.id && p != null) {
                                  _lastAddressTracked = a.id;
                                  unawaited(AppAnalytics.bookingAddressSelected(providerId: p!.id, area: a.area));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule), color: on ? Client.plumTint : Client.card),
                                child: Row(
                                  children: [
                                    Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Colors.transparent)),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text('${a.label.of(lang)}\n${a.line1.of(lang)}\n${a.city.of(lang)}${a.lat != 0 ? '\nGoogle Maps' : ''}', style: const TextStyle(fontSize: 13, height: 1.5))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        ClientGhostButton(
                          label: lang == 'ar' ? 'زودي عنوان' : 'Add an address',
                          onTap: () async {
                            final saved = await Navigator.of(context).push<Address?>(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => const AddressFormScreen(returnResult: true),
                              ),
                            );
                            if (!mounted) return;
                            final addrsNow = ref.read(sessionProvider).user?.addresses ?? [];
                            final pick = saved ?? (addrsNow.isNotEmpty ? addrsNow.last : null);
                            if (pick == null) return;
                            setState(() => addressId = pick.id);
                            await ref.read(sessionProvider.notifier).patchMe(defaultAddressId: pick.id);
                            if (_lastAddressTracked != pick.id && p != null) {
                              _lastAddressTracked = pick.id;
                              unawaited(AppAnalytics.bookingAddressSelected(providerId: p!.id, area: pick.area));
                            }
                          },
                        ),
                        if (addr != null && p!.areas.isNotEmpty && !p!.areas.contains(addr.area)) ...[
                          const SizedBox(height: 10),
                          Text(
                            lang == 'ar'
                                ? 'المتخصصة دي مش بتغطي منطقة عنوانك (${areaName(addr.area, lang)}). غيّري العنوان أو اختاري متخصصة تانية.'
                                : 'This professional doesn’t cover ${areaName(addr.area, lang)}. Change your address or pick someone else.',
                            style: const TextStyle(color: T.danger, fontSize: 13, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ClientKicker('${b['guests']}'),
                        const SizedBox(height: 8),
                        if (_hasCleaningItems) ...[
                          Text('${b['homeSize']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('${b['homeSizeTip']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.35)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: homeSqm,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() => _applyHomeSqmToGuests()),
                            decoration: InputDecoration(
                              hintText: '${b['homeSizeHint']}',
                              filled: true,
                              fillColor: Client.bg,
                              enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                            ),
                          ),
                          if (_parsedHomeSqm != null) ...[
                            const SizedBox(height: 8),
                            Builder(builder: (_) {
                              final match = _matchCleaningTier(_parsedHomeSqm!);
                              if (match == null) {
                                return Text('${b['homeSizeNoMatch']}', style: const TextStyle(color: T.danger, fontSize: 12.5, height: 1.35));
                              }
                              final included = kCleaningCatalogTaskCount - match.excludedTaskIds.length;
                              return Text(
                                '${b['homeSizeMatch']}: ${match.name.of(lang)}\n'
                                '${cleaningSizeMeta(fromSqm: match.sizeFromSqm, toSqm: match.sizeToSqm, workers: match.workerCount, ar: lang == 'ar')}'
                                '${included > 0 ? '\n${b['packageIncludes']}: ${pluralTasks(included, ar: lang == 'ar')}' : ''}',
                                style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600),
                              );
                            }),
                          ],
                          const SizedBox(height: 12),
                        ],
                        ...List.generate(guests.length, (i) {
                          final g = guests[i];
                          final requiredGuest = i == 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(requiredGuest ? '${b['you']}' : '${b['guestLabel']} ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const Spacer(),
                                      if (!requiredGuest)
                                        TextButton(
                                          onPressed: () {
                                            g.dispose();
                                            setState(() => guests.removeAt(i));
                                          },
                                          child: Text('${b['removeGuest']}', style: const TextStyle(fontSize: 12, color: T.danger)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: g.name,
                                    decoration: InputDecoration(
                                      hintText: lang == 'ar' ? 'الاسم' : 'Name',
                                      filled: true,
                                      fillColor: Client.bg,
                                      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: g.phone,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: lang == 'ar' ? 'موبايل الضيفة (اختياري)' : 'Guest phone (optional)',
                                      filled: true,
                                      fillColor: Client.bg,
                                      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: g.notes,
                                    minLines: 1,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      hintText: lang == 'ar' ? 'تفاصيل للضيفة (اختياري)' : 'Guest notes (optional)',
                                      filled: true,
                                      fillColor: Client.bg,
                                      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...p!.items.map((svc) {
                                    final n = g.serviceCounts[svc.id] ?? 0;
                                    final sqm = _parsedHomeSqm;
                                    final cleaningLocked = svc.isCleaning && sqm != null;
                                    final cleaningMatch = svc.isCleaning &&
                                        sqm != null &&
                                        cleaningSqmMatches(sqm: sqm, fromSqm: svc.sizeFromSqm, toSqm: svc.sizeToSqm);
                                    final meta = svc.isCleaning
                                        ? cleaningSizeMeta(
                                            fromSqm: svc.sizeFromSqm,
                                            toSqm: svc.sizeToSqm,
                                            workers: svc.workerCount,
                                            ar: lang == 'ar',
                                          )
                                        : null;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Opacity(
                                        opacity: cleaningLocked && !cleaningMatch ? 0.45 : 1,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(svc.name.of(lang), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                                  if (meta != null)
                                                    Text(meta, style: const TextStyle(fontSize: 11, color: Client.muted)),
                                                  if (cleaningMatch)
                                                    Text('${b['homeSizeMatch']}', style: const TextStyle(fontSize: 11, color: Client.plum, fontWeight: FontWeight.w600)),
                                                  // What the provider says this service includes. A
                                                  // cleaning package already lists its tasks through
                                                  // the checklist, so this is for everything else.
                                                  for (final ben in svc.benefits)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Padding(
                                                            padding: EdgeInsetsDirectional.only(end: 4, top: 2),
                                                            child: Icon(Icons.check, size: 11, color: Client.plum),
                                                          ),
                                                          Expanded(
                                                            child: Text(ben.of(lang),
                                                                style: const TextStyle(fontSize: 11, color: Client.muted, height: 1.35)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: cleaningLocked
                                                  ? null
                                                  : (n > 0
                                                      ? () => setState(() {
                                                            final m = n - 1;
                                                            if (m <= 0) {
                                                              g.serviceCounts.remove(svc.id);
                                                            } else {
                                                              g.serviceCounts[svc.id] = m;
                                                            }
                                                          })
                                                      : null),
                                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                                            ),
                                            Text('$n', style: const TextStyle(fontFamily: T.mono, fontSize: 13)),
                                            IconButton(
                                              onPressed: cleaningLocked
                                                  ? null
                                                  : () {
                                                      setState(() => g.serviceCounts[svc.id] = n + 1);
                                                      if (_lastServiceTracked != svc.id && p != null) {
                                                        _lastServiceTracked = svc.id;
                                                        unawaited(AppAnalytics.bookingServiceSelected(
                                                          providerId: p!.id,
                                                          serviceItemId: svc.id,
                                                          value: svc.price / 100,
                                                          serviceName: svc.name.en.isNotEmpty ? svc.name.en : svc.name.ar,
                                                        ));
                                                      }
                                                    },
                                              icon: const Icon(Icons.add_circle_outline, size: 20),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                n > 1 ? '${money(svc.price, lang)} ×$n' : money(svc.price, lang),
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  Text(
                                    lang == 'ar'
                                        ? 'إجمالي خدمات الضيفة: ${money(_guestServicesMoney(g), lang)}'
                                        : 'Guest services: ${money(_guestServicesMoney(g), lang)}',
                                    style: const TextStyle(fontSize: 11, color: Client.muted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        ClientGhostButton(
                          label: '${b['addGuest']}',
                          onTap: () {
                            setState(() {
                              final draft = _GuestDraft(name: TextEditingController(text: '${b['guestLabel']} ${guests.length + 1}'));
                              // Same services as the first guest so cost scales with guest count.
                              if (guests.isNotEmpty) {
                                draft.serviceCounts.addAll(Map<String, int>.from(guests.first.serviceCounts));
                              } else if (p != null && p!.items.isNotEmpty) {
                                draft.serviceCounts[p!.items.first.id] = 1;
                              }
                              guests.add(draft);
                            });
                          },
                        ),
                        if (formError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(formError!, style: const TextStyle(color: T.danger, fontSize: 13, height: 1.4)),
                          ),
                        const SizedBox(height: 8),
                        Text('${b['guestFeeNote']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                        if (guests.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${b['guestCancelNote']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                          ),
                        const SizedBox(height: 16),
                        ClientKicker('${b['savedInstr']}'),
                        const SizedBox(height: 8),
                        ...() {
                          final saved = ref.watch(sessionProvider).user?.instructions ?? [];
                          return [
                            if (saved.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('${b['noInstr']}', style: const TextStyle(fontSize: 13, color: Client.muted)),
                              ),
                            ...saved.map((i) {
                              final on = instructionId == i.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () => setState(() {
                                    instructionId = i.id;
                                    notes.text = i.body;
                                    saveInstr = false;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule),
                                      color: on ? Client.plumTint : Client.card,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Client.ink, width: Client.rule),
                                            color: on ? Client.plum : Colors.transparent,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '${i.title}\n${i.body}',
                                            style: const TextStyle(fontSize: 13, height: 1.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => setState(() {
                                  instructionId = null;
                                  if (notes.text.isEmpty) notes.clear();
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: instructionId == null ? Client.plum : Client.ink, width: Client.rule),
                                    color: instructionId == null ? Client.plumTint : Client.card,
                                  ),
                                  child: Text('${b['newInstr']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            ClientGhostButton(
                              label: lang == 'ar' ? 'زودي تعليمات' : 'Save an instruction',
                              onTap: () async {
                                final saved = await Navigator.of(context).push<Instruction?>(
                                  MaterialPageRoute(
                                    fullscreenDialog: true,
                                    builder: (_) => const InstructionFormScreen(returnResult: true),
                                  ),
                                );
                                if (!mounted) return;
                                await ref.read(sessionProvider.notifier).refreshMe();
                                final list = ref.read(sessionProvider).user?.instructions ?? [];
                                final pick = saved ?? (list.isNotEmpty ? list.last : null);
                                if (pick != null) {
                                  setState(() {
                                    instructionId = pick.id;
                                    if (notes.text.trim().isEmpty) notes.text = pick.body;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ];
                        }(),
                        ClientKicker('${b['notes']}'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notes,
                          minLines: 3,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: '${b['notesPh']}',
                            filled: true,
                            fillColor: Client.card,
                            enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                          ),
                        ),
                        if (instructionId == null) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => setState(() => saveInstr = !saveInstr),
                            child: Row(
                              children: [
                                Container(width: 18, height: 18, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: saveInstr ? Client.plum : Colors.transparent)),
                                const SizedBox(width: 10),
                                Expanded(child: Text('${b['saveInstr']}')),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ClientKicker(lang == 'ar' ? 'كوبون خصم' : 'Coupon'),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: coupon,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (v) {
                                  if (_couponOk && v.trim().toUpperCase() != _appliedCouponCode) {
                                    setState(() {
                                      _couponOk = false;
                                      _appliedCouponCode = null;
                                      _couponDiscount = 0;
                                      _couponMessage = null;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: lang == 'ar' ? 'اكتبي كود الكوبون' : 'Enter coupon code',
                                  filled: true,
                                  fillColor: Client.card,
                                  enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 104,
                              height: 48,
                              child: ClientGhostButton(
                                label: _couponBusy ? '…' : (lang == 'ar' ? 'تطبيق' : 'Apply'),
                                onTap: _couponBusy ? () {} : _applyCoupon,
                              ),
                            ),
                          ],
                        ),
                        if (_couponMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _couponMessage!,
                            style: TextStyle(fontSize: 12.5, color: _couponOk ? Client.plum : Client.muted, fontWeight: _couponOk ? FontWeight.w700 : FontWeight.w400),
                          ),
                        ],
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ClientStickyBar(
              label: '${bar['total']}',
              price: money(total, lang),
              cta: '${bar['continue']}',
              note: '${bar['held']}',
              enabled: !busy && ref.watch(sessionProvider).online,
              onTap: () async {
                if (addr == null || addr.id.isEmpty) {
                  setState(() => formError = '${b['needAddress']}');
                  return;
                }
                if (p!.areas.isNotEmpty && !p!.areas.contains(addr.area)) {
                  setState(() => formError = lang == 'ar'
                      ? 'المتخصصة دي مش بتغطي منطقة عنوانك. غيّري العنوان لمنطقة تغطيتها.'
                      : 'This professional doesn’t cover your address area. Pick a covered area or another pro.');
                  return;
                }
                if (p!.items.isEmpty) {
                  setState(() => formError = '${b['needService']}');
                  return;
                }
                final guestPayload = <Map<String, dynamic>>[];
                var selectedCleaning = false;
                for (final g in guests) {
                  final nm = g.name.text.trim();
                  for (final e in g.serviceCounts.entries) {
                    if (e.value <= 0) continue;
                    final it = _itemById(e.key);
                    if (it?.isCleaning == true) selectedCleaning = true;
                    guestPayload.add({
                      'guestLabel': nm.isEmpty ? '${b['guestLabel']}' : nm,
                      'guestPhone': g.phone.text.trim(),
                      'guestNotes': g.notes.text.trim(),
                      'serviceItemId': e.key,
                      'count': e.value,
                    });
                  }
                }
                if (guestPayload.isEmpty) {
                  setState(() => formError = '${b['needService']}');
                  return;
                }
                final onlyCleaningCatalog = p!.items.every((e) => e.isCleaning);
                if (selectedCleaning || onlyCleaningCatalog) {
                  final sqm = _parsedHomeSqm;
                  if (sqm == null) {
                    setState(() => formError = '${b['homeSizeTip']}');
                    return;
                  }
                  if (_matchCleaningTier(sqm) == null) {
                    setState(() => formError = '${b['homeSizeNoMatch']}');
                    return;
                  }
                }
                if (days.isEmpty) {
                  setState(() => formError = '${b['needSlot']}');
                  return;
                }
                final slots = (days[day]['slots'] as List?) ?? const [];
                if (slot < 0 || slot >= slots.length || (slots[slot] as Map)['available'] == false) {
                  setState(() => formError = '${b['needSlot']}');
                  return;
                }
                setState(() {
                  busy = true;
                  formError = null;
                });
                try {
                  final firstServiceId = '${guestPayload.first['serviceItemId']}';
                  final created = await ref.read(repoProvider).createBooking(
                        providerId: p!.id,
                        serviceItemId: firstServiceId,
                        slot: slotTime(),
                        addressId: addr.id,
                        notes: notes.text,
                        instructionId: instructionId,
                        saveInstruction: saveInstr && instructionId == null,
                        guests: guestPayload,
                        couponCode: _couponOk ? _appliedCouponCode : null,
                      );
                  await ref.read(sessionProvider.notifier).refreshMe();
                  if (mounted) context.push('/checkout/${created.booking.id}');
                } catch (e) {
                  if (!mounted) return;
                  setState(() => formError = friendlyError(e, lang));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(friendlyError(e, lang))),
                  );
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
            value: b.booking.total / 100.0,
          ));
        }
      }
    });
    // Refresh user so paidBookingCount is current (determines ID gate)
    ref.read(sessionProvider.notifier).refreshMe();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final co = t['co'] as Map;
    final bar = t['ctaBar'] as Map;
    final stepsMap = t['steps'] as Map;
    final steps = ['${stepsMap['service']}', '${stepsMap['details']}', '${stepsMap['payment']}'];
    final online = ref.watch(sessionProvider).online;
    final user = ref.watch(sessionProvider).user;
    final needsId = user?.needsIdentityCompletion ?? false;
    if (data == null) {
      return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
    }
    final b = data!.booking;
    final p = data!.provider;
    final methods = [
      ['card', Icons.credit_card_outlined, co['card'], co['cardNote']],
      ['instapay', Icons.phone_iphone_outlined, co['instapay'], co['instapayNote']],
    ];
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: lang == 'ar' ? 'الدفع' : 'Payment', onBack: () => context.pop()),
            ClientBookingStepper(step: 3, labels: steps),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Face(id: p?.id, ini: p?.initials.of(lang) ?? '', size: 48, photo: p?.photo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p?.name(lang) ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(
                                b.items.isNotEmpty
                                    ? '${b.itemsByGuest.length} ${lang == 'ar' ? 'ضيوف' : 'guests'} · ${b.items.fold<int>(0, (n, i) => n + i.count)} ${lang == 'ar' ? 'خدمات' : 'services'} · ${formatSlot(b.slotStart, lang)}'
                                    : '${b.serviceName.of(lang)} · ${formatSlot(b.slotStart, lang)}',
                                style: const TextStyle(fontSize: 12, color: Client.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ClientDivider(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${co['summary']}'),
                        const SizedBox(height: 12),
                        if (b.items.isNotEmpty)
                          ...() {
                            final groups = b.itemsByGuest.entries.toList();
                            return [
                              ...groups.map((entry) {
                                final guestName = entry.key;
                                final rows = entry.value;
                                final sub = rows.fold<int>(0, (n, r) => n + r.lineTotal);
                                final phone = rows.map((r) => r.guestPhone).whereType<String>().where((s) => s.isNotEmpty).toSet();
                                final notes = rows.map((r) => r.guestNotes).whereType<String>().where((s) => s.isNotEmpty).toSet();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(guestName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Client.ink)),
                                        if (phone.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(phone.join(' · '), style: const TextStyle(fontSize: 11, color: Client.muted)),
                                        ],
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(notes.join(' · '), style: const TextStyle(fontSize: 11, color: Client.muted, height: 1.35)),
                                        ],
                                        const SizedBox(height: 8),
                                        ...rows.map((r) {
                                          final qty = r.count < 1 ? 1 : r.count;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    qty > 1 ? '${r.serviceName.of(lang)}  ${co['qty']}$qty' : r.serviceName.of(lang),
                                                    style: const TextStyle(fontSize: 13, color: Client.body, height: 1.35),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(money(r.lineTotal, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 13)),
                                              ],
                                            ),
                                          );
                                        }),
                                        if (groups.length > 1) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(child: Text('${co['guestSubtotal']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.muted))),
                                              Text(money(sub, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              ClientKicker('${co['fees']}'),
                              const SizedBox(height: 8),
                              ...b.lineItems.where((l) => l.key != null && l.key != 'service').map((l) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(localizeAreaSlugs(l.label.of(lang), lang), style: const TextStyle(fontSize: 13, color: Client.body))),
                                        Text(money(l.amount, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 13)),
                                      ],
                                    ),
                                  )),
                            ];
                          }()
                        else
                          ...b.lineItems.map((l) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(localizeAreaSlugs(l.label.of(lang), lang), style: const TextStyle(fontSize: 13, color: Client.body))),
                                    Text(money(l.amount, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 13)),
                                  ],
                                ),
                              )),
                        const ClientDivider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Text('${co['total']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Text(money(b.total, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 20, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        if (data!.processingFeeFor(method) > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lang == 'ar' ? 'رسوم معالجة الدفع' : 'Payment processing fee',
                                  style: const TextStyle(fontSize: 13, color: Client.body),
                                ),
                              ),
                              Text(money(data!.processingFeeFor(method), lang), style: const TextStyle(fontFamily: T.mono, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                lang == 'ar' ? 'المبلغ المستحق' : 'Amount due',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                money(b.total + data!.processingFeeFor(method), lang),
                                style: const TextStyle(fontFamily: T.mono, fontSize: 20, fontWeight: FontWeight.w800, color: Client.plum),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang == 'ar'
                                ? 'رسوم بوابة الدفع بتتحسب فوق سعر الزيارة عشان المبلغ يوصل كامل.'
                                : 'Gateway fees are added so the visit total arrives in full after Paymob charges.',
                            style: const TextStyle(fontSize: 11, color: Client.muted, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    color: Client.olive,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.verified_user_outlined, color: Client.bg, size: 18),
                          const SizedBox(width: 10),
                          Text('${co['escrowTitle']}'.toUpperCase(), style: const TextStyle(color: Client.bg, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        ]),
                        const SizedBox(height: 10),
                        Text('${co['escrowBody']}', style: const TextStyle(color: Client.bg, fontSize: 14, height: 1.5)),
                        const SizedBox(height: 14),
                        ClientKicker('${co['escrowStep']}', color: Client.bg),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${co['payWith']}'),
                        const SizedBox(height: 6),
                        Text(
                          lang == 'ar' ? 'اختاري طريقة — كل طريقة في إطارها.' : 'Pick a method — each opens in its own frame.',
                          style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        ...methods.map((m) {
                          final key = '${m[0]}';
                          final on = method == key;
                          final icon = m[1] as IconData;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () {
                                setState(() => method = key);
                                unawaited(AppAnalytics.addPaymentInfo(
                                  bookingId: b.id,
                                  method: key,
                                  value: b.total / 100.0,
                                ));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: on ? Client.plum : Client.ink, width: on ? 2 : Client.rule),
                                  color: on ? Client.plumTint : Client.card,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Client.ink, width: Client.rule),
                                        color: Client.bg,
                                      ),
                                      child: Icon(icon, size: 22, color: Client.plum),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${m[2]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text('${m[3]}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                                          if (on) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              lang == 'ar' ? 'هتفتح إطار الدفع الخاص بالطريقة دي' : 'Opens this method’s payment frame',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Client.plum),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 18,
                                      height: 18,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Client.ink, width: Client.rule),
                                        color: on ? Client.plum : Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${co['policyTitle']}'),
                        ...(t['policy'] as List).map((row) {
                          final r = row as Map;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
                            child: Row(
                              children: [
                                SizedBox(width: 78, child: Text('${r['when']}', style: const TextStyle(fontFamily: T.mono, fontSize: 11))),
                                Expanded(child: Text('${r['what']}', style: const TextStyle(fontSize: 13, height: 1.4))),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text('${co['policyNote']}', style: const TextStyle(fontSize: 12, height: 1.5, color: Client.muted)),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => openLegal(context, 'cancellation'),
                          child: Text(
                            '${co['policyFull']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                          ),
                        ),
                        const SizedBox(height: 110),
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
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFF856404)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang == 'ar'
                              ? 'لازم تكملي بياناتك وترفعي صورة البطاقة قبل تأكيد الحجز — اضغطي هنا'
                              : 'Complete your ID before confirming — tap here',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF533F03), height: 1.4),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFF856404)),
                    ],
                  ),
                ),
              ),
            ClientStickyBar(
              label: '${bar['payNow']}',
              price: money(b.total, lang),
              cta: lang == 'ar' ? 'ادفعِي بإطار ${_methodShortAr(method)}' : 'Pay with ${_methodShortEn(method)}',
              note: lang == 'ar' ? 'الفلوس واقفة. مش رايحة لحد لسه. بتروح بعد ما تخلص.' : 'Held, not sent. Released after checkout.',
              enabled: online && !needsId,
              onTap: () {
                if (!online) return;
                tapSuccess();
                unawaited(AppAnalytics.addPaymentInfo(
                  bookingId: b.id,
                  method: method,
                  value: b.total / 100.0,
                ));
                context.push('/pay/${b.id}/$method');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _methodShortEn(String m) {
    switch (m) {
      case 'instapay':
        return 'Mobile Wallet';
      case 'fawry':
        return 'Fawry';
      default:
        return 'Credit Card';
    }
  }

  String _methodShortAr(String m) {
    switch (m) {
      case 'instapay':
        return 'محفظة الموبايل';
      case 'fawry':
        return 'فوري';
      default:
        return 'بطاقة ائتمان';
    }
  }
}

class FawryScreen extends ConsumerStatefulWidget {
  const FawryScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<FawryScreen> createState() => _FawryScreenState();
}

class _FawryScreenState extends ConsumerState<FawryScreen> {
  BookingBundle? data;
  Timer? t;

  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await ref.read(repoProvider).checkPay(widget.bookingId);
    if (!mounted) return;
    setState(() => data = b);
    if (b.booking.status == 'paid') {
      t?.cancel();
      await ref.read(repoProvider).ensurePurchaseTracked(b);
      if (!mounted) return;
      context.go('/confirmed/${b.booking.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final f = Copy.of(lang)['fawry'] as Map;
    final b = data?.booking;
    final cardPending = b != null && (b.fawryCode == null || b.fawryCode!.isEmpty);
    final left = b?.fawryExpiresAt?.difference(DateTime.now()) ?? Duration.zero;
    String cd() {
      final s = left.isNegative ? Duration.zero : left;
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(s.inHours)}:${two(s.inMinutes % 60)}:${two(s.inSeconds % 60)}';
    }

    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(
              title: cardPending
                  ? (lang == 'ar' ? 'بنتأكد من الدفع' : 'Confirming payment')
                  : (lang == 'ar' ? 'الدفع من فوري' : 'Fawry payment'),
              onBack: () => context.go('/home'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              if (cardPending) ...[
                Text(
                  lang == 'ar' ? 'خلّصي الدفع في نافذة بايموب، وبعدين ارجعي هنا.' : 'Finish in the Paymob window, then return here.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  lang == 'ar' ? 'بنحدّث الحالة تلقائي كل شوية.' : 'We refresh the status automatically.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                ClientGhostButton(
                  label: lang == 'ar' ? 'حدّث الآن' : 'Refresh now',
                  onTap: () async {
                    await ref.read(repoProvider).checkPay(widget.bookingId);
                    await _load();
                  },
                ),
              ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.warnTint),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, color: Client.terracotta),
                  const SizedBox(width: 8),
                  ClientKicker('${f['badge']}', color: Client.ink),
                ]),
              ),
              const SizedBox(height: 16),
              Text('${f['title']}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text('${f['body']}', style: Theme.of(context).textTheme.bodyMedium),
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
                          ClientKicker('${f['codeLabel']}'),
                          const SizedBox(height: 8),
                          Ltr(child: Text((b?.fawryCode ?? '--------').split('').join(' '), style: const TextStyle(fontFamily: T.mono, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: 1))),
                        ],
                      ),
                    ),
                    const ClientDivider(),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClientKicker('${f['expires']}'),
                          const Spacer(),
                          Text(cd(), style: const TextStyle(fontFamily: T.mono, fontSize: 16, fontWeight: FontWeight.w500, color: Client.terracotta)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...['s1', 's2', 's3'].asMap().entries.map((e) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.bg),
                    child: Row(
                      children: [
                        Text('${e.key + 1}'.padLeft(2, '0'), style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.plum)),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${f[e.value]}', style: const TextStyle(fontSize: 13, height: 1.45))),
                      ],
                    ),
                  )),
              const Spacer(),
              ClientGhostButton(
                label: '${f['paid']}',
                onTap: () async {
                  await ref.read(repoProvider).checkPay(widget.bookingId);
                  await _load();
                },
              ),
              TextButton(onPressed: () => context.push('/cancel/${widget.bookingId}'), child: Text('${f['cancel']}', style: const TextStyle(color: Client.muted))),
              ],
            ],
                ),
              ),
            ),
          ],
        ),
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
    final c = Copy.of(lang)['conf'] as Map;
    return FutureBuilder<BookingBundle>(
      future: ref.read(repoProvider).booking(bookingId),
      builder: (context, snap) {
        final b = snap.data?.booking;
        final p = snap.data?.provider;
        return Scaffold(
          backgroundColor: Client.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Client.olive,
                    padding: const EdgeInsets.all(14),
                    alignment: AlignmentDirectional.bottomStart,
                    child: Stack(
                      children: [
                        const Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Text('✓', style: TextStyle(fontFamily: T.mono, fontSize: 28, color: Client.bg)),
                        ),
                        Align(alignment: AlignmentDirectional.bottomStart, child: ClientKicker('${c['kicker']}', color: Client.bg)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('${c['title']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Client.ink)),
                  const SizedBox(height: 12),
                  Text('${c['body']}', style: const TextStyle(fontSize: 15, height: 1.5, color: Client.body)),
                  const SizedBox(height: 20),
                  if (b != null) ...[
                    _row(lang == 'ar' ? 'المرجع' : 'Reference', b.ref),
                    _row(lang == 'ar' ? 'الموعد' : 'When', formatSlot(b.slotStart, lang)),
                    _row(lang == 'ar' ? 'المكان' : 'Where', b.address?.city.of(lang) ?? ''),
                    _row(lang == 'ar' ? 'المدفوع' : 'Paid', '${money(b.total, lang)} · ${lang == 'ar' ? 'واقفة' : 'Held'}'),
                    _row(lang == 'ar' ? 'المتخصصة' : 'Professional', p?.name(lang) ?? ''),
                  ],
                  const Spacer(),
                  ClientPrimaryButton(
                    label: '${c['cta']}',
                    onTap: () {
                      if (context.mounted) context.go('/visit/$bookingId');
                    },
                  ),
                  const SizedBox(height: 8),
                  ClientGhostButton(label: '${c['share']}', onTap: () => context.push('/share/$bookingId')),
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
          SizedBox(width: 96, child: ClientKicker(k)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
