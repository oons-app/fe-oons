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

  static const _filters = ['All', 'Active', 'Locked'];

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

  bool _locked(Map a) => a['locked'] == true || '${a['status']}' == 'locked_teaser' || '${a['status']}' == 'locked';
  int _count(String f) => f == 'All' ? areas.length : areas.where((a) => f == 'Locked' ? _locked(a) : !_locked(a)).length;

  List<Map<String, dynamic>> get _rows {
    var list = areas;
    if (filter != 'All') list = list.where((a) => filter == 'Locked' ? _locked(a) : !_locked(a)).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((a) => a.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _edit(Map? a) async {
    final lang = ref.read(localeCodeProvider);
    final en = TextEditingController(text: '${asMap(a?['name'])?['en'] ?? ''}');
    final ar = TextEditingController(text: '${asMap(a?['name'])?['ar'] ?? ''}');
    final city = TextEditingController(text: '${asMap(a?['cityName'])?['en'] ?? a?['cityId'] ?? ''}');
    final fee = TextEditingController(
        text: a == null ? '0' : '${asInt(a['travelFee'] ?? a['travelFeeAmount']) / 100}');
    final ok = await v2Form(
      context,
      title: a == null ? (lang == 'ar' ? 'منطقة جديدة' : 'New area') : (lang == 'ar' ? 'تعديل المنطقة' : 'Edit area'),
      bodyBuilder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(label: 'Name (EN)', child: TextField(controller: en)),
          const SizedBox(height: 12),
          V2FormField(label: 'الاسم (AR)', child: TextField(controller: ar)),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'المدينة' : 'City', child: TextField(controller: city)),
          const SizedBox(height: 12),
          V2FormField(
              label: lang == 'ar' ? 'رسوم الانتقال (ج.م)' : 'Travel fee (EGP)',
              child: TextField(controller: fee, keyboardType: TextInputType.number)),
        ],
      ),
      onValidate: () {
        if (en.text.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'الاسم مطلوب' : 'Name is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    final payload = {
      'name': {'en': en.text.trim(), 'ar': ar.text.trim()},
      'city': city.text.trim(),
      'travelFee': ((double.tryParse(fee.text.trim()) ?? 0) * 100).round(),
    };
    try {
      if (a == null) {
        await staffClient.post('/admin/areas', data: payload);
      } else {
        await staffClient.patch('/admin/areas/${idOf(a)}', data: payload);
      }
      if (mounted) {
        v2Toast(context, a == null ? (lang == 'ar' ? 'تم الإنشاء' : 'Area created') : (lang == 'ar' ? 'تم التحديث' : 'Area updated'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleLock(Map a) async {
    try {
      await staffClient.patch('/admin/areas/${idOf(a)}', data: {'status': _locked(a) ? 'active' : 'locked_teaser'});
      _load();
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map a) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context,
        title: lang == 'ar' ? 'حذف المنطقة؟' : 'Delete area?',
        body: '"${locName(a['name'], lang)}" ${lang == 'ar' ? 'ستُحذف.' : 'is removed from the console.'}',
        confirmLabel: t(V2Copy.delete, lang),
        danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/areas/${idOf(a)}');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Area deleted');
        _load();
      }
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
        V2Btn.primary(lang == 'ar' ? '+ منطقة' : '+ New Area', onPressed: () => _edit(null), size: V2BtnSize.sm),
      ],
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المنطقة' : 'Area', flex: 1),
        V2Col(lang == 'ar' ? 'المدينة' : 'City', flex: 1),
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
              GestureDetector(
                onTap: () => _edit(a),
                child: Text(money(asInt(a['travelFee'] ?? a['travelFeeAmount']), lang),
                    style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, color: Ops.plum)),
              ),
              Align(alignment: AlignmentDirectional.centerStart, child: V2StatusPill.forLabel(_locked(a) ? 'Locked' : 'Active')),
            ],
            actions: [
              V2Btn(label: _locked(a) ? (lang == 'ar' ? 'فتح' : 'Unlock') : (lang == 'ar' ? 'قفل' : 'Lock'),
                  onPressed: () => _toggleLock(a), size: V2BtnSize.row),
              V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _edit(a), size: V2BtnSize.row),
              V2Btn.danger(lang == 'ar' ? 'حذف' : 'Delete', onPressed: () => _delete(a), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
