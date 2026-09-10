import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/areas');
      setState(() { areas = asMapList(data['areas']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _setStatus(String id, String status) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/areas/$id', data: {'status': status});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _editTravelFee(Map<String, dynamic> area) async {
    final lang = ref.read(localeCodeProvider);
    String? feeText = '${(asInt(area['travelFee'] ?? area['travelFeeAmount']) / 100).toStringAsFixed(2)}';
    final confirmed = await v2Form(
      context,
      title: '${lang == 'ar' ? 'تعديل رسوم السفر -' : 'Edit travel fee -'} ${locName(area['name'], lang)}',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setLocal) => V2FormField(
        label: lang == 'ar' ? 'رسوم السفر (ج.م)' : 'Travel fee (EGP)',
        child: TextField(
          controller: TextEditingController(text: feeText),
          onChanged: (v) => feeText = v,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
    );
    if (!confirmed) return;
    final fee = (double.tryParse(feeText?.trim() ?? '0') ?? 0) * 100;
    try {
      await staffClient.patch('/admin/areas/${idOf(area)}', data: {'travelFee': fee.round()});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _createArea() async {
    final lang = ref.read(localeCodeProvider);
    String? nameEn, nameAr, cityName, feeText = '0';
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'إنشاء منطقة' : 'Create area',
      confirmLabel: lang == 'ar' ? 'إنشاء' : 'Create',
      bodyBuilder: (ctx, setLocal) => Column(children: [
        V2FormField(label: 'Name (EN)', child: TextField(onChanged: (v) => nameEn = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: 'الاسم (AR)', child: TextField(onChanged: (v) => nameAr = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: lang == 'ar' ? 'المدينة' : 'City', child: TextField(onChanged: (v) => cityName = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: lang == 'ar' ? 'رسوم السفر (ج.م)' : 'Travel fee (EGP)', child: TextField(controller: TextEditingController(text: feeText), onChanged: (v) => feeText = v, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder()))),
      ]),
    );
    if (!confirmed) return;
    final fee = (double.tryParse(feeText?.trim() ?? '0') ?? 0) * 100;
    try {
      await staffClient.post('/admin/areas', data: {
        'name': {'en': nameEn, 'ar': nameAr},
        'city': cityName,
        'travelFee': fee.round(),
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم الإنشاء' : 'Created'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _deleteArea(String id) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context, title: lang == 'ar' ? 'حذف المنطقة' : 'Delete area', body: lang == 'ar' ? 'حذف هذه المنطقة؟' : 'Delete this area?', confirmLabel: t(V2Copy.delete, lang), danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/areas/$id');
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Deleted'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'areas.write')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'مناطق التغطية' : 'Coverage areas',
          lang: lang,
          resultCount: loading ? null : areas.length,
          actions: [ElevatedButton.icon(onPressed: _createArea, icon: const Icon(Icons.add, size: 16), label: Text(lang == 'ar' ? 'إنشاء' : 'Create'))],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : areas.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'المنطقة' : 'Area',
                      lang == 'ar' ? 'المدينة' : 'City',
                      lang == 'ar' ? 'رسوم السفر' : 'Travel fee',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final a in areas)
                        [
                          identityCell(locName(a['name'], lang), '${a['slug'] ?? shortId(idOf(a))}'),
                          Text(locName(a['cityName'], lang).isNotEmpty ? locName(a['cityName'], lang) : '${a['cityId'] ?? ''}'),
                          InkWell(
                            onTap: () => _editTravelFee(a),
                            child: Text(money(asInt(a['travelFee'] ?? a['travelFeeAmount']), lang), style: const TextStyle(fontFamily: Ops.mono, color: Ops.plum, decoration: TextDecoration.underline)),
                          ),
                          InkWell(
                            onTap: () => _setStatus(idOf(a), (a['locked'] == true || '${a['status']}' == 'locked_teaser') ? 'active' : 'locked_teaser'),
                            child: V2StatusPill(
                              label: statusLabel('${a['status'] ?? (a['locked'] == true ? 'locked' : 'active')}', lang),
                              tone: statusTone('${a['status'] ?? (a['locked'] == true ? 'locked' : 'active')}'),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _setStatus(idOf(a), (a['locked'] == true || '${a['status']}' == 'locked_teaser') ? 'active' : 'locked_teaser'),
                                child: Text((a['locked'] == true || '${a['status']}' == 'locked_teaser')
                                    ? (lang == 'ar' ? 'فتح' : 'Unlock')
                                    : (lang == 'ar' ? 'قفل' : 'Lock')),
                              ),
                              TextButton(
                                onPressed: () => _deleteArea(idOf(a)),
                                child: Text(t(V2Copy.delete, lang), style: const TextStyle(color: Ops.terracotta)),
                              ),
                            ],
                          ),
                        ],
                    ],
                  )),
                  const SizedBox(height: 24),
                ]),
        ),
      ]),
    );
  }
}
