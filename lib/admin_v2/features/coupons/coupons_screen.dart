import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/coupons');
      setState(() { coupons = asMapList(data['coupons']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _createCoupon() async {
    final lang = ref.read(localeCodeProvider);
    String? code, discountType = 'percent';
    String? amountText;
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'إنشاء كوبون' : 'Create coupon',
      confirmLabel: lang == 'ar' ? 'إنشاء' : 'Create',
      bodyBuilder: (ctx, setLocal) => Column(children: [
        V2FormField(label: lang == 'ar' ? 'الكود' : 'Code', child: TextField(onChanged: (v) => code = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(
          label: lang == 'ar' ? 'نوع الخصم' : 'Discount type',
          child: DropdownButtonFormField<String>(
            value: discountType,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'percent', child: Text(lang == 'ar' ? 'نسبة مئوية' : 'Percent')),
              DropdownMenuItem(value: 'fixed', child: Text(lang == 'ar' ? 'مبلغ ثابت' : 'Fixed')),
            ],
            onChanged: (v) => setLocal(() => discountType = v),
          ),
        ),
        const SizedBox(height: 12),
        V2FormField(
          label: discountType == 'fixed' ? (lang == 'ar' ? 'المبلغ (ج.م)' : 'Amount (EGP)') : (lang == 'ar' ? 'النسبة %' : 'Percent %'),
          child: TextField(onChanged: (v) => amountText = v, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
        ),
      ]),
    );
    if (!confirmed) return;
    final raw = double.tryParse((amountText ?? '').trim()) ?? 0;
    final amount = discountType == 'fixed' ? (raw * 100).round() : raw.round();
    try {
      await staffClient.post('/admin/coupons', data: {
        'code': code,
        'discountType': discountType == 'fixed' ? 'fixed' : 'percent',
        'amount': amount,
        'active': true,
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم إنشاء الكوبون' : 'Coupon created'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _toggleActive(String id, bool currentStatus) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/coupons/$id', data: {'active': !currentStatus});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _showRedemptions(Map<String, dynamic> coupon) async {
    final lang = ref.read(localeCodeProvider);
    try {
      final data = await staffClient.get('/admin/coupons/${idOf(coupon)}/redemptions');
      final redemptions = asMapList(data['redemptions'] ?? []);
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${lang == 'ar' ? 'استخدامات' : 'Redemptions'}: ${coupon['code']}'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: redemptions.isEmpty
                ? Center(child: Text(lang == 'ar' ? 'لا توجد استخدامات' : 'No redemptions'))
                : ListView.builder(
                    itemCount: redemptions.length,
                    itemBuilder: (context, i) {
                      final r = redemptions[i];
                      return ListTile(
                        title: Text(personName(r, lang, fallbackId: '${r['userId'] ?? r['customerId']}')),
                        subtitle: Text('${r['bookingId'] != null ? '#${shortId('${r['bookingId']}')}' : ''} • ${formatDay(r['redeemedAt'] ?? r['usedAt'], lang)}'),
                        trailing: Text(money(asInt(r['discountAmount'] ?? r['amount']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(lang == 'ar' ? 'إغلاق' : 'Close')),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _deleteCoupon(String id) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context, title: lang == 'ar' ? 'حذف الكوبون' : 'Delete coupon', body: lang == 'ar' ? 'حذف هذا الكوبون؟' : 'Delete this coupon?', confirmLabel: t(V2Copy.delete, lang), danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/coupons/$id');
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Deleted'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'coupons.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canWrite = staffCan(staffState.effectiveRole, 'coupons.write');
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'الكوبونات' : 'Coupons',
          lang: lang,
          resultCount: loading ? null : coupons.length,
          actions: [if (canWrite) ElevatedButton.icon(onPressed: _createCoupon, icon: const Icon(Icons.add, size: 16), label: Text(lang == 'ar' ? 'إنشاء' : 'Create'))],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : coupons.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الكود' : 'Code',
                      lang == 'ar' ? 'النوع' : 'Type',
                      lang == 'ar' ? 'القيمة' : 'Value',
                      lang == 'ar' ? 'الاستخدامات' : 'Redemptions',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      if (canWrite) lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final c in coupons)
                        [
                          Text('${c['code'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                          Text('${c['discountType']}' == 'percent' || '${c['discountType']}' == 'percentage'
                              ? (lang == 'ar' ? 'نسبة' : 'Percent')
                              : (lang == 'ar' ? 'ثابت' : 'Fixed')),
                          Text(
                            ('${c['discountType']}' == 'percent' || '${c['discountType']}' == 'percentage')
                                ? '${asInt(c['amount'] ?? c['discountValue'])}%'
                                : money(asInt(c['amount'] ?? c['discountValue']), lang),
                            style: const TextStyle(fontFamily: Ops.mono),
                          ),
                          InkWell(
                            onTap: () => _showRedemptions(c),
                            child: Text('${asInt(c['redeemedCount'] ?? c['redemptionCount'])}${asInt(c['maxRedemptions']) > 0 ? '/${asInt(c['maxRedemptions'])}' : ''}', style: const TextStyle(fontFamily: Ops.mono, color: Ops.plum, decoration: TextDecoration.underline)),
                          ),
                          InkWell(
                            onTap: canWrite ? () => _toggleActive(idOf(c), c['active'] == true) : null,
                            child: V2StatusPill(label: c['active'] == true ? (lang == 'ar' ? 'نشط' : 'Active') : (lang == 'ar' ? 'متوقف' : 'Inactive'), tone: c['active'] == true ? V2Tone.ok : V2Tone.neutral),
                          ),
                          if (canWrite) TextButton(onPressed: () => _deleteCoupon(idOf(c)), child: Text(t(V2Copy.delete, lang))),
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
