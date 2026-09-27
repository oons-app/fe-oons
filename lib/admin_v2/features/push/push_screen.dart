import 'dart:async';

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
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

class PushCampaignsScreen extends ConsumerStatefulWidget {
  const PushCampaignsScreen({super.key});

  @override
  ConsumerState<PushCampaignsScreen> createState() => _PushCampaignsScreenState();
}

class _PushCampaignsScreenState extends ConsumerState<PushCampaignsScreen> {
  final _titleEn = TextEditingController();
  final _titleAr = TextEditingController();
  final _bodyEn = TextEditingController();
  final _bodyAr = TextEditingController();
  final _coupon = TextEditingController();
  final _path = TextEditingController();
  String kind = 'marketing';
  String audience = 'clients';
  bool ios = true;
  bool android = true;
  bool sending = false;
  bool loading = true;
  String? error;
  Map<String, dynamic> status = const {};
  Map<String, dynamic> preview = const {};
  List<Map<String, dynamic>> campaigns = [];
  List<Map<String, dynamic>> coupons = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _titleEn.dispose();
    _titleAr.dispose();
    _bodyEn.dispose();
    _bodyAr.dispose();
    _coupon.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final st = await staffClient.get('/admin/push-campaigns/status');
      final list = await staffClient.get('/admin/push-campaigns');
      List<Map<String, dynamic>> codes = [];
      try {
        final c = await staffClient.get('/admin/coupons');
        codes = asMapList(c['coupons']).where((m) => m['active'] == true).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        status = Map<String, dynamic>.from(st);
        campaigns = asMapList(list['campaigns']);
        coupons = codes;
        loading = false;
      });
      unawaited(_preview());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _preview() async {
    try {
      final data = await staffClient.post('/admin/push-campaigns/preview', data: {
        'audience': audience,
        'platforms': [
          if (ios) 'ios',
          if (android) 'android',
        ],
      });
      if (mounted) setState(() => preview = Map<String, dynamic>.from(data));
    } catch (_) {}
  }

  Future<void> _send() async {
    final ar = ref.read(localeCodeProvider) == 'ar';
    if (!ios && !android) {
      v2Toast(context, ar ? 'اختاري نظاماً واحداً على الأقل' : 'Pick at least one platform', error: true);
      return;
    }
    if (kind == 'coupon' && _coupon.text.trim().isEmpty) {
      v2Toast(context, ar ? 'أدخلي كود الكوبون' : 'Enter a coupon code', error: true);
      return;
    }
    final ok = await v2Confirm(
      context,
      title: ar ? 'إرسال الإشعار الآن؟' : 'Send this push now?',
      body: ar
          ? 'سيصل الإشعار لكل الحسابات في الجمهور المختار على الأنظمة المحددة. يُسجَّل في سجل التدقيق.'
          : 'This goes to every matching account on the selected platforms. It is written to the audit trail.',
      confirmLabel: ar ? 'أرسل' : 'Send',
    );
    if (!ok) return;
    setState(() => sending = true);
    try {
      await staffClient.post('/admin/push-campaigns', data: {
        'kind': kind,
        'audience': audience,
        'platforms': [
          if (ios) 'ios',
          if (android) 'android',
        ],
        'titleEn': _titleEn.text.trim(),
        'titleAr': _titleAr.text.trim(),
        'bodyEn': _bodyEn.text.trim(),
        'bodyAr': _bodyAr.text.trim(),
        'couponCode': _coupon.text.trim(),
        'path': _path.text.trim(),
      });
      _titleEn.clear();
      _titleAr.clear();
      _bodyEn.clear();
      _bodyAr.clear();
      if (mounted) v2Toast(context, ar ? 'بدأ الإرسال' : 'Sending');
      await _boot();
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = ref.watch(localeCodeProvider) == 'ar';
    final sess = ref.watch(staffSessionProvider);
    if (sess.staffRole != roleSuper && !staffCan(sess.effectiveRole, 'push.campaigns')) {
      return Center(child: Text(ar ? 'للمديرة العامة فقط' : 'Super admin only'));
    }
    if (loading) return const V2Loading();
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: const TextStyle(color: Ops.terracottaInk)),
            const SizedBox(height: 10),
            V2Btn.ghost(ar ? 'إعادة المحاولة' : 'Retry', onPressed: _boot),
          ],
        ),
      );
    }
    final apns = status['apns'] == true;
    final fcm = status['fcm'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(ar ? 'إشعارات التطبيق' : 'Push campaigns', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          ar
              ? 'رسالة تسويقية أو كوبون يصل فوراً لتطبيقات iOS وAndroid. لا يُرسل واتساب.'
              : 'Marketing or coupon copy, delivered now to the iOS and Android apps. WhatsApp is not used.',
          style: const TextStyle(fontSize: 13, color: Ops.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            V2StatusPill(label: apns ? (ar ? 'APNs جاهز' : 'APNs ready') : (ar ? 'APNs غير مضبوط' : 'APNs off'), tone: apns ? V2Tone.ok : V2Tone.warn),
            V2StatusPill(label: fcm ? (ar ? 'FCM جاهز' : 'FCM ready') : (ar ? 'FCM غير مضبوط' : 'FCM off'), tone: fcm ? V2Tone.ok : V2Tone.warn),
          ],
        ),
        if (!fcm) ...[
          const SizedBox(height: 8),
          Text(
            ar
                ? 'أندرويد يحتاج FCM_SA_KEY_B64 (أو حساب GCP الحالي بصلاحية Firebase Cloud Messaging) وملف google-services.json في التطبيق.'
                : 'Android needs FCM_SA_KEY_B64 (or the existing GCP SA with Firebase Cloud Messaging Admin) plus google-services.json in the app.',
            style: const TextStyle(fontSize: 12, color: Ops.mutedSoft, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        V2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ar ? 'رسالة جديدة' : 'Compose', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _chips(ar ? 'النوع' : 'Kind', [
                ('marketing', ar ? 'تسويق' : 'Marketing'),
                ('coupon', ar ? 'كوبون' : 'Coupon'),
              ], kind, (v) => setState(() => kind = v)),
              const SizedBox(height: 10),
              _chips(ar ? 'الجمهور' : 'Audience', [
                ('clients', ar ? 'عميلات' : 'Clients'),
                ('providers', ar ? 'مهنيات' : 'Providers'),
                ('all', ar ? 'الجميع' : 'Everyone'),
              ], audience, (v) {
                setState(() => audience = v);
                unawaited(_preview());
              }),
              const SizedBox(height: 10),
              Text(ar ? 'الأنظمة' : 'Platforms', style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('iOS'),
                    selected: ios,
                    onSelected: (v) {
                      setState(() => ios = v);
                      unawaited(_preview());
                    },
                  ),
                  FilterChip(
                    label: const Text('Android'),
                    selected: android,
                    onSelected: (v) {
                      setState(() => android = v);
                      unawaited(_preview());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(ar ? 'العنوان إنجليزي' : 'Title (English)', _titleEn),
              _field(ar ? 'العنوان عربي' : 'Title (Arabic)', _titleAr),
              _field(ar ? 'النص إنجليزي' : 'Body (English)', _bodyEn, maxLines: 3),
              _field(ar ? 'النص عربي' : 'Body (Arabic)', _bodyAr, maxLines: 3),
              if (kind == 'coupon' || _coupon.text.isNotEmpty)
                _field(ar ? 'كود الكوبون' : 'Coupon code', _coupon),
              if (kind == 'coupon' && coupons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in coupons.take(12))
                      ActionChip(
                        label: Text('${c['code']}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                        onPressed: () => setState(() => _coupon.text = '${c['code']}'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _field(ar ? 'مسار اختياري مثل /browse/beauty' : 'Optional path, e.g. /browse/beauty', _path),
              const SizedBox(height: 8),
              Text(
                ar
                    ? 'الجمهور: ${preview['clients'] ?? '—'} عميلة · ${preview['providers'] ?? '—'} مهنية · ${preview['iosDevices'] ?? '—'} جهاز iOS · ${preview['androidDevices'] ?? '—'} أندرويد'
                    : 'Audience: ${preview['clients'] ?? '—'} clients · ${preview['providers'] ?? '—'} providers · ${preview['iosDevices'] ?? '—'} iOS · ${preview['androidDevices'] ?? '—'} Android',
                style: const TextStyle(fontSize: 12, color: Ops.mutedSoft, fontFamily: Ops.mono),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2Btn.primary(ar ? 'أرسل الآن' : 'Send now', onPressed: sending ? null : _send),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(ar ? 'المرسل مؤخراً' : 'Recent', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (campaigns.isEmpty)
          Text(ar ? 'لا شيء بعد.' : 'Nothing sent yet.', style: const TextStyle(color: Ops.muted)),
        for (final row in campaigns) ...[
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    V2StatusPill.forLabel('${row['kind']}'),
                    const SizedBox(width: 8),
                    V2StatusPill.forLabel('${row['status']}'),
                    const Spacer(),
                    Text('${row['audience']}', style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_titleOf(row), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_bodyOf(row), style: const TextStyle(fontSize: 13, color: Ops.muted, height: 1.4)),
                if ('${row['couponCode'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${row['couponCode']}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12.5)),
                ],
                const SizedBox(height: 8),
                Text(
                  ar
                      ? '${row['targeted'] ?? 0} حساب · iOS ${row['sentIos'] ?? 0} · أندرويد ${row['sentAndroid'] ?? 0} · فشل ${row['failed'] ?? 0} · ${row['actor'] ?? ''}'
                      : '${row['targeted'] ?? 0} accounts · iOS ${row['sentIos'] ?? 0} · Android ${row['sentAndroid'] ?? 0} · failed ${row['failed'] ?? 0} · ${row['actor'] ?? ''}',
                  style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft, fontFamily: Ops.mono),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _titleOf(Map row) {
    final t = row['title'];
    if (t is Map) return '${t['en'] ?? t['ar'] ?? ''}';
    return '';
  }

  String _bodyOf(Map row) {
    final t = row['body'];
    if (t is Map) return '${t['en'] ?? t['ar'] ?? ''}';
    return '';
  }

  Widget _chips(String label, List<(String, String)> items, String value, ValueChanged<String> onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final item in items)
              ChoiceChip(
                label: Text(item.$2),
                selected: value == item.$1,
                onSelected: (_) => onChange(item.$1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2FormField(
        label: label,
        child: TextField(
          controller: ctl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13.5),
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        ),
      ),
    );
  }
}
