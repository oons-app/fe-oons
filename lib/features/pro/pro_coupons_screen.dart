import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/errors.dart';

/// "كوبوناتي" — a provider's own discount codes. Always kind "provider" and
/// scoped to this provider's bookings only (ownerProviderId is implicit
/// server-side); separate from platform-wide coupons managed by staff.
class ProCouponsScreen extends ConsumerStatefulWidget {
  const ProCouponsScreen({super.key});

  @override
  ConsumerState<ProCouponsScreen> createState() => _ProCouponsScreenState();
}

class _ProCouponsScreenState extends ConsumerState<ProCouponsScreen> {
  List<Map<String, dynamic>> coupons = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await ref.read(repoProvider).proCoupons();
      if (mounted) {
        setState(() {
          coupons = rows;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final lang = langOf(ref);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _CouponEditorSheet(lang: lang, existing: existing, repo: ref.read(repoProvider)),
    );
    if (changed == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          lang == 'ar' ? 'اتحفظ الكوبون.' : 'Coupon saved.',
        )));
      }
    }
  }

  bool _isPercent(Map c) => '${c['discountType']}' == 'percent';
  bool _active(Map c) => c['active'] == true;
  int _num(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final ar = lang == 'ar';
    return Scaffold(
      backgroundColor: Pro.bg,
      appBar: AppBar(
        backgroundColor: Pro.bg,
        elevation: 0,
        foregroundColor: Pro.ink,
        title: Text(ar ? 'كوبوناتي' : 'My coupons'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Pro.plum))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  ar
                      ? 'اعملي كود خصم لعميلاتك. الكوبون ده بتاعك بس ومنفصل عن كوبونات المنصة.'
                      : 'Create a discount code for your clients. This coupon is yours only, separate from platform-wide coupons.',
                  style: const TextStyle(fontSize: 13, color: Pro.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (coupons.isEmpty)
                  ProCard(
                    child: Text(
                      ar ? 'مفيش كوبونات لسه.' : 'No coupons yet.',
                      style: const TextStyle(fontSize: 14, color: Pro.muted),
                    ),
                  )
                else
                  ...coupons.map((c) => _couponCard(lang, c)),
                const SizedBox(height: 14),
                ProSoftButton(label: ar ? '+ كوبون جديد' : '+ New coupon', onTap: () => _openEditor()),
              ],
            ),
    );
  }

  Widget _couponCard(String lang, Map<String, dynamic> c) {
    final ar = lang == 'ar';
    final percent = _isPercent(c);
    final amount = _num(c['amount']);
    final valueLabel = percent ? '${digits(amount, ar: ar)}%' : '${digits(amount ~/ 100, ar: ar)} ${ar ? 'ج.م' : 'EGP'}';
    final redeemed = _num(c['redeemedCount']);
    final limit = _num(c['maxRedemptions']);
    final ends = c['endsAt'];
    final active = _active(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openEditor(existing: c),
        borderRadius: BorderRadius.circular(Pro.rCard),
        child: ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${c['code'] ?? ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: T.mono, color: Pro.ink),
                    ),
                  ),
                  ProPill(active ? (ar ? 'فعّال' : 'Active') : (ar ? 'متوقّف' : 'Inactive'), soft: !active, hot: active),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  valueLabel,
                  '${ar ? 'استخدام' : 'used'} ${digits(redeemed, ar: ar)}${limit > 0 ? '/${digits(limit, ar: ar)}' : ''}',
                  if (ends != null) '${ar ? 'تنتهي' : 'ends'} ${_fmtDate(ends)}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: Pro.muted, fontFamily: T.mono),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic v) {
    final d = DateTime.tryParse('$v');
    if (d == null) return '$v';
    return DateFormat('yyyy-MM-dd').format(d.toLocal());
  }
}

class _CouponEditorSheet extends StatefulWidget {
  const _CouponEditorSheet({required this.lang, required this.existing, required this.repo});
  final String lang;
  final Map<String, dynamic>? existing;
  final Repo repo;

  @override
  State<_CouponEditorSheet> createState() => _CouponEditorSheetState();
}

class _CouponEditorSheetState extends State<_CouponEditorSheet> {
  late final code = TextEditingController(text: '${widget.existing?['code'] ?? ''}');
  late String discountType = '${widget.existing?['discountType'] ?? 'percent'}' == 'fixed' ? 'fixed' : 'percent';
  late final amount = TextEditingController(text: _initialAmount());
  late final maxDiscount = TextEditingController(text: _egpOrEmpty(widget.existing?['maxDiscount']));
  late final minService = TextEditingController(text: _egpOrEmpty(widget.existing?['minService']));
  late final maxRedemptions = TextEditingController(text: _intOrEmpty(widget.existing?['maxRedemptions']));
  late final maxPerUser = TextEditingController(text: _intOrEmpty(widget.existing?['maxPerUser']));
  DateTime? startsAt;
  DateTime? endsAt;
  late bool active = widget.existing?['active'] != false;
  bool busy = false;

  bool get ar => widget.lang == 'ar';
  bool get isEdit => widget.existing != null;

  String _initialAmount() {
    final v = widget.existing?['amount'];
    if (v == null) return '';
    final n = (v as num).toDouble();
    return discountType == 'fixed' ? '${(n / 100).round()}' : '${n.round()}';
  }

  String _egpOrEmpty(dynamic v) {
    if (v == null) return '';
    final n = (v as num).toInt();
    return n > 0 ? '${(n / 100).round()}' : '';
  }

  String _intOrEmpty(dynamic v) {
    if (v == null) return '';
    final n = (v as num).toInt();
    return n > 0 ? '$n' : '';
  }

  @override
  void initState() {
    super.initState();
    startsAt = DateTime.tryParse('${widget.existing?['startsAt'] ?? ''}');
    endsAt = DateTime.tryParse('${widget.existing?['endsAt'] ?? ''}');
  }

  @override
  void dispose() {
    code.dispose();
    amount.dispose();
    maxDiscount.dispose();
    minService.dispose();
    maxRedemptions.dispose();
    maxPerUser.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? startsAt : endsAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        startsAt = picked;
      } else {
        endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final codeVal = code.text.trim();
    if (codeVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'الكود مطلوب.' : 'Code is required.')),
      );
      return;
    }
    final amountRaw = double.tryParse(amount.text.trim()) ?? 0;
    if (amountRaw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'أدخلي قيمة الخصم.' : 'Enter a discount amount.')),
      );
      return;
    }
    if (discountType == 'percent' && (amountRaw < 1 || amountRaw > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'النسبة لازم تكون من ١ لـ ١٠٠.' : 'Percent must be 1–100.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        'code': codeVal,
        'discountType': discountType,
        'amount': discountType == 'percent' ? amountRaw.round() : (amountRaw * 100).round(),
        if (maxDiscount.text.trim().isNotEmpty)
          'maxDiscount': ((double.tryParse(maxDiscount.text.trim()) ?? 0) * 100).round(),
        if (minService.text.trim().isNotEmpty)
          'minService': ((double.tryParse(minService.text.trim()) ?? 0) * 100).round(),
        if (maxRedemptions.text.trim().isNotEmpty)
          'maxRedemptions': int.tryParse(maxRedemptions.text.trim()) ?? 0,
        if (maxPerUser.text.trim().isNotEmpty) 'maxPerUser': int.tryParse(maxPerUser.text.trim()) ?? 0,
        'startsAt': startsAt?.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'active': active,
      };
      final id = widget.existing?['id'] as String?;
      if (isEdit && id != null) {
        await widget.repo.proPatchCoupon(id, body);
      } else {
        await widget.repo.proCreateCoupon(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, widget.lang))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 12, color: Pro.muted));

  Widget _dateRow(String label, DateTime? value, {required bool start}) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(start: start),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F5),
                borderRadius: BorderRadius.circular(Pro.rSm),
                border: Border.all(color: const Color(0xFFE0D6CE)),
              ),
              child: Text(
                value == null ? label : DateFormat('yyyy-MM-dd').format(value),
                style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: value == null ? Pro.muted : Pro.ink,
                ),
              ),
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: () => setState(() {
              if (start) {
                startsAt = null;
              } else {
                endsAt = null;
              }
            }),
            icon: const Icon(Icons.close, size: 18, color: Pro.muted),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Pro.lineSoft, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? (ar ? 'الكوبون' : 'Coupon') : (ar ? 'كوبون جديد' : 'New coupon'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close, color: Pro.muted)),
              ],
            ),
            const SizedBox(height: 14),
            _label(ar ? 'الكود' : 'Code'),
            const SizedBox(height: 6),
            ProField(controller: code, mono: true),
            const SizedBox(height: 12),
            _label(ar ? 'نوع الخصم' : 'Discount type'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F5),
                borderRadius: BorderRadius.circular(Pro.rSm),
                border: Border.all(color: const Color(0xFFE0D6CE)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: discountType,
                  items: [
                    DropdownMenuItem(value: 'percent', child: Text(ar ? 'نسبة %' : 'Percent %')),
                    DropdownMenuItem(value: 'fixed', child: Text(ar ? 'قيمة ثابتة (ج.م)' : 'Fixed amount (EGP)')),
                  ],
                  onChanged: (v) => setState(() => discountType = v ?? 'percent'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _label(discountType == 'fixed' ? (ar ? 'القيمة (ج.م)' : 'Value (EGP)') : (ar ? 'النسبة %' : 'Percent %')),
            const SizedBox(height: 6),
            ProField(controller: amount, mono: true, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            if (discountType == 'percent') ...[
              _label(ar ? 'أقصى خصم (ج.م، اختياري)' : 'Max discount (EGP, optional)'),
              const SizedBox(height: 6),
              ProField(controller: maxDiscount, mono: true, keyboard: TextInputType.number),
              const SizedBox(height: 12),
            ],
            _label(ar ? 'أقل قيمة حجز (ج.م، اختياري)' : 'Min service total (EGP, optional)'),
            const SizedBox(height: 6),
            ProField(controller: minService, mono: true, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _label(ar ? 'أقصى عدد استخدامات (اختياري)' : 'Max redemptions (optional)'),
            const SizedBox(height: 6),
            ProField(controller: maxRedemptions, mono: true, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _label(ar ? 'أقصى استخدام لكل عميلة (اختياري)' : 'Max per user (optional)'),
            const SizedBox(height: 6),
            ProField(controller: maxPerUser, mono: true, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _label(ar ? 'تبدأ في (اختياري)' : 'Starts on (optional)'),
            const SizedBox(height: 6),
            _dateRow(ar ? 'بدون حد' : 'No limit', startsAt, start: true),
            const SizedBox(height: 12),
            _label(ar ? 'تنتهي في (اختياري)' : 'Ends on (optional)'),
            const SizedBox(height: 6),
            _dateRow(ar ? 'بدون حد' : 'No limit', endsAt, start: false),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ar ? 'فعّال' : 'Active', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: active,
              activeColor: Pro.plum,
              onChanged: (v) => setState(() => active = v),
            ),
            const SizedBox(height: 6),
            ProPrimaryButton(label: ar ? 'احفظي' : 'Save', enabled: !busy, onTap: _save),
          ],
        ),
      ),
    );
  }
}
