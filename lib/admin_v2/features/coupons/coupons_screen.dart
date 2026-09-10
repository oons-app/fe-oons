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

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  List<Map<String, dynamic>> coupons = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (staffCan(ref.read(staffSessionProvider).effectiveRole, 'coupons.write')) {
        ref.read(v2HeaderConfigProvider.notifier).state =
            V2HeaderConfig(newLabel: 'Coupon', onNewRecord: () => _edit(null));
      }
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/coupons');
      setState(() {
        coupons = asMapList(data['coupons']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  bool _active(Map c) => c['active'] == true;
  bool _isPercent(Map c) {
    final t = '${c['discountType']}';
    return t == 'percent' || t == 'percentage';
  }

  int _count(String f) {
    if (f == 'All') return coupons.length;
    return coupons.where((c) => f == 'Active' ? _active(c) : !_active(c)).length;
  }

  List<Map<String, dynamic>> get _rows {
    var list = coupons;
    if (filter != 'All') list = list.where((c) => filter == 'Active' ? _active(c) : !_active(c)).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((c) => c.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _edit(Map? c) async {
    final lang = ref.read(localeCodeProvider);
    final code = TextEditingController(text: '${c?['code'] ?? ''}');
    var type = _isPercent(c ?? {}) || c == null ? 'percent' : 'fixed';
    var scope = '${c?['scope'] ?? 'Platform'}';
    final value = TextEditingController(
        text: c == null
            ? ''
            : _isPercent(c)
                ? '${asInt(c['amount'] ?? c['discountValue'])}'
                : '${asInt(c['amount'] ?? c['discountValue']) / 100}');
    final limit = TextEditingController(text: '${c?['maxRedemptions'] ?? c?['limit'] ?? ''}');
    final ok = await v2Form(
      context,
      title: c == null ? (lang == 'ar' ? 'كوبون جديد' : 'New coupon') : (lang == 'ar' ? 'تعديل الكوبون' : 'Edit coupon'),
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(label: lang == 'ar' ? 'الكود' : 'Code', child: TextField(controller: code)),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'النطاق' : 'Scope',
            child: DropdownButtonFormField<String>(
              initialValue: scope,
              items: const [DropdownMenuItem(value: 'Platform', child: Text('Platform')), DropdownMenuItem(value: 'Provider', child: Text('Provider'))],
              onChanged: (v) => scope = v ?? 'Platform',
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'النوع' : 'Type',
            child: DropdownButtonFormField<String>(
              initialValue: type,
              items: const [DropdownMenuItem(value: 'percent', child: Text('Percent')), DropdownMenuItem(value: 'fixed', child: Text('Fixed'))],
              onChanged: (v) => setLocal(() => type = v ?? 'percent'),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: type == 'fixed' ? (lang == 'ar' ? 'القيمة (ج.م)' : 'Value (EGP)') : (lang == 'ar' ? 'النسبة %' : 'Percent %'),
            child: TextField(controller: value, keyboardType: TextInputType.number),
          ),
          const SizedBox(height: 12),
          V2FormField(
              label: lang == 'ar' ? 'حد الاستخدام' : 'Redemption limit',
              child: TextField(controller: limit, keyboardType: TextInputType.number)),
        ],
      ),
      onValidate: () {
        if (code.text.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'الكود مطلوب' : 'Code is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    final raw = double.tryParse(value.text.trim()) ?? 0;
    final amount = type == 'fixed' ? (raw * 100).round() : raw.round();
    final payload = {
      'code': code.text.trim(),
      'scope': scope,
      'discountType': type,
      'amount': amount,
      if (limit.text.trim().isNotEmpty) 'maxRedemptions': int.tryParse(limit.text.trim()),
      if (c == null) 'active': true,
    };
    try {
      if (c == null) {
        await staffClient.post('/admin/coupons', data: payload);
      } else {
        await staffClient.patch('/admin/coupons/${idOf(c)}', data: payload);
      }
      if (mounted) {
        v2Toast(context, c == null ? (lang == 'ar' ? 'تم إنشاء الكوبون' : 'Coupon created') : (lang == 'ar' ? 'تم تحديث الكوبون' : 'Coupon updated'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _toggle(Map c) async {
    try {
      await staffClient.patch('/admin/coupons/${idOf(c)}', data: {'active': !_active(c)});
      _load();
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map c) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context,
        title: lang == 'ar' ? 'حذف الكوبون؟' : 'Delete coupon?',
        body: '"${c['code']}" ${lang == 'ar' ? 'سيُحذف من الكونسول.' : 'is removed from the console.'}',
        confirmLabel: t(V2Copy.delete, lang),
        danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/coupons/${idOf(c)}');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Coupon deleted');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _redemptions(Map c) async {
    final lang = ref.read(localeCodeProvider);
    try {
      final data = await staffClient.get('/admin/coupons/${idOf(c)}/redemptions');
      final rows = asMapList(data['redemptions'] ?? []);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${lang == 'ar' ? 'استخدامات' : 'Redemptions'} · ${c['code']}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Text(lang == 'ar' ? 'لا استخدامات' : 'No redemptions', style: const TextStyle(color: Ops.muted))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in rows)
                          ListTile(
                            dense: true,
                            title: Text(personName(r, lang, fallbackId: '${r['userId'] ?? r['customerId']}')),
                            subtitle: Text(formatDay(r['redeemedAt'] ?? r['usedAt'], lang),
                                style: const TextStyle(fontSize: 11, fontFamily: Ops.mono)),
                            trailing: Text(money(asInt(r['discountAmount'] ?? r['amount']), lang),
                                style: const TextStyle(fontFamily: Ops.mono)),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: V2Btn.ghost(lang == 'ar' ? 'إغلاق' : 'Close', onPressed: () => Navigator.pop(context)),
                ),
              ],
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'coupons.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'coupons.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا كوبونات' : 'Nothing here yet',
      actionsWidth: canWrite ? 120 : 8,
      trailingActions: [
        if (canWrite) V2Btn.primary(lang == 'ar' ? '+ كوبون' : '+ New Coupon', onPressed: () => _edit(null), size: V2BtnSize.sm),
      ],
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'الكود' : 'Code', fixed: 120),
        V2Col(lang == 'ar' ? 'النوع' : 'Type', fixed: 110),
        V2Col(lang == 'ar' ? 'مستخدم' : 'Used', fixed: 90),
        V2Col(lang == 'ar' ? 'الحد' : 'Limit', fixed: 90),
        V2Col(lang == 'ar' ? 'ينتهي' : 'Expires', fixed: 120),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 100),
      ],
      rows: [
        for (final c in _rows)
          V2GridRow(
            cells: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${c['code'] ?? ''}',
                      style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                  Text('${c['scope'] ?? 'Platform'}', style: const TextStyle(fontSize: 11, color: Ops.mutedSoft)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isPercent(c) ? (lang == 'ar' ? 'نسبة' : 'Percent') : (lang == 'ar' ? 'ثابت' : 'Fixed'),
                      style: const TextStyle(fontSize: 13)),
                  Text(
                    _isPercent(c)
                        ? '${asInt(c['amount'] ?? c['discountValue'])}%'
                        : money(asInt(c['amount'] ?? c['discountValue']), lang),
                    style: const TextStyle(fontSize: 11, color: Ops.mutedSoft, fontFamily: Ops.mono),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _redemptions(c),
                child: Text('${asInt(c['redeemedCount'] ?? c['redemptionCount'])}',
                    style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, color: Ops.plum)),
              ),
              Text('${asInt(c['maxRedemptions'] ?? c['limit'])}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Text(formatDayOnly(c['expiresAt'] ?? c['expires']),
                  style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
              GestureDetector(
                onTap: canWrite ? () => _toggle(c) : null,
                child: V2StatusPill(label: _active(c) ? 'Active' : 'Inactive', tone: _active(c) ? V2Tone.ok : V2Tone.neutral),
              ),
            ],
            actions: [
              if (canWrite) ...[
                V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _edit(c), size: V2BtnSize.row),
                V2Btn.danger(lang == 'ar' ? 'حذف' : 'Delete', onPressed: () => _delete(c), size: V2BtnSize.row),
              ],
            ],
          ),
      ],
    );
  }
}
