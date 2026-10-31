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

  /// "Drawn" when ops pasted a boundary, else the circle the area matches with.
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
    final boundary = TextEditingController(text: a?['boundary'] is Map ? jsonEncode(a!['boundary']) : '');
    final fee = TextEditingController(
        text: a == null ? '0' : '${asInt(a['travelFee'] ?? a['travelFeeAmount']) / 100}');
    final cities = {for (final r in areas) '${r['cityId']}': r['cityName']};
    try {
      final ok = await v2Form(
        context,
        title: isNew ? (lang == 'ar' ? 'منطقة جديدة' : 'New area') : (lang == 'ar' ? 'تعديل المنطقة' : 'Edit area'),
        bodyBuilder: (ctx, _) => Column(
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
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'المركز: خط العرض، خط الطول (من خرائط جوجل)' : 'Centre: lat, lng (copy from Google Maps)',
                child: TextField(controller: pin)),
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'نصف القطر بالمتر (لو مفيش حدود مرسومة)' : 'Radius in metres (used until a boundary is drawn)',
                child: TextField(controller: radius, keyboardType: TextInputType.number)),
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'الحدود GeoJSON Polygon (اختياري — امسحيها للرجوع للدائرة)' : 'Boundary — GeoJSON Polygon (optional; clear it to go back to the circle)',
                child: TextField(controller: boundary, minLines: 2, maxLines: 6, style: const TextStyle(fontFamily: Ops.mono, fontSize: 12))),
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
          } else if (boundary.text.trim().isNotEmpty) {
            try {
              final g = jsonDecode(boundary.text.trim());
              if (g is! Map || g['type'] != 'Polygon') throw const FormatException();
            } catch (_) {
              err = lang == 'ar' ? 'الحدود لازم تبقى GeoJSON Polygon' : 'Boundary must be a GeoJSON Polygon';
            }
          }
          if (err != null) v2Toast(context, err, error: true);
          return err == null;
        },
      );
      if (!ok) return;
      final c = _parseCenter(pin.text)!;
      final shape = boundary.text.trim();
      final hadBoundary = a?['hasBoundary'] == true;
      final cityId = city.text.trim();
      final payload = <String, dynamic>{
        'name': {'en': en.text.trim(), 'ar': ar.text.trim()},
        'center': {'lat': c.$1, 'lng': c.$2},
        'radiusM': int.parse(radius.text.trim()),
        if (shape.isNotEmpty) 'boundary': jsonDecode(shape) else if (hadBoundary) 'boundary': null,
        'travelFee': ((double.tryParse(fee.text.trim()) ?? 0) * 100).round(),
        if (isNew) ...{
          'slug': slug.text.trim().toLowerCase(),
          'cityId': cityId,
          'cityName': cities[cityId] ?? {'en': cityId, 'ar': cityId},
        },
      };
      try {
        if (isNew) {
          await staffClient.post('/admin/areas', data: payload);
        } else {
          await staffClient.patch('/admin/areas/${idOf(a)}', data: payload);
        }
        if (mounted) {
          v2Toast(context, isNew ? (lang == 'ar' ? 'تم الإنشاء' : 'Area created') : (lang == 'ar' ? 'تم التحديث' : 'Area updated'));
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

  Future<void> _toggleLock(Map a) async {
    final lang = ref.read(localeCodeProvider);
    // Restoring an archived area brings it back locked, never straight to live.
    final willLock = !_locked(a);
    try {
      await staffClient.patch('/admin/areas/${idOf(a)}', data: {'status': willLock ? 'locked_teaser' : 'active'});
      _load();
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
          const SizedBox(height: 12),
          row([
            Text(ar ? 'المنطقة' : 'Area', style: head),
            Text(ar ? 'تجميل' : 'Beauty', style: head),
            Text(ar ? 'تنظيف' : 'Cleaning', style: head),
            Text(ar ? 'زيارات جاية' : 'Upcoming', style: head),
            Text(ar ? 'مستنيين' : 'Waiting', style: head),
            Text(ar ? 'برّه' : 'Outside', style: head),
          ]),
          for (final r in rows)
            row([
              Text('${locName(r['name'], lang)} · ${_status({'status': r['status']})}', style: const TextStyle(fontSize: 12.5)),
              Text('${asMap(r['providers'])?['beauty'] ?? 0}', style: cell),
              Text('${asMap(r['providers'])?['cleaning'] ?? 0}', style: cell),
              Text('${r['upcoming'] ?? 0}', style: cell),
              Text('${r['waiting'] ?? 0}', style: cell),
              Text('${r['outsideNearby'] ?? 0}', style: cell),
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
