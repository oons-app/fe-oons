import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/reviews.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/reviews/reviews_screens.dart';
import 'package:oons/l10n/copy.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, required this.service, this.initialQuery});
  final String service;
  final String? initialQuery;
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  late final TextEditingController _q;
  Timer? _debounce;
  String query = '';
  String? area;
  String dateMode = 'any';
  int? priceMax;
  String sort = 'rating';
  int minYears = 0;
  String? categoryId;
  List<Map<String, dynamic>> categories = [];
  bool catsLoaded = false;
  Future<List<ProviderP>>? _listFuture;
  String? _listKey;

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery?.trim() ?? '';
    _q = TextEditingController(text: query);
    final userArea = ref.read(sessionProvider).user?.area.trim();
    if (userArea != null && userArea.isNotEmpty) {
      area = userArea.toLowerCase();
    }
    _loadCategories();
    _refreshList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _refreshList() {
    final key = '${widget.service}|$query|$area|$priceMax|$categoryId|$sort|$minYears';
    if (_listKey == key && _listFuture != null) return;
    _listKey = key;
    _listFuture = ref.read(repoProvider).providers(
          service: widget.service == 'all' ? '' : widget.service,
          area: area,
          priceMax: priceMax,
          categoryId: categoryId,
          q: query,
          sort: sort,
          minYears: minYears > 0 ? minYears : null,
        );
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final q = v.trim();
      setState(() {
        query = q;
        _refreshList();
      });
      if (q.length >= 2) {
        unawaited(AppAnalytics.search(term: q, service: widget.service, area: area, categoryId: categoryId));
      }
    });
  }

  String? _lastListAnalyticsKey;

  void _trackList(List<ProviderP> list) {
    final key = '${widget.service}|$query|$area|$priceMax|$categoryId|$sort|$minYears|${list.length}';
    if (_lastListAnalyticsKey == key) return;
    _lastListAnalyticsKey = key;
    unawaited(AppAnalytics.viewItemList(
      service: widget.service,
      itemCount: list.length,
      area: area,
      categoryId: categoryId,
    ));
    if (query.length >= 2) {
      unawaited(AppAnalytics.search(
        term: query,
        service: widget.service,
        resultCount: list.length,
        area: area,
        categoryId: categoryId,
      ));
    }
  }

  Future<void> _loadCategories() async {
    try {
      final vertical = widget.service == 'all' ? null : widget.service;
      final userArea = ref.read(sessionProvider).user?.area.trim().toLowerCase();
      final rows = await ref.read(repoProvider).categories(
            vertical: vertical,
            activeOnly: true,
            area: area ?? userArea,
          );
      if (!mounted) return;
      setState(() {
        categories = rows;
        catsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => catsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final b = t['browse'] as Map;
    final svc = t['svc'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0, 1, 1),
                      child: const Glyph(GlyphKind.back, size: 20, color: Client.ink),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.service == 'all'
                          ? (lang == 'ar' ? 'نتائج البحث' : 'Search results')
                          : '${svc[widget.service] ?? widget.service}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Client.ink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ClientSearchField(
                hint: '${b['search']}',
                controller: _q,
                onChanged: _onQuery,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  final q = v.trim();
                  setState(() {
                    query = q;
                    _refreshList();
                  });
                },
                autofocus: (widget.initialQuery ?? '').isEmpty,
              ),
            ),
            if (categories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _catChip(lang == 'ar' ? 'الكل' : 'All', null, categoryId == null),
                    ...categories.map((c) {
                      final id = '${c['id']}';
                      final name = c['name'] is Map ? Loc.fromJson(c['name'] as Map).of(lang) : '${c['name'] ?? c['slug']}';
                      final available = c['availableInArea'] == true;
                      final hasAreaContext = (area ?? ref.read(sessionProvider).user?.area ?? '').trim().isNotEmpty;
                      final flag = !hasAreaContext
                          ? ''
                          : (available
                              ? (lang == 'ar' ? ' · ✓' : ' · ✓')
                              : (lang == 'ar' ? ' · ✕' : ' · ✕'));
                      return _catChip('$name$flag', id, categoryId == id, muted: hasAreaContext && !available);
                    }),
                  ],
                ),
              ),
            FutureBuilder<List<ProviderP>>(
              future: _listFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Expanded(child: _BrowseSkel());
                }
                if (snap.hasError) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ar' ? 'مقدرناش نحمّل النتائج.' : 'Could not load results.',
                            style: const TextStyle(color: Client.muted),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(_refreshList),
                            child: Text(lang == 'ar' ? 'حاولي تاني' : 'Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final list = _applyDate(snap.data ?? const []);
                _trackList(list);
                return Expanded(
                  child: ListView(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Client.card,
                          border: Border(top: BorderSide(color: Client.ink, width: Client.rule), bottom: BorderSide(color: Client.ink, width: Client.rule)),
                        ),
                        child: Row(
                          children: [
                            _filter(
                              area == null || area!.isEmpty ? '${b['anyArea']}' : areaName(area!, lang),
                              area != null && area!.isNotEmpty,
                              _openAdvanced,
                            ),
                            _filter(_dateLabel(b, lang), dateMode != 'any', _openAdvanced),
                            _filter(_priceLabel(b, lang), priceMax != null, _openAdvanced),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(child: ClientKicker('${list.length} ${b['count']}')),
                            TextButton(
                              onPressed: _openAdvanced,
                              child: Text('${b['advanced']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.plum)),
                            ),
                          ],
                        ),
                      ),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            lang == 'ar' ? 'مفيش متخصصات مطابقة للبحث ده.' : 'No professionals match this search.',
                            style: const TextStyle(color: Client.muted),
                          ),
                        ),
                      ...list.map(
                        (p) => _ProviderRow(
                          p: p,
                          fallbackArea: area,
                          bookLabel: '${b['quickBook']}',
                          fromLabel: '${b['from']}',
                          service: widget.service,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ProviderP> _applyDate(List<ProviderP> list) {
    if (dateMode == 'any') return list;
    final day = DateTime.now().add(Duration(days: dateMode == 'tomorrow' ? 1 : 0)).weekday;
    return list.where((p) => p.workDays.isEmpty || p.workDays.contains(day)).toList();
  }

  String _dateLabel(Map b, String lang) {
    if (dateMode == 'today') return '${b['today']}';
    if (dateMode == 'tomorrow') return '${b['tomorrow']}';
    return lang == 'ar' ? 'اليوم' : 'Date';
  }

  String _priceLabel(Map b, String lang) {
    if (priceMax == null) return '${b['anyPrice']}';
    return '${b['under']} ${money(priceMax!, lang)}';
  }

  Future<void> _openAdvanced() async {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final b = t['browse'] as Map;
    final areas = allCatalogAreaIds().toList()..sort();
    String? nextArea = area;
    String nextDate = dateMode;
    int? nextPrice = priceMax;
    String nextSort = sort;
    int nextYears = minYears;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Client.bg,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget chips<V>(List<(V, String)> opts, V value, ValueChanged<V> onPick) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: opts.map((o) {
                  final on = o.$1 == value;
                  return InkWell(
                    onTap: () => setSheet(() => onPick(o.$1)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: on ? Client.plum : Client.card,
                        border: Border.all(color: Client.ink, width: Client.rule),
                      ),
                      child: Text(o.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Client.bg : Client.ink)),
                    ),
                  );
                }).toList(),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b['advanced']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink)),
                      const SizedBox(height: 16),
                      ClientKicker(lang == 'ar' ? 'المنطقة' : 'Area'),
                      const SizedBox(height: 8),
                      chips<String?>(
                        [(null, '${b['anyArea']}'), ...areas.map((id) => (id, areaName(id, lang)))],
                        nextArea,
                        (v) => nextArea = v,
                      ),
                      const SizedBox(height: 16),
                      ClientKicker(lang == 'ar' ? 'اليوم' : 'Date'),
                      const SizedBox(height: 8),
                      chips<String>(
                        [('any', '${b['anyDate']}'), ('today', '${b['today']}'), ('tomorrow', '${b['tomorrow']}')],
                        nextDate,
                        (v) => nextDate = v,
                      ),
                      const SizedBox(height: 16),
                      ClientKicker(lang == 'ar' ? 'السعر' : 'Price'),
                      const SizedBox(height: 8),
                      chips<int?>(
                        [
                          (null, '${b['anyPrice']}'),
                          (40000, '${b['under']} ${money(40000, lang)}'),
                          (80000, '${b['under']} ${money(80000, lang)}'),
                          (120000, '${b['under']} ${money(120000, lang)}'),
                        ],
                        nextPrice,
                        (v) => nextPrice = v,
                      ),
                      const SizedBox(height: 16),
                      ClientKicker(lang == 'ar' ? 'الترتيب' : 'Sort'),
                      const SizedBox(height: 8),
                      chips<String>(
                        [
                          ('rating', '${b['sortRating']}'),
                          ('price', '${b['sortPrice']}'),
                          ('reviews', '${b['sortReviews']}'),
                        ],
                        nextSort,
                        (v) => nextSort = v,
                      ),
                      const SizedBox(height: 16),
                      ClientKicker('${b['minYears']}'),
                      const SizedBox(height: 8),
                      chips<int>(
                        [(0, '${b['anyYears']}'), (2, '2+'), (5, '5+'), (10, '10+')],
                        nextYears,
                        (v) => nextYears = v,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ClientGhostButton(
                              label: '${b['reset']}',
                              onTap: () => setSheet(() {
                                nextArea = null;
                                nextDate = 'any';
                                nextPrice = null;
                                nextSort = 'rating';
                                nextYears = 0;
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClientPrimaryButton(
                              label: '${b['apply']}',
                              onTap: () {
                                setState(() {
                                  area = nextArea;
                                  dateMode = nextDate;
                                  priceMax = nextPrice;
                                  sort = nextSort;
                                  minYears = nextYears;
                                  _refreshList();
                                });
                                unawaited(_loadCategories());
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _catChip(String label, String? id, bool on, {bool muted = false}) {
    final fg = on ? Client.bg : (muted ? Client.muted : Client.ink);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() {
          categoryId = id;
          _refreshList();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on ? Client.plum : Client.card,
            border: Border.all(color: muted && !on ? Client.muted : Client.ink, width: Client.rule),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  Widget _filter(String label, bool on, VoidCallback tap) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: on ? Client.plumTint : Client.card,
            border: const Border(right: BorderSide(color: Client.ink, width: Client.rule)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Client.plum : Client.muted),
          ),
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.p,
    required this.fallbackArea,
    required this.bookLabel,
    required this.fromLabel,
    required this.service,
  });
  final ProviderP p;
  final String? fallbackArea;
  final String bookLabel;
  final String fromLabel;
  final String service;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final area = p.areas.isEmpty ? (fallbackArea ?? '') : p.areas.first;
    return InkWell(
      onTap: () {
        unawaited(AppAnalytics.selectProvider(providerId: p.id, service: service, providerName: p.name('en')));
        context.push('/provider/${p.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Face(id: p.id, ini: p.initials.of(lang), photo: p.photo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(p.name(lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      const Icon(Icons.check, size: 13, color: Client.olive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.specialty.of(lang)} · ${area.isEmpty ? '' : '${areaName(area, lang)} · '}${p.years} ${lang == 'ar' ? 'سنين' : 'yrs'}',
                    style: const TextStyle(fontSize: 12, color: Client.muted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('${p.rating} ★ (${p.reviewCount})', style: const TextStyle(fontFamily: T.mono, fontSize: 11)),
                      Container(width: 2, height: 12, color: Client.line, margin: const EdgeInsets.symmetric(horizontal: 8)),
                      Text('$fromLabel ${money(p.priceFrom, lang)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      AppAnalytics.markBookingEntry('search');
                      unawaited(AppAnalytics.selectProvider(providerId: p.id, service: service, providerName: p.name('en')));
                      unawaited(AppAnalytics.beginCheckout(
                        providerId: p.id,
                        entryPoint: 'search',
                        providerName: p.name('en'),
                        serviceName: service,
                      ));
                      context.push('/book/${p.id}');
                    },
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Client.plum, border: Border.all(color: Client.ink, width: Client.rule)),
                      child: Text(bookLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.bg)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseSkel extends StatelessWidget {
  const _BrowseSkel();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: List.generate(
        4,
        (i) => Container(
          height: 84,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: Client.line.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final pcopy = t['prov'] as Map;
    final bar = t['ctaBar'] as Map;
    return FutureBuilder<ProviderP>(
      future: ref.read(repoProvider).provider(id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
        }
        final p = snap.data!;
        return Scaffold(
          backgroundColor: Client.bg,
          body: SafeArea(
            child: Column(
              children: [
                ClientBackHeader(title: lang == 'ar' ? 'المتخصصة' : 'Professional', onBack: () => context.pop()),
                Expanded(
                  child: ListView(
                    children: [
                      ClientProviderHero(
                        name: p.name(lang),
                        subtitle: '${p.specialty.of(lang)} · ${areaName(p.areas.first, lang)} · ${p.years} ${lang == 'ar' ? 'سنين' : 'yrs'}',
                        rating: p.rating,
                        reviewCount: p.reviewCount,
                        ini: p.initials.of(lang),
                        photo: p.photo,
                        onReviews: () => context.push('/reviews/${p.id}'),
                      ),
                      ClientTrustBanner(
                        text: '${pcopy['vetTitle']}',
                        link: lang == 'ar' ? 'تفاصيل ›' : 'Details ›',
                        onTap: () => showClientVerifiedSheet(
                          context,
                          title: '${pcopy['vetTitle']}',
                          body: '${pcopy['vetNote']}',
                          lang: lang,
                        ),
                      ),
                      const ClientDivider(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClientKicker('${pcopy['vetTitle']}', color: Client.plum),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 3.2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              children: [
                                _badge(lang == 'ar' ? 'البطاقة متأكدين منها' : 'ID verified'),
                                _badge(lang == 'ar' ? 'السجل اتراجع' : 'Background check'),
                                _badge(lang == 'ar' ? 'مقابلة وش لوش' : 'In-person interview'),
                                _badge(lang == 'ar' ? 'من غير وسيط' : 'No subcontracting'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('${pcopy['vetNote']}', style: const TextStyle(fontSize: 11, color: Client.muted, height: 1.45)),
                          ],
                        ),
                      ),
                      const ClientDivider(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClientKicker('${pcopy['portfolio']}'),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              children: List.generate(6, (i) {
                                final shots = Face.shotsOf(service: p.service, portfolio: p.portfolio);
                                return InkWell(
                                  onTap: () => openGallery(context, shots, index: i % shots.length),
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                                    clipBehavior: Clip.hardEdge,
                                    child: MediaThumb(shots[i % shots.length]),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            ClientKicker('${pcopy['portfolioNote']}'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClientKicker('${pcopy['reviews']}'),
                            const SizedBox(height: 12),
                            FutureBuilder<List<Review>>(
                              future: ref.read(repoProvider).reviews(providerId: p.id),
                              builder: (context, rsnap) {
                                final rows = (rsnap.data ?? const <Review>[]).take(2).toList();
                                if (rows.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      lang == 'ar' ? 'لسه مفيش تقييمات.' : 'No reviews yet.',
                                      style: const TextStyle(fontSize: 13, color: Client.muted),
                                    ),
                                  );
                                }
                                return Column(
                                  children: rows
                                      .map(
                                        (r) => ReviewCard(
                                          review: r,
                                          lang: lang,
                                          onTap: () => context.push('/reviews/${p.id}'),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                            ClientGhostButton(
                              label: '${pcopy['seeAll']}',
                              onTap: () => context.push('/reviews/${p.id}'),
                            ),
                            const SizedBox(height: 24),
                            ClientKicker('${pcopy['services']}'),
                            ...p.items.map((it) => Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(it.name.of(lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                                      Text(money(it.price, lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 96),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ClientStickyBar(
                  label: '${bar['from']}',
                  price: money(p.priceFrom, lang),
                  cta: '${bar['choose']}',
                  note: '${bar['chooseNote']}',
                  onTap: () {
                    AppAnalytics.markBookingEntry('profile');
                    unawaited(AppAnalytics.beginCheckout(
                      providerId: p.id,
                      entryPoint: 'profile',
                      providerName: p.name('en'),
                      serviceName: p.service,
                    ));
                    context.push('/book/${p.id}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
      child: Row(
        children: [
          const Text('✓', style: TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.olive)),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
