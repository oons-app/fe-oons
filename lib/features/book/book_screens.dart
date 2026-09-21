import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/book/book_draft.dart';
import 'package:oons/features/book/book_pricing.dart';
import 'package:oons/features/book/book_widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/me/me_screens.dart';
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/features/system/progress.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

export 'package:oons/features/book/book_checkout.dart';

class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, required this.providerId, this.itemId});
  final String providerId;
  final String? itemId;
  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  static const _chipIds = ['no_elevator', 'cat', 'ring', 'doorman'];

  ProviderP? p;
  ProcessingFeeSchedule fees = const ProcessingFeeSchedule();
  List<Map<String, dynamic>> days = [];
  final qty = <String, int>{};
  String? _activeVertical;
  final homeSqm = TextEditingController();
  int? chipSqm;
  bool toolsFromProvider = false;
  int guests = 1;
  String hair = 'medium';
  int day = 0;
  int slot = 0;
  String? addressId;
  final notes = TextEditingController();
  final coupon = TextEditingController();
  final noteChipIds = <String>{};
  String? expandedId;
  bool couponOpen = false;
  bool couponBusy = false;
  bool couponOk = false;
  String? appliedCoupon;
  int couponDiscount = 0;
  String? couponMessage;
  bool busy = false;
  String? formError;
  BookField? errorField;
  String? toastMessage;
  int toastNonce = 0;
  Object? loadError;
  String? notice;
  bool flowStarted = false;
  bool notesTracked = false;
  int screen = 1;
  int? lastDurationFetched;
  String? lastAreaFetched;
  Timer? persistWait;
  final scroll = ScrollController();
  final servicesKey = GlobalKey();
  final areaKey = GlobalKey();
  final slotKey = GlobalKey();
  final addressKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    notes.addListener(_onNotesChanged);
    _load();
  }

  @override
  void dispose() {
    persistWait?.cancel();
    notes.removeListener(_onNotesChanged);
    notes.dispose();
    homeSqm.dispose();
    coupon.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _onNotesChanged() {
    if (notesTracked || notes.text.trim().isEmpty || p == null) return;
    notesTracked = true;
    unawaited(AppAnalytics.bookingNotesAdded(providerId: p!.id));
  }

  Map<String, String> get bf => Copy.bookFlow(langOf(ref));

  List<String> get verticals {
    if (p == null) return const [];
    final seen = <String>[];
    for (final it in p!.items) {
      final v = it.vertical ?? p!.service;
      if (!seen.contains(v)) seen.add(v);
    }
    return seen;
  }

  String get activeVertical => _activeVertical ?? (verticals.contains('cleaning') ? 'cleaning' : (verticals.isEmpty ? '' : verticals.first));

  List<ServiceItem> get visibleItems {
    if (p == null) return const [];
    if (verticals.length <= 1) return p!.items.where((e) => e.active).toList();
    return p!.items.where((e) => e.active && (e.vertical ?? p!.service) == activeVertical).toList();
  }

  List<BookLine> get lines {
    if (p == null) return const [];
    return bookLines(items: p!.items, qty: qty, guests: guests, hair: hair);
  }

  bool get cartReady => lines.isNotEmpty;

  bool get activeHasCart => visibleItems.any((e) => (qty[e.id] ?? 0) > 0);

  bool get showCleaningFields => activeHasCart && visibleItems.any((e) => e.isCleaning);

  bool get showBeautyFields => activeHasCart && visibleItems.any((e) => !e.isCleaning);

  bool get showHair => lines.any((l) => l.item.needsHairLength);

  int get exclusive => bookExclusiveTotal(
        lines: lines,
        toolsFromProvider: toolsFromProvider,
        discount: couponOk ? couponDiscount : 0,
        trustFee: ref.read(sessionProvider).trustFee,
      );

  int get inclusive => bookInclusiveTotal(
        lines: lines,
        toolsFromProvider: toolsFromProvider,
        fees: fees,
        discount: couponOk ? couponDiscount : 0,
        trustFee: ref.read(sessionProvider).trustFee,
      );

  Address? _selectedAddress() {
    final addrs = ref.read(sessionProvider).user?.addresses ?? const <Address>[];
    for (final a in addrs) {
      if (addressId != null && a.id == addressId) return a;
    }
    if (addrs.isEmpty) return null;
    final defaults = addrs.where((a) => a.isDefault);
    return defaults.isEmpty ? addrs.first : defaults.first;
  }

  ServiceItem? _itemById(String id) {
    if (p == null) return null;
    for (final it in p!.items) {
      if (it.id == id) return it;
    }
    return null;
  }

  ServiceItem? _matchCleaningTier(int sqm) {
    if (p == null) return null;
    for (final it in p!.items) {
      if (!it.isCleaning || !it.active) continue;
      if (cleaningSqmMatches(sqm: sqm, fromSqm: it.sizeFromSqm, toSqm: it.sizeToSqm)) return it;
    }
    return null;
  }

  int? get _parsedHomeSqm {
    final n = int.tryParse(toWesternDigits(homeSqm.text.trim()).replaceAll(RegExp(r'[^0-9]'), ''));
    if (n == null || n <= 0) return null;
    return n;
  }

  DateTime slotTime() {
    if (days.isEmpty) return DateTime.now().toUtc();
    final dayMap = days[day.clamp(0, days.length - 1)];
    final slots = (dayMap['slots'] as List?) ?? const [];
    if (slots.isEmpty) return DateTime.now().toUtc();
    final i = slot.clamp(0, slots.length - 1);
    return availabilitySlotUtc(dayMap, slots[i] as Map);
  }

  void _touch(VoidCallback fn) {
    setState(fn);
    _schedulePersist();
  }

  void _schedulePersist() {
    persistWait?.cancel();
    persistWait = Timer(const Duration(milliseconds: 280), _persist);
  }

  Future<void> _persist() async {
    await saveBookDraft(
      widget.providerId,
      BookDraft(
        qty: Map<String, int>.from(qty),
        vertical: _activeVertical,
        areaM: homeSqm.text,
        chipSqm: chipSqm,
        toolsFromProvider: toolsFromProvider,
        guests: guests,
        hair: hair,
        day: day,
        slot: slot,
        addressId: addressId,
        notes: notes.text,
        noteChipIds: noteChipIds.toList(),
        coupon: coupon.text,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => loadError = null);
    try {
      final repo = ref.read(repoProvider);
      await ref.read(sessionProvider.notifier).refreshMe();
      final boot = await repo.bookBootstrap(widget.providerId);
      if (!mounted) return;
      final prov = boot.provider;
      final draft = loadBookDraft(widget.providerId);
      final verts = <String>[];
      for (final it in prov.items) {
        final v = it.vertical ?? prov.service;
        if (!verts.contains(v)) verts.add(v);
      }
      var nextQty = <String, int>{};
      if (draft != null && draft.qty.isNotEmpty) {
        nextQty = Map<String, int>.from(draft.qty);
      } else if (widget.itemId != null && prov.items.any((e) => e.id == widget.itemId)) {
        nextQty[widget.itemId!] = 1;
      }
      String? vert = draft?.vertical;
      if (vert == null || !verts.contains(vert)) {
        vert = verts.contains('cleaning') ? 'cleaning' : (verts.isEmpty ? null : verts.first);
      }
      if (!flowStarted) {
        flowStarted = true;
        unawaited(AppAnalytics.beginCheckout(
          providerId: prov.id,
          serviceItemId: widget.itemId,
          value: prov.priceFrom / 100,
          entryPoint: AppAnalytics.bookingEntryPoint,
          providerName: prov.name('en'),
          serviceName: prov.service,
        ));
      }
      final addrs = ref.read(sessionProvider).user?.addresses ?? const <Address>[];
      String? addrId = draft?.addressId;
      if (addrId == null || !addrs.any((a) => a.id == addrId)) {
        addrId = addrs.where((a) => a.isDefault).isNotEmpty ? addrs.firstWhere((a) => a.isDefault).id : (addrs.isEmpty ? null : addrs.first.id);
      }
      var noticeVal = GoRouterState.of(context).uri.queryParameters['notice'];
      setState(() {
        p = prov;
        fees = boot.fees;
        days = boot.days;
        qty
          ..clear()
          ..addAll(nextQty);
        _activeVertical = vert;
        toolsFromProvider = false;
        guests = draft?.guests ?? 1;
        hair = draft?.hair ?? 'medium';
        day = draft?.day ?? 0;
        slot = draft?.slot ?? 0;
        addressId = addrId;
        chipSqm = draft?.chipSqm;
        if ((draft?.areaM ?? '').isNotEmpty) homeSqm.text = draft!.areaM;
        if ((draft?.notes ?? '').isNotEmpty) notes.text = draft!.notes;
        if ((draft?.coupon ?? '').isNotEmpty) coupon.text = draft!.coupon;
        noteChipIds
          ..clear()
          ..addAll(draft?.noteChipIds ?? const []);
        notice = noticeVal == 'hold_expired' ? 'hold_expired' : null;
        if (notice == 'hold_expired') screen = 2;
      });
      if (screen == 2) unawaited(_refreshAvailability(force: true));
    } catch (e) {
      if (!mounted) return;
      setState(() => loadError = e);
    }
  }

  Future<void> _refreshAvailability({bool force = false}) async {
    if (p == null) return;
    final dur = bookCartDuration(lines);
    final area = _selectedAddress()?.area;
    if (!force && dur == lastDurationFetched && area == lastAreaFetched && days.isNotEmpty) return;
    lastDurationFetched = dur;
    lastAreaFetched = area;
    try {
      final av = await ref.read(repoProvider).availability(p!.id, durationMin: dur);
      if (!mounted) return;
      setState(() {
        days = av;
        if (day >= days.length) day = 0;
        if (days.isNotEmpty) {
          final slots = (days[day]['slots'] as List?) ?? const [];
          if (slot >= slots.length) slot = 0;
        }
      });
    } catch (_) {}
  }

  Future<void> _setQty(ServiceItem it, int next) async {
    final n = next.clamp(0, 99);
    final prev = qty[it.id] ?? 0;
    _touch(() {
      if (n <= 0) {
        qty.remove(it.id);
        if (expandedId == it.id) expandedId = null;
      } else {
        qty[it.id] = n;
      }
      formError = null;
    });
    if (prev != n) {
      unawaited(AppAnalytics.bookServiceChanged(
        providerId: p!.id,
        serviceItemId: it.id,
        qty: n,
        serviceName: it.name.en.isNotEmpty ? it.name.en : it.name.ar,
      ));
      if (n > 0 && prev == 0) {
        unawaited(AppAnalytics.bookingServiceSelected(
          providerId: p!.id,
          serviceItemId: it.id,
          value: it.price / 100,
          serviceName: it.name.en.isNotEmpty ? it.name.en : it.name.ar,
        ));
        if (mounted) {
          final name = it.name.of(langOf(ref));
          showUndoSnack(
            context,
            message: (bf['added'] ?? '').replaceAll('{name}', name),
            undoLabel: bf['undo'] ?? '',
            onUndo: () => unawaited(_setQty(it, 0)),
          );
        }
      }
    }
  }

  void _applySqm({bool fromChip = false}) {
    final sqm = _parsedHomeSqm;
    if (sqm == null) return;
    final match = _matchCleaningTier(sqm);
    _touch(() {
      chipSqm = fromChip ? sqm : null;
      qty.removeWhere((id, _) => _itemById(id)?.isCleaning == true);
      if (match != null) qty[match.id] = 1;
    });
    unawaited(AppAnalytics.bookFieldChanged(providerId: p!.id, field: 'area_m'));
  }

  Future<void> _applyCoupon() async {
    final code = coupon.text.trim();
    final lang = langOf(ref);
    if (code.isEmpty || p == null || busy) return;
    setState(() {
      couponBusy = true;
      couponMessage = null;
    });
    final verts = <String>{};
    final cats = <String>{};
    for (final l in lines) {
      verts.add(l.item.vertical ?? p!.service);
      if ((l.item.categoryId ?? '').isNotEmpty) cats.add(l.item.categoryId!);
    }
    try {
      final r = await ref.read(repoProvider).validateCoupon(
            code: code,
            providerId: p!.id,
            serviceTotal: bookSubtotal(lines),
            vertical: p!.service,
            verticals: verts.toList(),
            area: _selectedAddress()?.area,
            categoryIds: cats.toList(),
          );
      if (!mounted) return;
      final ok = r['ok'] == true;
      final label = r['label'];
      setState(() {
        couponOk = ok;
        appliedCoupon = ok ? code : null;
        couponDiscount = ok ? ((r['discount'] as num?)?.toInt() ?? 0) : 0;
        couponMessage = ok
            ? (label is Map ? '${label[lang] ?? label['en'] ?? ''}' : (bf['couponApplied'] ?? ''))
            : '${r['message'] ?? (bf['couponInvalid'] ?? '')}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        couponOk = false;
        appliedCoupon = null;
        couponDiscount = 0;
        couponMessage = friendlyError(e, lang);
      });
    } finally {
      if (mounted) setState(() => couponBusy = false);
    }
  }

  String _chipLabel(String id) {
    switch (id) {
      case 'no_elevator':
        return bf['chipNoLift'] ?? '';
      case 'cat':
        return bf['chipCat'] ?? '';
      case 'ring':
        return bf['chipRing'] ?? '';
      case 'doorman':
        return bf['chipDoorman'] ?? '';
      default:
        return id;
    }
  }

  void _toggleChip(String id) {
    final label = _chipLabel(id);
    _touch(() {
      if (noteChipIds.contains(id)) {
        noteChipIds.remove(id);
        notes.text = notes.text.replaceAll(label, '').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
      } else {
        noteChipIds.add(id);
        final t = notes.text.trim();
        notes.text = t.isEmpty ? label : '$t\n$label';
      }
    });
    unawaited(AppAnalytics.bookFieldChanged(providerId: p!.id, field: 'notes'));
  }

  String? _step1Error() {
    if (!cartReady) return bf['needService'];
    if (lines.any((l) => l.isCleaning)) {
      final sqm = _parsedHomeSqm;
      if (sqm == null) return bf['needArea'];
      if (_matchCleaningTier(sqm) == null) return bf['needAreaMatch'];
    }
    return null;
  }

  BookField _step1Field(String? err) {
    if (err == bf['needArea'] || err == bf['needAreaMatch']) return BookField.area;
    return BookField.services;
  }

  String? _step2Error() {
    final addr = _selectedAddress();
    if (addr == null || addr.id.isEmpty) return bf['needAddress'];
    if (p!.areas.isNotEmpty && !p!.areas.contains(addr.area)) {
      return langOf(ref) == 'ar'
          ? 'المتخصصة دي مش بتغطي منطقة عنوانك. غيّري العنوان لمنطقة تغطيتها.'
          : 'This professional doesn’t cover your address area. Pick a covered area or another pro.';
    }
    if (days.isEmpty) return bf['needSlot'];
    final slots = (days[day]['slots'] as List?) ?? const [];
    if (slot < 0 || slot >= slots.length || (slots[slot] as Map)['available'] == false) return bf['needSlot'];
    return null;
  }

  BookField _step2Field(String? err) {
    if (err == bf['needSlot'] || err == bf['slotTaken']) return BookField.slot;
    return BookField.address;
  }

  void _clearFieldError(BookField field) {
    if (errorField != field && formError == null) return;
    if (errorField != null && errorField != field) return;
    setState(() {
      formError = null;
      errorField = null;
    });
  }

  void _fail(String msg, BookField field) {
    tapLight();
    setState(() {
      formError = msg;
      errorField = field;
      toastMessage = msg;
      toastNonce++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = switch (field) {
        BookField.services => servicesKey.currentContext,
        BookField.area => areaKey.currentContext,
        BookField.slot => slotKey.currentContext,
        BookField.address => addressKey.currentContext,
      };
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.12, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _goStep2() async {
    final err = _step1Error();
    if (err != null) {
      _fail(err, _step1Field(err));
      return;
    }
    unawaited(AppAnalytics.bookStepAdvanced(providerId: p!.id, step: 2));
    _touch(() {
      screen = 2;
      formError = null;
      errorField = null;
      toastMessage = null;
    });
    await _refreshAvailability(force: true);
  }

  Future<void> _goPay() async {
    final err = _step2Error();
    if (err != null) {
      _fail(err, _step2Field(err));
      return;
    }
    setState(() {
      busy = true;
      formError = null;
    });
    final lang = langOf(ref);
    final payload = <Map<String, dynamic>>[];
    for (final l in lines) {
      payload.add({
        'guestLabel': lang == 'ar' ? 'إنتي' : 'You',
        'serviceItemId': l.item.id,
        'count': l.mult,
        if (l.item.needsHairLength) 'hairLength': hair,
      });
    }
    try {
      unawaited(AppAnalytics.bookStepAdvanced(providerId: p!.id, step: 3));
      final created = await ref.read(repoProvider).createBooking(
            providerId: p!.id,
            serviceItemId: '${payload.first['serviceItemId']}',
            slot: slotTime(),
            addressId: _selectedAddress()!.id,
            notes: notes.text,
            saveInstruction: notes.text.trim().isNotEmpty,
            guests: payload,
            couponCode: couponOk ? appliedCoupon : null,
            toolsFromProvider: toolsFromProvider && lines.any((l) => l.isCleaning),
          );
      await ref.read(sessionProvider.notifier).refreshMe();
      if (mounted) context.push('/checkout/${created.booking.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSlotTaken || e.status == 409) {
        _fail(bf['slotTaken'] ?? err ?? '', BookField.slot);
        await _refreshAvailability(force: true);
      } else {
        _fail(friendlyError(e, lang), BookField.slot);
      }
    } catch (e) {
      if (!mounted) return;
      _fail(friendlyError(e, lang), BookField.slot);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.of(context).push<Address?>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AddressFormScreen(returnResult: true)),
    );
    if (!mounted) return;
    final addrsNow = ref.read(sessionProvider).user?.addresses ?? [];
    final pick = saved ?? (addrsNow.isNotEmpty ? addrsNow.last : null);
    if (pick == null) return;
    _clearFieldError(BookField.address);
    _touch(() => addressId = pick.id);
    await ref.read(sessionProvider.notifier).patchMe(defaultAddressId: pick.id);
    unawaited(AppAnalytics.bookingAddressSelected(providerId: p!.id, area: pick.area));
    await _refreshAvailability(force: true);
  }

  void _browseServices() {
    final verts = verticals;
    final target = verts.contains('cleaning') ? 'cleaning' : (verts.isEmpty ? null : verts.first);
    if (target != null && target != activeVertical) {
      _touch(() => _activeVertical = target);
      unawaited(AppAnalytics.bookCategorySwitched(providerId: p!.id, vertical: target));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final copy = bf;
    if (p == null && loadError != null) {
      final online = ref.watch(sessionProvider).online;
      return Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ClientFlowHeader(title: copy['title1'] ?? '', onBack: () => context.pop()),
              Expanded(
                child: online
                    ? OnsEmpty.fetchFailed(lang: lang, onRetry: _load, onSupport: () => unawaited(openExternal('https://wa.me/201117198333')))
                    : OnsEmpty.offline(lang: lang, onRetry: _load),
              ),
            ],
          ),
        ),
      );
    }
    if (p == null) {
      final ec = Copy.of(lang)['empty'] as Map;
      return Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: Column(
            children: [
              ClientFlowHeader(title: copy['title1'] ?? '', onBack: () => context.pop()),
              Expanded(
                child: SingleChildScrollView(
                  child: ServiceListSkeleton(heading: copy['title1'] ?? '', caption: '${ec['skeletonCaption']}'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final steps = [copy['step1'] ?? '', copy['step2'] ?? '', copy['step3'] ?? ''];
    final empty = !cartReady;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientFlowHeader(
              title: screen == 1 ? (copy['title1'] ?? '') : (copy['title2'] ?? ''),
              onBack: () {
                if (screen == 2) {
                  _touch(() => screen = 1);
                } else {
                  context.pop();
                }
              },
            ),
            ClientBookingStepper(
              step: screen,
              labels: steps,
              cartReady: cartReady,
              onSegmentTap: (n) {
                if (n == 1) _touch(() => screen = 1);
                if (n == 2 && cartReady) unawaited(_goStep2());
                if (n == 3 && cartReady) {
                  if (screen == 1) {
                    unawaited(_goStep2());
                  } else {
                    unawaited(_goPay());
                  }
                }
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    controller: scroll,
                    children: [
                      if (notice == 'hold_expired')
                        BookFieldFrame(
                          invalid: true,
                          message: copy['holdExpired'],
                          child: const SizedBox(height: 8),
                        ),
                      if (screen == 1) ..._step1(lang, copy) else ..._step2(lang, copy),
                      const SizedBox(height: 24),
                    ],
                  ),
                  if (toastMessage != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: BookErrorToast(
                        key: ValueKey('toast-$toastNonce'),
                        message: toastMessage!,
                        onDismiss: () {
                          if (mounted) setState(() => toastMessage = null);
                        },
                      ),
                    ),
                ],
              ),
            ),
            ClientStickyBar(
              label: empty ? (copy['barEmpty'] ?? '') : (copy['barTotal'] ?? ''),
              sub: empty ? copy['barEmptySub'] : copy['barFeesIn'],
              price: empty ? '—' : money(inclusive, lang),
              cta: screen == 1 ? (copy['ctaSlot'] ?? '') : (copy['ctaPay'] ?? ''),
              busy: busy,
              busyLabel: copy['confirming'] ?? '',
              enabled: !busy && !empty && ref.watch(sessionProvider).online,
              onTap: () {
                if (screen == 1) {
                  unawaited(_goStep2());
                } else {
                  unawaited(_goPay());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _step1(String lang, Map<String, String> copy) {
    final counts = <String, int>{};
    for (final v in verticals) {
      counts[v] = p!.items.where((e) => e.active && (e.vertical ?? p!.service) == v).length;
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: BookCategoryTabs(
          verticals: verticals,
          active: activeVertical,
          counts: counts,
          bf: copy,
          onSelect: (v) {
            _touch(() => _activeVertical = v);
            unawaited(AppAnalytics.bookCategorySwitched(providerId: p!.id, vertical: v));
          },
        ),
      ),
      BookFieldFrame(
        key: servicesKey,
        invalid: errorField == BookField.services,
        message: errorField == BookField.services ? formError : null,
        child: Column(
          children: [
            ...visibleItems.map((it) {
              final q = qty[it.id] ?? 0;
              final note = it.isCleaning
                  ? cleaningSizeMeta(fromSqm: it.sizeFromSqm, toSqm: it.sizeToSqm, workers: it.workerCount, ar: lang == 'ar')
                  : (lang == 'ar' ? '${digits(it.duration, ar: true)} د' : '${it.duration} min');
              final includes = it.isCleaning
                  ? cleaningIncludeIds(it).map((id) => cleaningTaskNames[id]?.of(lang) ?? id).where((e) => e.isNotEmpty).toList()
                  : it.benefits.map((b) => b.of(lang)).where((e) => e.isNotEmpty).toList();
              final excludes = it.isCleaning
                  ? cleaningExcludeIds(it).map((id) => cleaningTaskNames[id]?.of(lang) ?? id).where((e) => e.isNotEmpty).toList()
                  : const <String>[];
              return BookServiceRow(
                name: it.name.of(lang),
                note: note,
                price: money(it.price, lang),
                qty: q,
                expanded: expandedId == it.id,
                onInc: () {
                  _clearFieldError(BookField.services);
                  unawaited(_setQty(it, q + 1));
                },
                onDec: () {
                  _clearFieldError(BookField.services);
                  unawaited(_setQty(it, q - 1));
                },
                onToggle: () {
                  final open = expandedId != it.id;
                  _touch(() => expandedId = open ? it.id : null);
                  unawaited(AppAnalytics.bookDetailsToggled(providerId: p!.id, serviceItemId: it.id, open: open));
                },
                includes: includes,
                excludes: excludes,
                includesLabel: copy['includes'] ?? '',
                excludesLabel: copy['excludes'] ?? '',
                detailsOpen: copy['detailsOpen'] ?? '',
                detailsClose: copy['detailsClose'] ?? '',
              );
            }),
            if (!cartReady) OnsEmpty.nothingPicked(lang: lang, cleaning: verticals.contains('cleaning'), onBrowse: _browseServices),
          ],
        ),
      ),
      if (showCleaningFields) ..._cleaningFields(lang, copy),
      if (showBeautyFields) ..._beautyFields(lang, copy),
    ];
  }

  List<Widget> _cleaningFields(String lang, Map<String, String> copy) {
    final tiers = p!.items.where((e) => e.isCleaning && e.active).toList()..sort((a, b) => a.sizeFromSqm.compareTo(b.sizeFromSqm));
    final match = _parsedHomeSqm == null ? null : _matchCleaningTier(_parsedHomeSqm!);
    return [
      const ClientDivider(),
      BookFieldFrame(
        key: areaKey,
        invalid: errorField == BookField.area,
        message: errorField == BookField.area ? formError : null,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookMonoKicker(copy['fieldsClean'] ?? ''),
            const SizedBox(height: 6),
            Text(copy['hintClean'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4, color: Client.muted)),
            const SizedBox(height: 14),
            Text(copy['homeSize'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tiers.map((tier) {
                final label = tier.sizeToSqm != null
                    ? '${digits(tier.sizeFromSqm, ar: lang == 'ar')}–${digits(tier.sizeToSqm, ar: lang == 'ar')} ${copy['sqm']}'
                    : '${digits(tier.sizeFromSqm, ar: lang == 'ar')}+ ${copy['sqm']}';
                final on = match?.id == tier.id;
                return BookChip(
                  label: label,
                  selected: on,
                    onTap: () {
                    final rep = tier.sizeFromSqm > 0 ? tier.sizeFromSqm : (tier.sizeToSqm ?? 1);
                    homeSqm.text = '$rep';
                    _clearFieldError(BookField.area);
                    _applySqm(fromChip: true);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: homeSqm,
              keyboardType: TextInputType.number,
              inputFormatters: [ArabicDigitsFormatter()],
              onChanged: (_) {
                _clearFieldError(BookField.area);
                _applySqm();
              },
              decoration: InputDecoration(
                hintText: copy['homeSizePh'],
                filled: true,
                fillColor: Client.card,
                enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
              ),
            ),
            if (_parsedHomeSqm != null) ...[
              const SizedBox(height: 8),
              Text(
                match == null
                    ? (copy['needAreaMatch'] ?? '')
                    : crewLine(workers: match.workerCount < 1 ? 1 : match.workerCount, durationMin: match.duration, ar: lang == 'ar'),
                style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: match == null ? T.danger : Client.ink),
              ),
            ],
          ],
        ),
      ),
      ),
    ];
  }

  List<Widget> _beautyFields(String lang, Map<String, String> copy) {
    ServiceItem? hairItem;
    for (final l in lines) {
      if (l.item.needsHairLength) {
        hairItem = l.item;
        break;
      }
    }
    return [
      const ClientDivider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookMonoKicker(copy['fieldsBeauty'] ?? ''),
            const SizedBox(height: 6),
            Text(copy['hintBeauty'] ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4, color: Client.muted)),
            const SizedBox(height: 14),
            Text(copy['guestsQ'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(copy['guestsHint'] ?? '', style: const TextStyle(fontSize: 12, color: Client.muted)),
            const SizedBox(height: 8),
            BookStepperControl(
              qty: guests,
              min: 1,
              max: 6,
              onDec: () {
                _touch(() => guests = (guests - 1).clamp(1, 6));
                unawaited(AppAnalytics.bookFieldChanged(providerId: p!.id, field: 'guests'));
              },
              onInc: () {
                _touch(() => guests = (guests + 1).clamp(1, 6));
                unawaited(AppAnalytics.bookFieldChanged(providerId: p!.id, field: 'guests'));
              },
            ),
            if (showHair && hairItem != null) ...[
              const SizedBox(height: 16),
              Text(copy['hair'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final key in ['short', 'medium', 'long']) ...[
                    if (key != 'short') const SizedBox(width: 8),
                    BookChip(
                      expanded: true,
                      label: copy[key == 'short' ? 'hairShort' : key == 'long' ? 'hairLong' : 'hairMedium'] ?? key,
                      selected: hair == key,
                      onTap: () {
                        _touch(() => hair = key);
                        unawaited(AppAnalytics.bookFieldChanged(providerId: p!.id, field: 'hair'));
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final add = hairAddFor(hairItem!, hair);
                if (add <= 0) return Text(copy['hairNone'] ?? '', style: const TextStyle(fontSize: 12, color: Client.muted));
                return Text('${money(add, lang)} ${copy['hairAdd']}', style: const TextStyle(fontSize: 12, color: Client.muted));
              }),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _step2(String lang, Map<String, String> copy) {
    final addrs = ref.watch(sessionProvider).user?.addresses ?? const <Address>[];
    final addr = _selectedAddress();
    final travel = bookTravel(lines);
    final ec = Copy.of(lang)['empty'] as Map;
    final daySlots = days.isEmpty ? const [] : ((days[day]['slots'] as List?) ?? const []);
    final dayTaken = days.isEmpty || daySlots.every((s) => (s as Map)['available'] == false);
    int? nextIdx;
    int? nextFree;
    if (days.isNotEmpty) {
      for (var k = day + 1; k < days.length; k++) {
        final n = ((days[k]['slots'] as List?) ?? const []).where((s) => (s as Map)['available'] != false).length;
        if (n > 0) {
          nextIdx = k;
          nextFree = n;
          break;
        }
      }
    }
    String dayWord(int k) {
      final d = DateTime.tryParse('${days[k]['date']}') ?? DateTime.now();
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) return '${ec['today']}';
      return '${weekdayLabel(d, lang)} ${digits(d.day, ar: lang == 'ar')}';
    }
    return [
      BookFieldFrame(
        key: slotKey,
        invalid: errorField == BookField.slot,
        message: errorField == BookField.slot ? formError : null,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookMonoKicker(copy['when'] ?? ''),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: List.generate(days.length.clamp(0, 5), (i) {
                  final on = day == i;
                  final date = DateTime.tryParse('${days[i]['date']}') ?? DateTime.now();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: on,
                        child: InkWell(
                          onTap: () {
                            _clearFieldError(BookField.slot);
                            _touch(() => day = i);
                            unawaited(AppAnalytics.bookingSlotSelected(providerId: p!.id, slotStart: slotTime().toIso8601String()));
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Client.card),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekdayLabel(date, lang), style: TextStyle(fontFamily: T.mono, fontSize: 10, color: on ? Client.bg : Client.ink)),
                                Text(digits('${date.day}'.padLeft(2, '0'), ar: lang == 'ar'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? Client.bg : Client.ink)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            if (dayTaken)
              OnsEmpty.noAvailability(
                lang: lang,
                area: areaName(_selectedAddress()?.area ?? (p!.areas.isNotEmpty ? p!.areas.first : ''), lang),
                day: days.isEmpty ? '' : dayWord(day),
                nextDayLabel: nextIdx == null ? null : dayWord(nextIdx),
                nextCount: nextFree,
                onNext: () {
                  final idx = nextIdx;
                  if (idx == null) {
                    unawaited(_refreshAvailability(force: true));
                    return;
                  }
                  _clearFieldError(BookField.slot);
                  _touch(() => day = idx);
                  unawaited(AppAnalytics.bookingSlotSelected(providerId: p!.id, slotStart: slotTime().toIso8601String()));
                },
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.7,
                children: List.generate(((days[day]['slots'] as List?) ?? const []).length, (i) {
                  final s = (days[day]['slots'] as List)[i] as Map;
                  final avail = s['available'] != false;
                  final on = slot == i && avail;
                  return Semantics(
                    button: true,
                    enabled: avail,
                    selected: on,
                    child: InkWell(
                      onTap: avail
                          ? () {
                              tapLight();
                              _clearFieldError(BookField.slot);
                              _touch(() {
                                slot = i;
                                notice = null;
                              });
                              unawaited(AppAnalytics.bookingSlotSelected(providerId: p!.id, slotStart: slotTime().toIso8601String()));
                            }
                          : null,
                      mouseCursor: avail ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: on ? Client.plum : (avail ? Client.ink : Client.line), width: Client.rule),
                          color: on ? Client.plum : (avail ? Client.card : Client.sand),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              availabilitySlotLabel(s, lang),
                              style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: on ? Client.bg : (avail ? Client.ink : Client.muted2)),
                            ),
                            Text(
                              on ? (copy['slotPicked'] ?? '') : (avail ? (copy['slotFree'] ?? '') : (copy['slotBusy'] ?? '')),
                              style: TextStyle(fontSize: 10, color: on ? Client.bg : Client.muted2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
      ),
      const ClientDivider(),
      BookFieldFrame(
        key: addressKey,
        invalid: errorField == BookField.address,
        message: errorField == BookField.address ? formError : null,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookMonoKicker(copy['where'] ?? ''),
            const SizedBox(height: 10),
            if (addrs.isEmpty) OnsEmpty.noAddress(lang: lang, onAdd: _addAddress),
            ...addrs.map((a) {
              final on = addr?.id == a.id;
              final covered = p!.areas.isEmpty || p!.areas.contains(a.area);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  selected: on,
                  child: InkWell(
                    onTap: () async {
                      _clearFieldError(BookField.address);
                      _touch(() => addressId = a.id);
                      await ref.read(sessionProvider.notifier).patchMe(defaultAddressId: a.id);
                      unawaited(AppAnalytics.bookingAddressSelected(providerId: p!.id, area: a.area));
                      await _refreshAvailability(force: true);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule), color: on ? Client.plumTint : Client.card),
                      child: Row(
                        children: [
                          Text(
                            covered && travel > 0 ? money(travel, lang) : (copy['travel'] ?? ''),
                            style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.muted),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Colors.transparent)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${a.label.of(lang)} · ${a.line1.of(lang)} · ${areaName(a.area, lang)}',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            Semantics(
              button: true,
              child: InkWell(
                onTap: _addAddress,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule, style: BorderStyle.solid)),
                  foregroundDecoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                  child: Text(copy['newAddress'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      const ClientDivider(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookMonoKicker(copy['notes'] ?? ''),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _chipIds.map((id) {
                return BookChip(label: _chipLabel(id), selected: noteChipIds.contains(id), onTap: () => _toggleChip(id));
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => _schedulePersist(),
              decoration: InputDecoration(
                hintText: copy['notesPh'],
                filled: true,
                fillColor: Client.card,
                enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
              ),
            ),
            const SizedBox(height: 8),
            Text(copy['notesFoot'] ?? '', style: const TextStyle(fontSize: 11.5, height: 1.4, color: Client.muted2)),
          ],
        ),
      ),
      const ClientDivider(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: couponOpen,
              child: InkWell(
                onTap: () => setState(() => couponOpen = !couponOpen),
                child: Row(
                  children: [
                    Text(couponOpen ? '−' : '+', style: const TextStyle(fontFamily: T.mono, fontSize: 16, color: Client.muted)),
                    const SizedBox(width: 8),
                    Text(copy['couponQ'] ?? '', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            if (couponOpen) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: coupon,
                      enabled: !couponBusy,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: copy['couponPh'],
                        prefixIcon: couponBusy
                            ? const Padding(padding: EdgeInsets.all(12), child: InlineSpinner())
                            : null,
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
                    child: ClientGhostButton(label: copy['couponApply'] ?? '', onTap: couponBusy ? null : _applyCoupon),
                  ),
                ],
              ),
              if (couponMessage != null) ...[
                const SizedBox(height: 8),
                Text(couponMessage!, style: TextStyle(fontSize: 12.5, color: couponOk ? Client.oliveInk : T.danger, fontWeight: couponOk ? FontWeight.w700 : FontWeight.w400)),
              ],
            ],
          ],
        ),
      ),
    ];
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

  Future<void> _manualRefresh(String lang) async {
    try {
      final b = await ref.read(repoProvider).checkPay(widget.bookingId);
      if (!mounted) return;
      setState(() => data = b);
      if (b.booking.status == 'paid') {
        t?.cancel();
        await ref.read(repoProvider).ensurePurchaseTracked(b);
        if (!mounted) return;
        context.go('/confirmed/${b.booking.id}');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'ar' ? 'لسه مفيش تأكيد دفع.' : 'No payment confirmation yet.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
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
              title: cardPending ? (lang == 'ar' ? 'بنتأكد من الدفع' : 'Confirming payment') : (lang == 'ar' ? 'الدفع من فوري' : 'Fawry payment'),
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
                      Text(lang == 'ar' ? 'خلّصي الدفع في نافذة بايموب، وبعدين ارجعي هنا.' : 'Finish in the Paymob window, then return here.', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Text(lang == 'ar' ? 'بنحدّث الحالة تلقائي كل شوية.' : 'We refresh the status automatically.', style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      ClientGhostButton(label: lang == 'ar' ? 'حدّث الآن' : 'Refresh now', onTap: () => _manualRefresh(lang)),
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
                      ClientGhostButton(label: '${f['paid']}', onTap: () => _manualRefresh(lang)),
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
