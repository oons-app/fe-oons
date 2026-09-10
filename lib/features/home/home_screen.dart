import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/reviews.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/client/client_tour.dart';
import 'package:oons/features/reviews/reviews_screens.dart';
import 'package:oons/l10n/copy.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final searchKey = GlobalKey();
  final trustKey = GlobalKey();
  final servicesKey = GlobalKey();
  final navHintKey = GlobalKey();
  final searchCtrl = TextEditingController();
  bool showTour = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!clientTourDone()) {
        setState(() => showTour = true);
      }
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  /// Map free-text to a vertical when the query is clearly a service name.
  String _serviceForQuery(String raw, String lang) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return 'beauty';
    final cleaning = ['cleaning', 'clean', 'house', 'منزل', 'تنظيف', 'نظافة', 'بيت'];
    final chef = ['chef', 'cook', 'cooking', 'شيف', 'طبخ', 'مطبخ', 'طعام'];
    final beauty = ['beauty', 'salon', 'hair', 'nail', 'makeup', 'تجميل', 'صالون', 'شعر', 'مكياج', 'عناية'];
    bool hit(List<String> keys) => keys.any((k) => q.contains(k) || k.contains(q));
    if (hit(cleaning)) return 'cleaning';
    if (hit(chef)) return 'chef';
    if (hit(beauty)) return 'beauty';
    return 'all';
  }

  void _runSearch([String? raw]) {
    final q = (raw ?? searchCtrl.text).trim();
    final service = _serviceForQuery(q, langOf(ref));
    final path = q.isEmpty
        ? '/browse/$service'
        : '/browse/$service?q=${Uri.encodeComponent(q)}';
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    if (!clientTourDone() && !showTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !clientTourDone() && !showTour) {
          setState(() => showTour = true);
        }
      });
    }
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final h = t['home'] as Map;
    final svc = t['svc'] as Map;
    final occ = t['occ'] as Map;
    final tour = t['tour'] as Map;
    final user = ref.watch(sessionProvider).user;

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(repoProvider).home(),
      builder: (context, snap) {
        if (snap.hasError && snap.data == null) {
          return const _HomeSkeleton();
        }
        final data = snap.data;
        final area = '${data?['area'] ?? user?.area ?? 'zamalek'}';
        final name = user?.firstName.of(lang) ?? (lang == 'ar' ? 'نور' : 'Nour');
        final services = ((data?['services'] as List?) ?? []).cast<Map>();
        final rebooks = ((data?['rebooks'] as List?) ?? []).cast<Map>();
        final nearby = ((data?['nearby'] as List?) ?? []).cast<Map>();
        final occasions = ((data?['occasions'] as List?) ?? ['wedding', 'engagement', 'eid', 'graduation']);
        final addr = user?.addresses.where((a) => a.isDefault).firstOrNull ?? user?.addresses.firstOrNull;
        final street = addr?.line1.of(lang).trim() ?? '';
        final areaLabel = addr != null ? areaName(addr.area, lang) : areaName(area, lang);
        final addrLine = street.isEmpty
            ? areaLabel
            : (street.length > 28 ? '$areaLabel · ${street.substring(0, 28)}…' : '$areaLabel · $street');

        return Stack(
          children: [
            ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(greet(DateTime.now(), lang, name), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: Client.ink)),
                                const SizedBox(height: 6),
                                ClientAddressChip(
                                  line: addrLine,
                                  changeLabel: lang == 'ar' ? 'تغيير' : 'Change',
                                  onTap: () => context.push('/me/addresses'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClientSquareBtn(label: lang == 'ar' ? 'EN' : 'ع', onTap: () => ref.read(localeProvider.notifier).toggle()),
                          const SizedBox(width: 8),
                          ClientSquareBtn(
                            label: (user?.initials.of(lang).isNotEmpty == true ? user!.initials.of(lang).characters.first : 'ن'),
                            filled: true,
                            onTap: () => context.push('/profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      KeyedSubtree(
                        key: searchKey,
                        child: ClientSearchField(
                          hint: lang == 'ar' ? 'دوري على خدمة أو متخصصة…' : 'Search for a service or pro…',
                          controller: searchCtrl,
                          onSubmitted: _runSearch,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => _runSearch(),
                          child: Text(
                            lang == 'ar' ? 'بحث ←' : 'Search →',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                KeyedSubtree(
                  key: trustKey,
                  child: ClientTrustBanner(
                    text: '${h['trust']}',
                    link: lang == 'ar' ? 'اعرفي أكتر ›' : 'Learn more ›',
                    onTap: () => showClientVerifiedSheet(
                      context,
                      title: '${tour['trustTitle']}',
                      body: '${h['trust']}',
                      lang: lang,
                    ),
                  ),
                ),
                FutureBuilder<List<BookingBundle>>(
                  future: ref.read(repoProvider).bookings('upcoming'),
                  builder: (context, upSnap) {
                    final upcoming = (upSnap.data ?? []).isNotEmpty ? upSnap.data!.first : null;
                    if (upcoming == null) return const SizedBox.shrink();
                    final b = upcoming.booking;
                    final states = Copy.of(lang)['states'] as Map;
                    final st = (states[b.status] as Map?) ?? {};
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (lang == 'ar' ? 'زيارتك الجاية' : 'Your next visit').toUpperCase(),
                                style: const TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: Client.muted2),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => context.go('/bookings'),
                                child: Text(
                                  lang == 'ar' ? 'كل الحجوزات' : 'All bookings',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _UpcomingCard(bundle: upcoming, lang: lang, statusLabel: '${st['code'] ?? b.status}'),
                        ],
                      ),
                    );
                  },
                ),
                if (rebooks.isNotEmpty) ...[
                  ClientSectionLabel('${h['rebook']}'),
                  ...rebooks.take(2).map((r) {
                    final ini = Loc.fromJson(r['initials']);
                    final nm = Loc.fromJson(r['name']);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Material(
                        color: Client.card,
                        child: InkWell(
                          onTap: () => context.push('/provider/${r['providerId']}'),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                            child: Row(
                              children: [
                                _monoAvatar(ini.of(lang)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nm.of(lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.ink)),
                                      Text(Loc.fromJson(r['specialty']).of(lang), style: const TextStyle(fontSize: 12.5, color: Client.muted)),
                                    ],
                                  ),
                                ),
                                Text(lang == 'ar' ? 'احجزي تاني' : 'Rebook', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.plum)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                KeyedSubtree(
                  key: servicesKey,
                  child: ClientSectionLabel('${h['services']}', trailing: lang == 'ar' ? 'شوفي الكل' : 'See all', onTrailing: () => context.push('/browse/beauty')),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref.read(repoProvider).categories(includeLocked: true, area: area),
                  builder: (context, catSnap) {
                    final cats = catSnap.data ?? const <Map<String, dynamic>>[];
                    final byVertical = <String, List<Map<String, dynamic>>>{};
                    for (final c in cats) {
                      final v = '${c['vertical'] ?? ''}';
                      byVertical.putIfAbsent(v, () => []).add(c);
                    }
                    bool lockedVertical(String id) {
                      final matches = services.where((e) => '${e['id']}' == id);
                      if (matches.isNotEmpty && matches.first['locked'] == true) return true;
                      final rows = byVertical[id] ?? [];
                      if (rows.isEmpty) return id == 'childcare' || id == 'chef';
                      return rows.every((e) => e['status'] == 'locked_teaser' || e['locked'] == true);
                    }
                    bool availableVertical(String id) {
                      if (lockedVertical(id)) return false;
                      final matches = services.where((e) => '${e['id']}' == id);
                      if (matches.isNotEmpty && matches.first.containsKey('availableInArea')) {
                        return matches.first['availableInArea'] == true;
                      }
                      final rows = byVertical[id] ?? [];
                      return rows.any((e) => e['availableInArea'] == true);
                    }
                    String meta(String id) {
                      if (lockedVertical(id)) return '';
                      final matches = services.where((e) => '${e['id']}' == id);
                      final inArea = matches.isEmpty
                          ? 0
                          : ((matches.first['providerCountInArea'] as num?)?.toInt() ?? 0);
                      if (availableVertical(id)) {
                        if (inArea > 0) {
                          return lang == 'ar' ? '$inArea ${h['prosNearYou']}' : '$inArea ${h['prosNearYou']}';
                        }
                        return '${h['availableHere']}';
                      }
                      return '${h['notInArea']}';
                    }
                    final tileDefs = <({String id, Color bg, Color fg, String icon, bool locked})>[
                      (id: 'beauty', bg: const Color(0xFFB5654B), fg: Client.bg, icon: '✂', locked: lockedVertical('beauty')),
                      (id: 'cleaning', bg: Client.card, fg: Client.ink, icon: '✳', locked: lockedVertical('cleaning')),
                      (id: 'chef', bg: Client.card, fg: Client.ink, icon: '♨', locked: lockedVertical('chef')),
                      (id: 'childcare', bg: Client.sand2, fg: Client.ink, icon: '☺', locked: lockedVertical('childcare')),
                    ];
                    tileDefs.sort((a, b) {
                      final aa = availableVertical(a.id);
                      final ba = availableVertical(b.id);
                      if (aa != ba) return aa ? -1 : 1;
                      if (a.locked != b.locked) return a.locked ? 1 : -1;
                      return 0;
                    });
                    Widget rowFor(List<({String id, Color bg, Color fg, String icon, bool locked})> pair, {required bool bottom}) {
                      return Row(
                        children: [
                          for (var i = 0; i < pair.length; i++)
                            Expanded(
                              child: _svcTile(
                                context,
                                pair[i].id,
                                svc,
                                services,
                                pair[i].bg,
                                pair[i].fg,
                                meta(pair[i].id),
                                locked: pair[i].locked,
                                icon: pair[i].icon,
                                leftBorder: i == 1,
                                bottom: bottom,
                                availableInArea: availableVertical(pair[i].id),
                              ),
                            ),
                        ],
                      );
                    }
                    return DecoratedBox(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink, width: Client.rule))),
                      child: Column(
                        children: [
                          rowFor(tileDefs.take(2).toList(), bottom: false),
                          rowFor(tileDefs.skip(2).take(2).toList(), bottom: true),
                        ],
                      ),
                    );
                  },
                ),
                if (nearby.isNotEmpty) ...[
                  ClientSectionLabel(
                    lang == 'ar' ? 'متخصصات قريب منك' : 'Pros near you',
                    trailing: lang == 'ar' ? 'شوفي الكل' : 'See all',
                    onTrailing: () => context.push('/browse/beauty'),
                  ),
                  ...nearby.take(4).map((r) {
                    final ini = Loc.fromJson(r['initials']);
                    final nm = Loc.fromJson(r['name']);
                    final spec = Loc.fromJson(r['specialty']);
                    final rating = (r['rating'] as num?)?.toDouble() ?? 0;
                    final reviews = (r['reviewCount'] as num?)?.toInt() ?? 0;
                    final from = (r['priceFrom'] as num?)?.toInt() ?? 0;
                    final pid = '${r['providerId']}';
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Material(
                        color: Client.card,
                        child: InkWell(
                          onTap: () => context.push('/provider/$pid'),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                            child: Row(
                              children: [
                                Face(id: pid, ini: ini.of(lang), size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nm.of(lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.ink)),
                                      Text(spec.of(lang), style: const TextStyle(fontSize: 12.5, color: Client.muted)),
                                      const SizedBox(height: 4),
                                      Text(
                                        reviews > 0
                                            ? (lang == 'ar' ? '★ ${rating.toStringAsFixed(1)} · $reviews تقييم' : '★ ${rating.toStringAsFixed(1)} · $reviews reviews')
                                            : (lang == 'ar' ? 'جديدة على أنس' : 'New on Oons'),
                                        style: const TextStyle(fontSize: 12, color: Client.body),
                                      ),
                                    ],
                                  ),
                                ),
                                if (from > 0)
                                  Text(
                                    lang == 'ar' ? 'من ${money(from, lang)}' : 'from ${money(from, lang)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.plum),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                FutureBuilder(
                  future: ref.read(repoProvider).reviews(),
                  builder: (context, snap) {
                    final rows = (snap.data ?? const <Review>[]).take(2).toList();
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Row(
                            children: [
                              Text(
                                '${h['reviews']}'.toUpperCase(),
                                style: const TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: Client.muted2),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => context.push('/reviews'),
                                child: Text(
                                  '${h['seeReviews']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...rows.map(
                          (r) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ReviewCard(
                              review: r,
                              lang: lang,
                              showPro: true,
                              onTap: () => context.push('/reviews/${r.providerId}'),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: ClientGhostButton(label: '${h['browseReviews']}', onTap: () => context.push('/reviews')),
                        ),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${h['occasions']}'.toUpperCase(),
                        style: const TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: Client.muted2),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: occasions.map((o) {
                          final id = '$o';
                          return InkWell(
                            onTap: () => context.push('/browse/beauty'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                              child: Text('${occ[id] ?? id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Client.ink)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: navHintKey,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
                          child: Text(
                            lang == 'ar' ? 'حجوزاتك وحسابك من التبويبات تحت.' : 'Bookings and account live in the tabs below.',
                            style: const TextStyle(fontSize: 12.5, color: Client.body),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showTour)
              Positioned.fill(
                child: ClientTourOverlay(
                  steps: [
                    ClientTourStep(targetKey: searchKey, title: '${tour['searchTitle']}', body: '${tour['searchBody']}'),
                    ClientTourStep(targetKey: trustKey, title: '${tour['trustTitle']}', body: '${tour['trustBody']}'),
                    ClientTourStep(targetKey: servicesKey, title: '${tour['servicesTitle']}', body: '${tour['servicesBody']}'),
                    ClientTourStep(targetKey: navHintKey, title: '${tour['navTitle']}', body: '${tour['navBody']}'),
                  ],
                  skipLabel: '${t['skip']}',
                  nextLabel: lang == 'ar' ? 'التالي' : 'Next',
                  doneLabel: lang == 'ar' ? 'تمام' : 'Got it',
                  onDone: () async {
                    await setClientTourDone(true);
                    if (mounted) setState(() => showTour = false);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _monoAvatar(String ini) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
      child: Text(ini, style: const TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w600, color: Client.ink)),
    );
  }

  Widget _svcTile(BuildContext context, String id, Map svc, List<Map> rows, Color bg, Color fg, String meta,
      {required bool locked, required String icon, bool leftBorder = false, bool bottom = false, bool availableInArea = false}) {
    final matches = rows.where((e) => e['id'] == id);
    final row = matches.isEmpty ? null : matches.first;
    final from = (row?['from'] as num?)?.toInt() ?? 0;
    final lang = Localizations.localeOf(context).languageCode;
    return Material(
      color: bg,
      child: InkWell(
        onTap: () {
          if (locked) {
            context.push('/empty');
            return;
          }
          context.push('/browse/$id');
        },
        child: Container(
          height: 168,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: const BorderSide(color: Client.ink, width: Client.rule),
              left: leftBorder ? const BorderSide(color: Client.ink, width: Client.rule) : BorderSide.none,
              bottom: bottom ? const BorderSide(color: Client.ink, width: Client.rule) : BorderSide.none,
              right: const BorderSide(color: Client.ink, width: Client.rule),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(icon, style: TextStyle(fontFamily: T.mono, fontSize: 18, color: fg)),
                  const Spacer(),
                  if (!locked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: availableInArea
                            ? (bg == Client.card ? const Color(0xFFE8F2EA) : fg.withValues(alpha: 0.18))
                            : (bg == Client.card ? Client.sand : fg.withValues(alpha: 0.12)),
                        border: Border.all(color: fg.withValues(alpha: 0.35), width: Client.rule),
                      ),
                      child: Text(
                        availableInArea ? (lang == 'ar' ? 'متاح' : 'Here') : (lang == 'ar' ? 'برّا' : 'Away'),
                        style: TextStyle(fontFamily: T.mono, fontSize: 10, fontWeight: FontWeight.w700, color: fg),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${svc[id]}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg, height: 1.15)),
                  const SizedBox(height: 3),
                  Text(
                    locked ? '${svc['coming']}' : '${svc['from']} ${from == 0 ? '' : money(from, lang)}',
                    style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w500, color: locked ? fg.withValues(alpha: 0.7) : (bg == Client.card ? Client.muted : fg.withValues(alpha: 0.9))),
                  ),
                  if (meta.isNotEmpty && !locked)
                    Text(meta, style: TextStyle(fontSize: 12, color: bg == Client.card ? Client.muted : fg.withValues(alpha: 0.9))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.bundle, required this.lang, required this.statusLabel});

  final BookingBundle bundle;
  final String lang;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final b = bundle.booking;
    final p = bundle.provider;
    final ini = p?.initials.of(lang) ?? '';
    final svc = b.serviceName.of(lang);
    return Container(
      decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
                  child: Text(ini, style: const TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p?.name(lang) ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.ink)),
                      Text('${formatSlot(b.slotStart, lang)} · $svc', style: const TextStyle(fontSize: 12.5, color: Client.muted)),
                    ],
                  ),
                ),
                ClientStatusChip(statusLabel),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Client.sand2, border: Border(top: BorderSide(color: Client.line, width: Client.rule), bottom: BorderSide(color: Client.line, width: Client.rule))),
            child: Text(
              lang == 'ar' ? 'تنبيه قبلها بـ٣ ساعات' : 'Reminder 3 hours before',
              style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Client.muted),
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                _action(lang == 'ar' ? 'شوفي التفاصيل' : 'Details', () => context.push('/booking/${b.id}'), defer: false),
                _action(lang == 'ar' ? 'تأجيل' : 'Reschedule', () => context.push('/reschedule/${b.id}'), defer: true, border: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap, {bool defer = false, bool border = false}) {
    return Expanded(
      child: Material(
        color: Client.card,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: border ? const Border(left: BorderSide(color: Client.line, width: Client.rule)) : null,
            ),
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: defer ? Client.defer : Client.ink)),
          ),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skel(width: 220, height: 28),
          SizedBox(height: 14),
          Skel(width: double.infinity, height: 48),
        ],
      ),
    );
  }
}
