import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/admin_v2/features/areas/area_geometry.dart';
import 'package:oons/admin_v2/features/areas/area_map_editor.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';
import 'package:oons/admin_v2/ui/list_view.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class AreasScreen extends ConsumerStatefulWidget {
  const AreasScreen({super.key});

  @override
  ConsumerState<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends ConsumerState<AreasScreen> {
  List<Map<String, dynamic>> areas = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Active', 'Locked', 'Archived'];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(v2HeaderConfigProvider.notifier).state =
            V2HeaderConfig(newLabel: 'Area', onNewRecord: () => _edit(null));
      }
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/areas');
      setState(() {
        areas = asMapList(data['areas']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  /// Active (bookable), Locked (shown as coming soon) or Archived (retired).
  String _status(Map a) {
    final st = '${a['status']}';
    if (st == 'archived') return 'Archived';
    if (a['locked'] == true || st == 'locked_teaser' || st == 'locked') return 'Locked';
    return 'Active';
  }

  bool _locked(Map a) => _status(a) == 'Locked';
  int _count(String f) => f == 'All' ? areas.length : areas.where((a) => _status(a) == f).length;

  /// "Drawn" when the area has a boundary, else the circle it matches with.
  String _shape(Map a, String lang) {
    if (a['hasBoundary'] == true) return lang == 'ar' ? 'مرسومة' : 'Drawn';
    final km = asInt(a['radiusM']) / 1000;
    if (km <= 0) return lang == 'ar' ? 'بلا مكان' : 'No pin';
    return lang == 'ar' ? 'دائرة ${km.toStringAsFixed(1)} كم' : 'Circle ${km.toStringAsFixed(1)} km';
  }

  List<Map<String, dynamic>> get _rows {
    var list = areas;
    if (filter != 'All') list = list.where((a) => _status(a) == filter).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((a) => a.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  /// "30.0917, 31.6306" — the format Google Maps copies when you click a spot.
  static (double, double)? _parseCenter(String raw) {
    final parts = raw.split(',').map((p) => double.tryParse(p.trim())).toList();
    if (parts.length != 2 || parts.any((p) => p == null)) return null;
    final (lat, lng) = (parts[0]!, parts[1]!);
    if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
    return (lat, lng);
  }

  Future<void> _edit(Map? a) async {
    final lang = ref.read(localeCodeProvider);
    final isNew = a == null;
    final center = asMap(a?['center']);
    final en = TextEditingController(text: '${asMap(a?['name'])?['en'] ?? ''}');
    final ar = TextEditingController(text: '${asMap(a?['name'])?['ar'] ?? ''}');
    final slug = TextEditingController(text: '${a?['slug'] ?? ''}');
    final city = TextEditingController(text: '${a?['cityId'] ?? ''}');
    final pin = TextEditingController(text: center == null ? '' : '${center['lat']}, ${center['lng']}');
    final radius = TextEditingController(text: '${a == null ? 2500 : asInt(a['radiusM'])}');
    // The map is the editor; the GeoJSON box is the paste fallback.
    final loaded = ringFromGeoJson(a?['boundary']);
    final boundary = TextEditingController(text: a?['boundary'] is Map ? jsonEncode(a!['boundary']) : '');
    final startCenter = _parseCenter(pin.text) ?? (30.0444, 31.2357);
    var shape = AreaShape(
      center: LatLng(startCenter.$1, startCenter.$2),
      radiusM: int.tryParse(radius.text) ?? 2500,
      ring: loaded?.ring ?? const [],
    );
    var showPaste = false;
    void setShape(AreaShape next) {
      shape = next;
      pin.text = '${next.center.latitude.toStringAsFixed(6)}, ${next.center.longitude.toStringAsFixed(6)}';
      final g = ringToGeoJson(next.ring);
      boundary.text = g == null ? '' : jsonEncode(g);
    }
    final fee = TextEditingController(
        text: a == null ? '0' : '${asInt(a['travelFee'] ?? a['travelFeeAmount']) / 100}');
    final cities = {for (final r in areas) '${r['cityId']}': r['cityName']};
    try {
      final ok = await v2Form(
        context,
        title: isNew ? (lang == 'ar' ? 'منطقة جديدة' : 'New area') : (lang == 'ar' ? 'تعديل المنطقة' : 'Edit area'),
        bodyBuilder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: 'Name (EN)', child: TextField(controller: en)),
            const SizedBox(height: 12),
            V2FormField(label: 'الاسم (AR)', child: TextField(controller: ar)),
            if (isNew) ...[
              const SizedBox(height: 12),
              V2FormField(
                  label: lang == 'ar' ? 'المعرّف (بالإنجليزي، مثل shorouk)' : 'Slug (e.g. shorouk)',
                  child: TextField(controller: slug)),
              const SizedBox(height: 12),
              V2FormField(
                  label: lang == 'ar'
                      ? 'معرّف المدينة (${cities.keys.join(' · ')})'
                      : 'City id (${cities.keys.join(' · ')})',
                  child: TextField(controller: city)),
            ],
            const SizedBox(height: 16),
            AreaMapEditor(
              shape: shape,
              ar: lang == 'ar',
              onChanged: (next) => setLocal(() => setShape(next)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: V2FormField(
                    label: lang == 'ar' ? 'المركز: خط العرض، خط الطول' : 'Centre: lat, lng',
                    child: TextField(
                      controller: pin,
                      onSubmitted: (v) {
                        final c = _parseCenter(v);
                        if (c != null) setLocal(() => setShape(AreaShape(center: LatLng(c.$1, c.$2), radiusM: shape.radiusM, ring: shape.ring)));
                      },
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: V2FormField(
                    label: lang == 'ar' ? 'نصف القطر بالمتر (لو مفيش حدود)' : 'Radius, metres (used with no boundary)',
                    child: TextField(
                      controller: radius,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final r = int.tryParse(v.trim());
                        if (r != null && r >= 200) setLocal(() => shape = AreaShape(center: shape.center, radiusM: r, ring: shape.ring));
                      },
                    )),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: V2Btn.ghost(
                showPaste
                    ? (lang == 'ar' ? 'اخفي GeoJSON' : 'Hide GeoJSON')
                    : (lang == 'ar' ? 'الصقي GeoJSON بدل الرسم' : 'Paste GeoJSON instead'),
                onPressed: () => setLocal(() => showPaste = !showPaste),
                size: V2BtnSize.sm,
              ),
            ),
            if (showPaste) ...[
              const SizedBox(height: 8),
              V2FormField(
                  label: lang == 'ar' ? 'الحدود — GeoJSON Polygon' : 'Boundary — GeoJSON Polygon',
                  child: TextField(controller: boundary, minLines: 2, maxLines: 6, style: const TextStyle(fontFamily: Ops.mono, fontSize: 12))),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2Btn.ghost(lang == 'ar' ? 'حمّليها على الخريطة' : 'Load onto map', size: V2BtnSize.sm, onPressed: () {
                  final raw = boundary.text.trim();
                  if (raw.isEmpty) return setLocal(() => setShape(AreaShape(center: shape.center, radiusM: shape.radiusM)));
                  Object? g;
                  try {
                    g = jsonDecode(raw);
                  } catch (_) {}
                  final parsed = ringFromGeoJson(g);
                  if (parsed == null) {
                    v2Toast(context, lang == 'ar' ? 'ده مش GeoJSON Polygon صالح' : 'That isn\'t a valid GeoJSON Polygon', error: true);
                    return;
                  }
                  if (parsed.holes) {
                    v2Toast(context, lang == 'ar' ? 'الفتحات الداخلية اتشالت — المحرر بيحفظ الحدود الخارجية بس' : 'Inner holes were dropped — the editor keeps the outer ring only');
                  }
                  setLocal(() => setShape(AreaShape(center: shape.center, radiusM: shape.radiusM, ring: parsed.ring)));
                }),
              ),
            ],
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'رسوم الانتقال (ج.م)' : 'Travel fee (EGP)',
                child: TextField(controller: fee, keyboardType: TextInputType.number)),
          ],
        ),
        onValidate: () {
          String? err;
          if (en.text.trim().isEmpty) {
            err = lang == 'ar' ? 'الاسم مطلوب' : 'Name is required';
          } else if (isNew && (slug.text.trim().isEmpty || city.text.trim().isEmpty)) {
            err = lang == 'ar' ? 'المعرّف والمدينة مطلوبين' : 'Slug and city id are required';
          } else if (_parseCenter(pin.text) == null) {
            err = lang == 'ar' ? 'المركز لازم يبقى «خط عرض، خط طول»' : 'Centre must be "lat, lng"';
          } else if ((int.tryParse(radius.text.trim()) ?? 0) < 200) {
            err = lang == 'ar' ? 'نصف القطر ٢٠٠ متر على الأقل' : 'Radius must be at least 200 m';
          } else if (shape.ring.isNotEmpty) {
            err = ringProblem(shape.ring, ar: lang == 'ar');
          }
          if (err != null) v2Toast(context, err, error: true);
          return err == null;
        },
      );
      if (!ok) return;
      final c = _parseCenter(pin.text)!;
      final drawn = ringToGeoJson(shape.ring);
      final hadBoundary = a?['hasBoundary'] == true;
      final cityId = city.text.trim();
      final payload = <String, dynamic>{
        'name': {'en': en.text.trim(), 'ar': ar.text.trim()},
        'center': {'lat': c.$1, 'lng': c.$2},
        'radiusM': int.parse(radius.text.trim()),
        if (drawn != null) 'boundary': drawn else if (hadBoundary) 'boundary': null,
        'travelFee': ((double.tryParse(fee.text.trim()) ?? 0) * 100).round(),
        if (isNew) ...{
          'slug': slug.text.trim().toLowerCase(),
          'cityId': cityId,
          'cityName': cities[cityId] ?? {'en': cityId, 'ar': cityId},
        },
      };
      try {
        var notified = 0;
        if (isNew) {
          await staffClient.post('/admin/areas', data: payload);
        } else {
          final r = await staffClient.patch('/admin/areas/${idOf(a)}', data: payload);
          notified = asInt(r['notified']);
        }
        if (mounted) {
          v2Toast(context, isNew ? (lang == 'ar' ? 'تم الإنشاء' : 'Area created') : (lang == 'ar' ? 'تم التحديث' : 'Area updated'));
          if (notified > 0) _toldToast(notified);
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      for (final t in [en, ar, slug, city, pin, radius, boundary, fee]) {
        t.dispose();
      }
    }
  }

  /// After an area goes live: how many waiting customers were told.
  void _toldToast(int n) {
    final lang = ref.read(localeCodeProvider);
    v2Toast(context, lang == 'ar' ? 'بلّغنا $n عميلة إن منطقتها اتفتحت' : 'Told $n customers their area is open');
  }

  Future<void> _toggleLock(Map a) async {
    final lang = ref.read(localeCodeProvider);
    // Restoring an archived area brings it back locked, never straight to live.
    final willLock = !_locked(a);
    try {
      final r = await staffClient.patch('/admin/areas/${idOf(a)}', data: {'status': willLock ? 'locked_teaser' : 'active'});
      _load();
      if (mounted && asInt(r['notified']) > 0) _toldToast(asInt(r['notified']));
      if (mounted) {
        v2Toast(context, willLock
            ? (lang == 'ar' ? 'اتقفلت المنطقة' : 'Area locked')
            : (lang == 'ar' ? 'اتفتحت المنطقة' : 'Area unlocked'));
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _archive(Map a) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context,
        title: lang == 'ar' ? 'أرشفة المنطقة؟' : 'Archive area?',
        body: '"${locName(a['name'], lang)}" ${lang == 'ar' ? 'هتختفي من الحجز والاختيار. العناوين والمتخصصات المرتبطة بيها بتفضل محفوظة، وتقدري ترجّعيها.' : 'stops matching addresses and disappears from pickers. Saved addresses and providers keep it, and you can restore it.'}',
        confirmLabel: lang == 'ar' ? 'أرشفة' : 'Archive',
        danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/areas/${idOf(a)}');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'اتأرشفت' : 'Area archived');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  /// Where we're thin: bookable providers per service, upcoming visits, and
  /// customers who pinned a place we don't serve yet.
  Future<void> _coverage() async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(await staffClient.get('/admin/areas/coverage') as Map);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    final rows = asMapList(data['areas'])
      ..sort((a, b) => (b['gap'] == true ? 1 : 0).compareTo(a['gap'] == true ? 1 : 0));
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Ops.inkSoft);
    const cell = TextStyle(fontSize: 12.5, fontFamily: Ops.mono);
    Widget row(List<Widget> cells, {bool gap = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          color: gap ? Ops.plum.withValues(alpha: 0.07) : null,
          child: Row(children: [
            Expanded(flex: 3, child: cells[0]),
            for (final c in cells.skip(1)) Expanded(flex: 2, child: c),
          ]),
        );
    await v2Form(
      context,
      title: ar ? 'التغطية' : 'Coverage gaps',
      confirmLabel: ar ? 'تمام' : 'Done',
      bodyBuilder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              ar
                  ? 'الصفوف المظلّلة: منطقة شغّالة ناقصها خدمة، أو منطقة مقفولة فيها طلب. «برّه» = عملاء برّه كل المناطق والمنطقة دي الأقرب ليهم (الإجمالي ${data['outsideTotal'] ?? 0}).'
                  : 'Shaded rows: a live area missing a service, or a locked one people are asking for. "Outside" = customers outside every area who are nearest this one (${data['outsideTotal'] ?? 0} in total).',
              style: const TextStyle(fontSize: 12, color: Ops.inkSoft, height: 1.4)),
          if (asInt(data['providersWithNoAreas']) > 0) ...[
            const SizedBox(height: 10),
            Text(
                ar
                    ? '${asInt(data['providersWithNoAreas'])} متخصصة متوثّقة مالهاش مناطق — مش بتظهر لأي عميلة. حدّدي مناطقها من صفحتها.'
                    : '${asInt(data['providersWithNoAreas'])} vetted providers have no areas, so no customer can find them. Set their areas on their profile.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Ops.plum, height: 1.4)),
          ],
          const SizedBox(height: 12),
          row([
            Text(ar ? 'المنطقة' : 'Area', style: head),
            Text(ar ? 'تجميل' : 'Beauty', style: head),
            Text(ar ? 'تنظيف' : 'Cleaning', style: head),
            Text(ar ? 'زيارات جاية' : 'Upcoming', style: head),
            Text(ar ? 'مستنيين' : 'Waiting', style: head),
            Text(ar ? 'برّه' : 'Outside', style: head),
            Text(ar ? 'رسوم الانتقال' : 'Travel fee', style: head),
          ]),
          for (final r in rows)
            row([
              Text('${locName(r['name'], lang)} · ${_status({'status': r['status']})}', style: const TextStyle(fontSize: 12.5)),
              Text('${asMap(r['providers'])?['beauty'] ?? 0}', style: cell),
              Text('${asMap(r['providers'])?['cleaning'] ?? 0}', style: cell),
              Text('${r['upcoming'] ?? 0}', style: cell),
              Text('${r['waiting'] ?? 0}', style: cell),
              Text('${r['outsideNearby'] ?? 0}', style: cell),
              // No fee set: shown as "—" so ops can fill it in; never guessed.
              Text(r['noTravelFee'] == true ? '—' : money(asInt(r['travelFee']), lang),
                  style: cell.copyWith(color: r['noTravelFee'] == true ? Ops.plum : null)),
            ], gap: r['gap'] == true),
        ],
      ),
    );
  }

  /// Saved addresses whose pin sits in a different area than the one stored
  /// (most were silently set to the Capital). Read first, then fix on confirm.
  Future<void> _addressCheck() async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(await staffClient.get('/admin/areas/address-audit') as Map);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    final counts = asMap(data['counts']) ?? const {};
    final moves = asMap(data['moves']) ?? const {};
    final mismatch = asInt(counts['mismatch']);
    final lines = [
      for (final e in moves.entries.toList()..sort((a, b) => asInt(b.value).compareTo(asInt(a.value))))
        '${e.key.replaceAll('→', ' → ').replaceFirst(RegExp(r' → $'), ' → ${ar ? 'برّه' : 'outside'}')}: ${e.value}',
    ];
    final ok = await v2Form(
      context,
      title: ar ? 'مراجعة العناوين' : 'Check saved addresses',
      confirmLabel: mismatch == 0 ? (ar ? 'تمام' : 'Done') : (ar ? 'صحّحي $mismatch عنوان' : 'Fix $mismatch addresses'),
      bodyBuilder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              ar
                  ? 'مطابقة: ${asInt(counts['match'])} · منطقة غلط: $mismatch · برّه كل المناطق: ${asInt(counts['outside'])} · من غير دبوس حقيقي: ${asInt(counts['no_pin'])}'
                  : 'Match: ${asInt(counts['match'])} · Wrong area: $mismatch · Outside every area: ${asInt(counts['outside'])} · No real pin: ${asInt(counts['no_pin'])}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(
              ar
                  ? 'التصحيح بيغيّر بس العناوين اللي دبوسها جوّه منطقة تانية معروفة. اللي برّه أو من غير دبوس بيفضل زي ما هو.'
                  : 'Fixing only changes addresses whose pin is inside a different known area. Outside and unpinned addresses are left alone.',
              style: const TextStyle(fontSize: 12, color: Ops.inkSoft, height: 1.4)),
          const SizedBox(height: 10),
          for (final l in lines.take(20)) Text(l, style: const TextStyle(fontSize: 12, fontFamily: Ops.mono)),
        ],
      ),
    );
    if (!ok || mismatch == 0 || !mounted) return;
    try {
      final r = await staffClient.post('/admin/areas/address-audit/apply', data: {'confirm': true});
      if (mounted) v2Toast(context, ar ? 'اتصحّح ${asInt((r as Map)['updated'])} عنوان' : 'Fixed ${asInt((r as Map)['updated'])} addresses');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  /// Saved addresses we can't serve yet that have no coverage request (saved
  /// before requests existed). Preview counts, then write on confirm.
  Future<void> _backfillRequests() async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    Map<String, dynamic> counts;
    try {
      final r = await staffClient.get('/admin/areas/coverage-requests/backfill');
      counts = asMap(r['counts']) ?? const {};
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
      return;
    }
    if (!mounted) return;
    final changes = asInt(counts['insert']) + asInt(counts['update']) + asInt(counts['delete']);
    String line(Map c) => ar
        ? 'جديد: ${asInt(c['insert'])} · متحدّث: ${asInt(c['update'])} · اتشال (بقى متغطّي): ${asInt(c['delete'])} · من غير تغيير: ${asInt(c['unchanged'])} · من غير دبوس ولا منطقة: ${asInt(c['skipped'])}'
        : 'New: ${asInt(c['insert'])} · Updated: ${asInt(c['update'])} · Removed (now covered): ${asInt(c['delete'])} · Unchanged: ${asInt(c['unchanged'])} · No pin or area: ${asInt(c['skipped'])}';
    final ok = await v2Form(
      context,
      title: ar ? 'طلبات التغطية القديمة' : 'Backfill coverage requests',
      confirmLabel: changes == 0 ? (ar ? 'تمام' : 'Done') : (ar ? 'اكتبي $changes تغيير' : 'Write $changes changes'),
      bodyBuilder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            ar
                ? 'بيراجع كل العناوين المحفوظة (${asInt(counts['checked'])}) وبيسجّل طلب لكل عنوان برّه أو في منطقة لسه مقفولة، عشان تظهر في «التغطية» وتتبلّغ لما المنطقة تفتح. مش بيغيّر العناوين نفسها.'
                : 'Checks every saved address (${asInt(counts['checked'])}) and records a request for each one outside our areas or in a locked area, so it shows in Coverage gaps and is told when the area opens. It does not change the addresses themselves.',
            style: const TextStyle(fontSize: 12, color: Ops.inkSoft, height: 1.4)),
        const SizedBox(height: 10),
        Text(line(counts), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
    if (!ok || changes == 0 || !mounted) return;
    try {
      final r = await staffClient.post('/admin/areas/coverage-requests/backfill', data: {'confirm': true});
      if (mounted) v2Toast(context, line(asMap(r['counts']) ?? const {}));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'areas.write')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا مناطق' : 'Nothing here yet',
      actionsWidth: 170,
      trailingActions: [
        V2Btn.ghost(lang == 'ar' ? 'التغطية' : 'Coverage gaps', onPressed: _coverage, size: V2BtnSize.sm),
        V2Btn.ghost(lang == 'ar' ? 'مراجعة العناوين' : 'Check addresses', onPressed: _addressCheck, size: V2BtnSize.sm),
        V2Btn.ghost(lang == 'ar' ? 'طلبات التغطية' : 'Backfill requests', onPressed: _backfillRequests, size: V2BtnSize.sm),
        V2Btn.primary(lang == 'ar' ? '+ منطقة' : '+ New Area', onPressed: () => _edit(null), size: V2BtnSize.sm),
      ],
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المنطقة' : 'Area', flex: 1),
        V2Col(lang == 'ar' ? 'المدينة' : 'City', flex: 1),
        V2Col(lang == 'ar' ? 'المكان' : 'Shape', fixed: 120),
        V2Col(lang == 'ar' ? 'رسوم الانتقال' : 'Travel fee', fixed: 110),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 110),
      ],
      rows: [
        for (final a in _rows)
          V2GridRow(
            cells: [
              Text(locName(a['name'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(locName(a['cityName'], lang).isNotEmpty ? locName(a['cityName'], lang) : '${a['cityId'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(_shape(a, lang), style: const TextStyle(fontSize: 12, fontFamily: Ops.mono, color: Ops.inkSoft)),
              GestureDetector(
                onTap: () => _edit(a),
                child: Text(money(asInt(a['travelFee'] ?? a['travelFeeAmount']), lang),
                    style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, color: Ops.plum)),
              ),
              Align(alignment: AlignmentDirectional.centerStart, child: V2StatusPill.forLabel(_status(a))),
            ],
            actions: [
              if (_status(a) == 'Archived')
                V2Btn(label: lang == 'ar' ? 'استرجاع' : 'Restore', onPressed: () => _toggleLock(a), size: V2BtnSize.row)
              else
                V2Btn(label: _locked(a) ? (lang == 'ar' ? 'فتح' : 'Unlock') : (lang == 'ar' ? 'قفل' : 'Lock'),
                    onPressed: () => _toggleLock(a), size: V2BtnSize.row),
              V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _edit(a), size: V2BtnSize.row),
              if (_status(a) != 'Archived')
                V2Btn.danger(lang == 'ar' ? 'أرشفة' : 'Archive', onPressed: () => _archive(a), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
