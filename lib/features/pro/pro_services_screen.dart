import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/features/pro/pro_service_editor_sheet.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';
import 'package:uuid/uuid.dart';

class ProServicesScreen extends ConsumerStatefulWidget {
  const ProServicesScreen({super.key});

  @override
  ConsumerState<ProServicesScreen> createState() => _ProServicesScreenState();
}

class _ProServicesScreenState extends ConsumerState<ProServicesScreen> {
  final drafts = <ProServiceDraft>[];
  final slugCtrl = TextEditingController();
  final domainCtrl = TextEditingController();
  String? lastDnsHint;
  String? lastDnsTxt;
  final areas = <String>{};
  List<int> days = [];
  final slotLocal = <String>{};
  final expandedCities = <String>{'new_cairo'};
  List<Map<String, dynamic>> allProCategories = [];
  List<Map<String, dynamic>> approvedCategories = [];
  List<Map<String, dynamic>> pendingCategories = [];
  Map<String, dynamic> catalog = {};
  double commissionRate = 0.10;
  bool catsLoaded = false;
  bool primed = false;
  String? primedId;
  bool busy = false;
  int tab = 0; // 0 services, 1 areas, 2 hours
  String filter = 'all'; // all | live | paused | pending
  List<int>? _bulkUndoPrices;
  String? _confirmDeleteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
      _loadCategories();
      unawaited(refreshServiceCities(activeOnly: true, force: true).then((_) {
        if (mounted) setState(() {});
      }));
    });
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(repoProvider);
      final rows = await repo.proCategories();
      Map<String, dynamic> cat = {};
      try {
        cat = await repo.proCatalog();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        allProCategories = rows;
        approvedCategories = rows.where((r) => r['status'] == 'active').toList();
        pendingCategories = rows.where((r) {
          final s = '${r['status']}';
          return s == 'pending_addition_approval' || s == 'pending_initial_vetting';
        }).toList();
        catalog = cat;
        commissionRate = (cat['commissionRate'] as num?)?.toDouble() ?? 0.10;
        catsLoaded = true;
        primed = false;
      });
      _prime(ref.read(sessionProvider).provider);
    } catch (_) {
      if (mounted) setState(() => catsLoaded = true);
    }
  }

  Future<void> _requestCategorySheet() async {
    final lang = langOf(ref);
    final repo = ref.read(repoProvider);
    final me = ref.read(sessionProvider).provider;
    if (me == null) return;
    List<Map<String, dynamic>> allCats = [];
    try {
      allCats = await repo.categories(vertical: me.service, activeOnly: true);
    } catch (_) {}
    final mine = allProCategories.map((c) => '${c['categoryId']}').toSet();
    final available = allCats.where((c) {
      final id = '${c['id'] ?? c['_id'] ?? ''}';
      return id.isNotEmpty && !mine.contains(id);
    }).toList();
    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ar' ? 'مفيش تخصصات جديدة متاحة للطلب.' : 'No new categories available to request.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RequestCategorySheet(
        available: available,
        lang: lang,
        onRequest: (catId) async {
          Navigator.pop(ctx);
          try {
            await repo.proAddCategory(catId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang == 'ar' ? 'تم إرسال الطلب للمراجعة ✓' : 'Request sent for review ✓')),
            );
            await _loadCategories();
          } on ApiException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
  }

  String? _matchCategoryId(ServiceItem it) {
    if (it.categoryId != null && it.categoryId!.isNotEmpty) return it.categoryId;
    final label = it.name.ar.isNotEmpty ? it.name.ar : it.name.en;
    for (final c in approvedCategories) {
      final n = c['name'];
      if (n is Map) {
        final loc = Loc.fromJson(n);
        if (loc.of('ar') == label || loc.of('en') == label) return '${c['categoryId']}';
      }
    }
    return approvedCategories.isNotEmpty ? '${approvedCategories.first['categoryId']}' : null;
  }

  String _categoryLabel(String? categoryId, String lang) {
    if (categoryId == null) return '';
    for (final c in allProCategories) {
      if ('${c['categoryId']}' == categoryId) {
        final n = c['name'];
        if (n is Map) return Loc.fromJson(n).of(lang);
        return '$n';
      }
    }
    return '';
  }

  bool _categoryPending(String? categoryId) {
    if (categoryId == null) return false;
    return pendingCategories.any((c) => '${c['categoryId']}' == categoryId);
  }

  @override
  void dispose() {
    slugCtrl.dispose();
    domainCtrl.dispose();
    for (final d in drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _prime(ProviderP? me) {
    if (me == null || !catsLoaded) return;
    if (primed && primedId == me.id) return;
    primed = true;
    primedId = me.id;
    for (final d in drafts) {
      d.dispose();
    }
    drafts
      ..clear()
      ..addAll(me.items.map((it) => ProServiceDraft(
            id: it.id,
            categoryId: _matchCategoryId(it),
            name: it.name,
            catalogItemId: it.catalogItemId,
            kind: it.kind,
            duration: it.duration > 0 ? it.duration : 60,
            priceEgp: (it.price / 100).round(),
            travelEgp: (it.travelFee / 100).round(),
            active: it.active,
            sizeFromSqm: it.sizeFromSqm > 0 ? it.sizeFromSqm : 120,
            sizeToSqm: it.sizeToSqm,
            workerCount: it.workerCount > 0 ? it.workerCount : 1,
            excludedTaskIds: it.excludedTaskIds.toSet(),
            approvalState: it.approvalState,
          )));
    areas
      ..clear()
      ..addAll(me.areas.where(allCatalogAreaIds().contains));
    if (areas.isEmpty) {
      areas.add('madinaty');
    }
    days = me.workDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : List.of(me.workDays);
    slotLocal
      ..clear()
      ..addAll(
        (me.slotHours.isEmpty ? defaultLocalSlotHours : me.slotHours.map(utcHourToLocal)).map((e) => e),
      );
    slugCtrl.text = me.slug ?? '';
  }

  Future<void> _openEditor({ProServiceDraft? existing}) async {
    final lang = langOf(ref);
    if (approvedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ar' ? 'مفيش تخصصات معتمدة لسه.' : 'No approved specialties yet.')),
      );
      return;
    }
    final result = await showProServiceEditorSheet(
      context: context,
      lang: lang,
      approvedCategories: approvedCategories,
      repo: ref.read(repoProvider),
      existing: existing,
      usedCategoryIds: const {},
      catalog: catalog,
      commissionRate: commissionRate,
    );
    if (result == null || !mounted) return;
    if (result.categoryId == '__delete__') {
      result.dispose();
      if (existing == null) return;
      setState(() {
        final i = drafts.indexWhere((d) => d.id == existing.id);
        if (i >= 0) {
          drafts[i].dispose();
          drafts.removeAt(i);
        }
      });
      return;
    }
    setState(() {
      if (existing == null) {
        drafts.add(result);
      } else {
        final i = drafts.indexWhere((d) => d.id == existing.id);
        if (i >= 0) {
          drafts[i].dispose();
          drafts[i] = result;
        } else {
          drafts.add(result);
        }
      }
    });
    if (existing == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        lang == 'ar'
            ? 'خدمتك هتتبعت لفريق أُنس للموافقة بعد ما تحفظي — مش هتظهر للعميلات لحد ما تتفعّل (٢٤–٤٨ ساعة).'
            : "Your new service goes to Oons for review once you save — it won't show to clients until it's activated (24–48h).",
      )));
    }
  }

  void _duplicate(ProServiceDraft d) {
    setState(() {
      drafts.add(d.copyAsNew('new-${const Uuid().v4().substring(0, 8)}'));
    });
  }

  void _toggleActive(ProServiceDraft d) {
    setState(() => d.active = !d.active);
  }

  Future<void> _bulkPrice(double factor) async {
    final lang = langOf(ref);
    final m = Copy.of(lang)['svcMgmt'] as Map;
    final preview = <MapEntry<ProServiceDraft, int>>[];
    for (final d in drafts) {
      final p = d.priceEgp;
      if (p <= 0) continue;
      final next = (((p * factor) / 5).round() * 5).clamp(5, 999999);
      preview.add(MapEntry(d, next));
    }
    if (preview.isEmpty) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${m['bulkConfirmTitle'] ?? (lang == 'ar' ? 'تأكيد تعديل الأسعار' : 'Confirm price change')}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...preview.take(8).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${e.key.name.of(lang)}: ${toArabicDigits(e.key.priceEgp)} → ${toArabicDigits(e.value)}',
                    style: const TextStyle(fontFamily: T.mono, fontSize: 13),
                  ),
                )),
            if (preview.length > 8) Text('… +${preview.length - 8}', style: const TextStyle(color: Pro.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ProSoftButton(label: '${m['deleteNo']}', onTap: () => Navigator.pop(ctx, false))),
                const SizedBox(width: 10),
                Expanded(child: ProPrimaryButton(label: '${m['bulkConfirm'] ?? (lang == 'ar' ? 'طبّقي' : 'Apply')}', onTap: () => Navigator.pop(ctx, true))),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final prev = drafts.map((d) => d.priceEgp).toList();
    setState(() {
      _bulkUndoPrices = prev;
      for (final e in preview) {
        e.key.priceCtrl.text = '${e.value}';
      }
    });
    AppAnalytics.logEvent('pro_service_bulk_price', {'factor': factor});
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('${m['bulkUndoHint'] ?? (lang == 'ar' ? 'اتطبّق. تقدري ترجعي في ١٠ ثواني' : 'Applied. Undo within 10s')}'),
        action: SnackBarAction(
          label: '${m['bulkUndo'] ?? (lang == 'ar' ? 'تراجع' : 'Undo')}',
          onPressed: () {
            final snap = _bulkUndoPrices;
            if (snap == null) return;
            setState(() {
              for (var i = 0; i < drafts.length && i < snap.length; i++) {
                drafts[i].priceCtrl.text = '${snap[i]}';
              }
              _bulkUndoPrices = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProServiceDraft d) async {
    setState(() => _confirmDeleteId = d.id);
  }

  void _deleteConfirmed(ProServiceDraft d) {
    setState(() {
      drafts.remove(d);
      d.dispose();
      _confirmDeleteId = null;
    });
  }

  Future<void> _save() async {
    final me = ref.read(sessionProvider).provider;
    final lang = langOf(ref);
    final m = Copy.of(lang)['svcMgmt'] as Map;
    if (me == null) return;
    if (areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ar' ? 'اختاري منطقة واحدة على الأقل.' : 'Pick at least one neighbourhood.')),
      );
      return;
    }
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ar' ? 'ضيفي خدمة واحدة على الأقل.' : 'Add at least one service.')),
      );
      return;
    }
    if (drafts.any((d) => d.categoryId == null || d.categoryId!.isEmpty || d.priceEgp <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${m['needNamePrice']}')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final items = drafts.map((d) => d.toApiItem()).toList();
      final body = <String, dynamic>{
        'areas': areas.toList(),
        'workDays': days,
        'slotHours': slotLocal.map(localHourToUtc).toList(),
        'items': items,
      };
      final slug = slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
      if (slug.isNotEmpty || me.vetted == true) body['slug'] = slug;
      final r = await ref.read(repoProvider).patchPro(body);
      if (r['provider'] is Map) {
        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
        primed = false;
        _prime(ref.read(sessionProvider).provider);
      }
      tapSuccess();
      if (mounted) {
        final p = Copy.of(lang)['pro'] as Map;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneSave']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<ProServiceDraft> get _filtered {
    switch (filter) {
      case 'live':
        return drafts.where((d) => d.active && !_categoryPending(d.categoryId)).toList();
      case 'paused':
        return drafts.where((d) => !d.active).toList();
      case 'pending':
        return drafts.where((d) => _categoryPending(d.categoryId)).toList();
      default:
        return drafts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final m = Copy.of(lang)['svcMgmt'] as Map;
    final p = Copy.of(lang)['pro'] as Map;
    final me = ref.watch(sessionProvider).provider;
    _prime(me);
    final tabLabels = lang == 'ar' ? const ['الخدمات', 'المناطق', 'المواعيد'] : const ['Services', 'Areas', 'Hours'];
    final linkLive = slugCtrl.text.trim().isNotEmpty;
    final liveN = drafts.where((d) => d.active).length;
    final pausedN = drafts.where((d) => !d.active).length;
    final priced = drafts.where((d) => d.priceEgp > 0).toList();
    final avg = priced.isEmpty ? 0 : (priced.fold<int>(0, (s, d) => s + d.priceEgp) / priced.length).round();

    return ColoredBox(
      color: Pro.bg,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m['title']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink)),
                            const SizedBox(height: 2),
                            Text('${m['categoryNote']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
                          ],
                        ),
                      ),
                      if (linkLive) ProPill('${m['linkLive']}', hot: false),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ProSegment(labels: tabLabels, index: tab, onChanged: (i) => setState(() => tab = i)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (tab == 0) ..._servicesTab(lang, m, p, me, liveN, pausedN, avg),
                if (tab == 1) ..._areasTab(lang, m),
                if (tab == 2) ..._hoursTab(lang, p, m),
                const SizedBox(height: 20),
                ProPrimaryButton(label: '${m['save']}', enabled: !busy && me != null, onTap: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _servicesTab(String lang, Map m, Map p, ProviderP? me, int liveN, int pausedN, int avg) {
    final filtered = _filtered;
    return [
      Row(
        children: [
          Expanded(child: _statCard('${m['live']}', '$liveN')),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${m['paused']}', '$pausedN')),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${m['avgPrice']}', avg > 0 ? '$avg' : '—')),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: ProSectionWithHelp('${m['servicesTitle']}', help: '${m['tipList']}')),
          ProSoftButton(label: '${m['addService']}', onTap: () => _openEditor()),
        ],
      ),
      const SizedBox(height: 10),
      ProSectionWithHelp('${m['bulkTitle']}', help: '${m['tipBulk']}'),
      const SizedBox(height: 6),
      Text('${m['bulkSub']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: ProSoftButton(label: '−١٠٪', onTap: () => _bulkPrice(0.9))),
          const SizedBox(width: 8),
          Expanded(child: ProSoftButton(label: '+١٠٪', onTap: () => _bulkPrice(1.1))),
        ],
      ),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in [
              ('all', m['filterAll']),
              ('live', m['filterLive']),
              ('paused', m['filterPaused']),
              ('pending', m['filterPending']),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ProChip(
                  label: '${e.$2}',
                  on: filter == e.$1,
                  onTap: () => setState(() => filter = e.$1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (filtered.isEmpty)
        ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${m['emptyFilter']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Pro.ink)),
              const SizedBox(height: 6),
              Text('${m['emptyFilterHint']}', style: const TextStyle(fontSize: 13, color: Pro.muted, height: 1.45)),
            ],
          ),
        )
      else
        ...filtered.map((d) => _serviceCard(lang, m, d)),
      const SizedBox(height: 14),
      _bookingLinkCard(lang, m, p, me),
      const SizedBox(height: 14),
      _domainsCard(lang, me),
      const SizedBox(height: 14),
      _categoriesCard(lang, m),
    ];
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Pro.cardDec(radius: Pro.rMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Pro.muted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink)),
        ],
      ),
    );
  }

  Widget _serviceCard(String lang, Map m, ProServiceDraft d) {
    // Either the whole category is awaiting staff approval, or — new — this
    // one service is (added or duplicated, not yet activated). Same "not
    // bookable yet" treatment either way.
    final pending = _categoryPending(d.categoryId) || d.isPendingApproval;
    final price = d.priceEgp;
    final travel = d.travelEgp;
    final net = price > 0 ? netAfterCommission(priceEgp: price, travelEgp: travel, commissionRate: commissionRate) : null;
    final name = d.name.of(lang);
    final cat = _categoryLabel(d.categoryId, lang);
    final ar = lang == 'ar';
    String status;
    if (pending) {
      status = '${m['pendingApproval']}';
    } else if (d.active) {
      status = '${m['visibleToClients']}';
    } else {
      status = '${m['pausedTemp']}';
    }
    d.syncSizeFromControls();
    final included = 18 - d.excludedTaskIds.length;
    final meta = d.isCleaning
        ? cleaningSizeMeta(fromSqm: d.sizeFromSqm, toSqm: d.sizeToSqm, workers: d.workerCount, ar: ar)
        : [
            if (d.duration > 0) '${toArabicDigits(d.duration)}${ar ? ' د' : ' min'}',
            if (price > 0) '${toArabicDigits(price)} ${ar ? 'ج.م' : 'EGP'}',
            if (net != null) '· ${m['net']} ${toArabicDigits(net)}',
          ].join(' · ');
    final hours = d.duration >= 60 ? (d.duration / 60) : d.duration;
    final durLabel = d.duration >= 60
        ? (ar ? '${toArabicDigits(hours % 1 == 0 ? hours.toInt() : hours)} س' : '${hours % 1 == 0 ? hours.toInt() : hours} h')
        : (ar ? '${toArabicDigits(d.duration)} د' : '${d.duration} min');
    final packageLine = d.isCleaning
        ? (ar ? 'الباقة شاملة ${pluralTasks(included, ar: true)} · $durLabel' : 'Package includes ${pluralTasks(included, ar: false)} · $durLabel')
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? cat : name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pro.ink)),
                      if (cat.isNotEmpty && name.isNotEmpty) Text(cat, style: const TextStyle(fontSize: 12, color: Pro.muted)),
                    ],
                  ),
                ),
                ProPill(status, soft: !d.active || pending, hot: d.active && !pending),
              ],
            ),
            const SizedBox(height: 8),
            Text(meta, style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Pro.soft)),
            if (packageLine != null) ...[
              const SizedBox(height: 4),
              Text(packageLine, style: const TextStyle(fontSize: 12, color: Pro.muted)),
            ],
            if (!d.isCleaning && price > 0 && net != null) ...[
              const SizedBox(height: 4),
              Text(
                '${toArabicDigits(price)} ${ar ? 'ج.م' : 'EGP'} · ${m['net']} ${toArabicDigits(net)}',
                style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Pro.soft),
              ),
            ],
            if (travel > 0) ...[
              const SizedBox(height: 4),
              Text('${m['travel']} ${toArabicDigits(travel)} ${ar ? 'ج.م' : 'EGP'}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            ],
            if (_confirmDeleteId == d.id) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8EEEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: Pro.dangerLine)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${m['deleteConfirm']}'.replaceAll('{name}', name.isEmpty ? '${m['service']}' : name),
                      style: const TextStyle(fontSize: 13, height: 1.45, color: Pro.ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: ProSoftButton(label: '${m['inlineDeleteKeep'] ?? m['deleteNo']}', onTap: () => setState(() => _confirmDeleteId = null))),
                        const SizedBox(width: 8),
                        Expanded(child: ProSoftButton(label: '${m['inlineDeleteYes'] ?? m['deleteYes']}', danger: true, onTap: () => _deleteConfirmed(d))),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _actionChip('${m['edit']}', () => _openEditor(existing: d)),
                  _actionChip(d.active ? '${m['pause']}' : '${m['resume']}', () => _toggleActive(d)),
                  _actionChip('${m['duplicate']}', () => _duplicate(d)),
                  _actionChip('${m['delete']}', () => _confirmDelete(d), danger: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFF8EEEE) : Pro.chip,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: danger ? Pro.dangerLine : Pro.lineSoft),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: danger ? Pro.danger : Pro.ink)),
      ),
    );
  }

  Widget _bookingLinkCard(String lang, Map m, Map p, ProviderP? me) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProSectionWithHelp('${m['bookingLink']}', help: '${m['tipLink']}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Pro.bg,
              borderRadius: BorderRadius.circular(Pro.rSm),
              border: Border.all(color: Pro.lineSoft),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: slugCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontFamily: T.mono, fontSize: 14, color: Pro.ink),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '${p['slugPlaceholder']}',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (slugCtrl.text.trim().isNotEmpty)
                  InkWell(
                    onTap: () {
                      final meNow = ref.read(sessionProvider).provider;
                      final slug = slugCtrl.text.trim();
                      final url = publicBookingUrl(slug, customDomain: meNow?.liveCustomDomain);
                      Clipboard.setData(ClipboardData(text: url));
                      unawaited(AppAnalytics.shareProviderLink(slug: slug));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['linkCopied']}')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Pro.plum, borderRadius: BorderRadius.circular(8)),
                      child: Text(lang == 'ar' ? 'كوبي' : 'Copy', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          if (slugCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              publicBookingUrl(slugCtrl.text.trim(), customDomain: me?.liveCustomDomain),
              style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Pro.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _domainsCard(String lang, ProviderP? me) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProSectionLabel(lang == 'ar' ? 'دومين خاص' : 'Custom domain'),
          const SizedBox(height: 6),
          Text(
            lang == 'ar'
                ? 'اربطي book.yoursite.com بعد ما تشيري DNS وتفعّلي الشهادة.'
                : 'Connect book.yoursite.com after DNS + TLS activate.',
            style: const TextStyle(fontSize: 12, color: Pro.muted),
          ),
          const SizedBox(height: 10),
          ...?me?.customDomains.map((d) {
            final status = d.status == 'verified'
                ? (d.tlsStatus == 'active'
                    ? (lang == 'ar' ? 'شغّال' : 'Live')
                    : (lang == 'ar' ? 'جاري تفعيل HTTPS' : 'TLS pending'))
                : (lang == 'ar' ? 'استني التحقق' : 'Pending verify');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Pro.bg,
                  borderRadius: BorderRadius.circular(Pro.rSm),
                  border: Border.all(color: Pro.lineSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(d.host, style: const TextStyle(fontFamily: T.mono, fontSize: 13, color: Pro.ink))),
                        ProPill(status, hot: d.tlsStatus == 'active'),
                      ],
                    ),
                    if (d.status == 'pending' && d.verifyToken.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('TXT: oons-domain-verification=${d.verifyToken}', style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Pro.muted)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (d.status != 'verified')
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    setState(() => busy = true);
                                    try {
                                      final r = await ref.read(repoProvider).verifyProDomain(d.host);
                                      if (r['provider'] is Map) {
                                        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                                      }
                                      tapSuccess();
                                      if (mounted) {
                                        final p = Copy.of(lang)['pro'] as Map;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneSave']}')));
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                                      }
                                    } finally {
                                      if (mounted) setState(() => busy = false);
                                    }
                                  },
                            child: Text(lang == 'ar' ? 'تحققي' : 'Verify'),
                          ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  try {
                                    final r = await ref.read(repoProvider).deleteProDomain(d.host);
                                    if (r['provider'] is Map) {
                                      ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                                    }
                                  } finally {
                                    if (mounted) setState(() => busy = false);
                                  }
                                },
                          child: Text(lang == 'ar' ? 'امسحي' : 'Remove', style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if ((me?.customDomains.length ?? 0) < 3) ...[
            TextField(
              controller: domainCtrl,
              style: const TextStyle(fontFamily: T.mono, fontSize: 14, color: Pro.ink),
              decoration: InputDecoration(
                hintText: 'book.yoursite.com',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Pro.rSm)),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final host = domainCtrl.text.trim().toLowerCase();
                        if (host.isEmpty) return;
                        setState(() => busy = true);
                        try {
                          final r = await ref.read(repoProvider).addProDomain(host);
                          domainCtrl.clear();
                          lastDnsHint = r['dnsHint']?.toString();
                          lastDnsTxt = r['txtRecord']?.toString();
                          if (r['provider'] is Map) {
                            ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                          }
                          tapSuccess();
                          if (mounted) {
                            final p = Copy.of(lang)['pro'] as Map;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneSaveLink']}')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(lang == 'ar' ? 'أضيفي الدومين' : 'Add domain'),
              ),
            ),
            if (lastDnsHint != null && lastDnsHint!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(lastDnsHint!, style: const TextStyle(fontSize: 11, color: Pro.muted)),
            ],
            if (lastDnsTxt != null && lastDnsTxt!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(lastDnsTxt!, style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Pro.muted)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _categoriesCard(String lang, Map m) {
    return ProCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProSectionWithHelp('${m['categories']}', help: '${m['tipCats']}'),
          if (pendingCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Pro.pendingBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Pro.pendingLine),
              ),
              child: Text('${m['pendingNote']}', style: const TextStyle(fontSize: 12, color: Pro.pendingInk, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          if (!catsLoaded)
            const LinearProgressIndicator(minHeight: 2, color: Pro.plum)
          else ...[
            ...approvedCategories.map((c) => _catRow(lang, c, pending: false)),
            ...pendingCategories.map((c) => _catRow(lang, c, pending: true)),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _requestCategorySheet,
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Pro.plum),
              label: Text('${m['requestCat']}', style: const TextStyle(fontSize: 13, color: Pro.plum, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catRow(String lang, Map c, {required bool pending}) {
    final n = c['name'];
    final label = n is Map ? Loc.fromJson(n).of(lang) : '$n';
    final id = '${c['id'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pending ? (lang == 'ar' ? '$label · قيد الموافقة' : '$label · pending') : label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: pending ? Pro.pendingInk : Pro.ink),
            ),
          ),
          if (!pending && id.isNotEmpty)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await ref.read(repoProvider).proRemoveCategory(id);
                        await _loadCategories();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(lang == 'ar' ? 'شيلي' : 'Remove', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            ),
        ],
      ),
    );
  }

  List<Widget> _areasTab(String lang, Map m) {
    return [
      ProSectionWithHelp('${m['coverageTitle']}', help: '${m['tipAreas']}'),
      const SizedBox(height: 6),
      Text('${m['coverageSub']}', style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.45)),
      const SizedBox(height: 10),
      ...serviceCities.map((city) {
        final open = expandedCities.contains(city.id);
        final picked = city.areas.where(areas.contains).length;
        final allOn = city.areas.every(areas.contains);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ProCard(
            padding: EdgeInsets.zero,
            color: picked == 0 ? const Color(0xFFFBF8F5) : Pro.card,
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    if (open) {
                      expandedCities.remove(city.id);
                    } else {
                      expandedCities.add(city.id);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            city.name.of(lang),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: picked == 0 ? FontWeight.w600 : FontWeight.w700,
                              color: picked == 0 ? Pro.soft : Pro.ink,
                            ),
                          ),
                        ),
                        Text(
                          '$picked/${city.areas.length}',
                          style: TextStyle(
                            fontFamily: T.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: picked == 0 ? const Color(0xFF9C8F96) : Pro.plum,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(open ? '▲' : '▼', style: const TextStyle(fontSize: 12, color: Pro.muted)),
                      ],
                    ),
                  ),
                ),
                if (open)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                allOn
                                    ? (lang == 'ar' ? 'كل المناطق مختارة' : 'All areas selected')
                                    : (lang == 'ar' ? 'اختاري المناطق' : 'Pick areas'),
                                style: const TextStyle(fontSize: 11, color: Pro.muted),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() {
                                if (allOn) {
                                  areas.removeAll(city.areas);
                                } else {
                                  areas.addAll(city.areas);
                                }
                              }),
                              child: Text(
                                allOn ? '${m['clearCity']}' : '${m['allCity']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pro.plum),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: city.areas.map((id) {
                            final on = areas.contains(id);
                            return ProChip(
                              label: areaName(id, lang),
                              on: on,
                              onTap: () => setState(() {
                                if (on && areas.length > 1) {
                                  areas.remove(id);
                                } else if (!on) {
                                  areas.add(id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  List<Widget> _hoursTab(String lang, Map p, Map m) {
    final labels = lang == 'ar' ? weekdayAr : weekdayEn;
    return [
      ProSectionWithHelp('${m['hoursTitle']}', help: '${m['tipHours']}'),
      const SizedBox(height: 6),
      Text('${m['hoursSub']}', style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.45)),
      const SizedBox(height: 10),
      ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProSectionLabel(lang == 'ar' ? 'أيام شغلي' : '${p['hours']}'),
                const Spacer(),
                Text('${days.length} ${lang == 'ar' ? 'أيام' : 'days'}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: List.generate(7, (i) {
                final day = i + 1;
                final on = days.contains(day);
                return ProChip(
                  label: labels[i],
                  on: on,
                  onTap: () => setState(() {
                    if (on && days.length > 1) {
                      days.remove(day);
                    } else if (!on) {
                      days.add(day);
                      days.sort();
                    }
                  }),
                );
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProSectionLabel(lang == 'ar' ? 'ساعات الحجز' : '${p['slotHours']}'),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => slotLocal
                    ..clear()
                    ..addAll(defaultLocalSlotHours)),
                  child: Text(
                    lang == 'ar' ? 'اختاري الكل' : 'Select all',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pro.plum),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 2.1,
              children: defaultLocalSlotHours.map((h) {
                final on = slotLocal.contains(h);
                return InkWell(
                  onTap: () => setState(() {
                    if (on && slotLocal.length > 1) {
                      slotLocal.remove(h);
                    } else if (!on) {
                      slotLocal.add(h);
                    }
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? Pro.plum : Pro.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontFamily: T.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : const Color(0xFF9C8F96),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ];
  }
}

class _RequestCategorySheet extends StatelessWidget {
  const _RequestCategorySheet({
    required this.available,
    required this.lang,
    required this.onRequest,
  });
  final List<Map<String, dynamic>> available;
  final String lang;
  final Future<void> Function(String categoryId) onRequest;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 36, height: 4, decoration: BoxDecoration(color: Pro.lineSoft, borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              lang == 'ar' ? 'اطلبي إضافة تخصص' : 'Request a new specialty',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pro.ink),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              lang == 'ar' ? 'اختاري التخصص اللي عايزاه وهنراجع الطلب.' : 'Pick the specialty you want — we\'ll review your request.',
              style: const TextStyle(fontSize: 13, color: Pro.muted, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: available.length,
              itemBuilder: (_, i) {
                final c = available[i];
                final id = '${c['id'] ?? c['_id'] ?? ''}';
                final n = c['name'];
                final label = n is Map ? Loc.fromJson(n).of(lang) : '${n ?? c['slug']}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onRequest(id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Pro.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Pro.line),
                      ),
                      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Pro.ink)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
