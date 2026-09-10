import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  Map<String, dynamic>? settings;
  bool loading = true;
  String? error;
  String mode = 'simulate';
  bool waiver = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/settings/payments');
      setState(() {
        settings = data;
        mode = '${data['mode'] ?? 'simulate'}';
        waiver = data['feeWaiverEnabled'] == true;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _patch(Map<String, dynamic> body, String okMsg) async {
    try {
      final data = await staffClient.patch('/admin/settings/payments', data: body);
      setState(() {
        settings = data;
        mode = '${data['mode'] ?? mode}';
        waiver = data['feeWaiverEnabled'] == true;
      });
      if (mounted) v2Toast(context, okMsg);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _editKey(String field, String label) async {
    final lang = ref.read(localeCodeProvider);
    final ctl = TextEditingController();
    try {
      final ok = await v2Form(
        context,
        title: '${lang == 'ar' ? 'تعديل' : 'Edit'} $label',
        bodyBuilder: (ctx, _) => V2FormField(
          label: label,
          child: TextField(controller: ctl, obscureText: field.contains('Key')),
        ),
      );
      if (ok && ctl.text.trim().isNotEmpty) {
        _patch({field: ctl.text.trim()}, lang == 'ar' ? 'تم الحفظ' : 'Saved');
      }
    } finally {
      ctl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'payments.settings')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final s = settings ?? {};
    final rows = <(String field, String label, String value)>[
      ('paymobKey', 'Paymob', s['paymobKeySet'] == true ? 'pk_live_••••' : (lang == 'ar' ? 'غير مُعيّن' : 'not set')),
      ('webhookUrl', 'Webhook', '${s['webhookUrl'] ?? 'https://api.oons.app/hooks/paymob'}'),
      ('fawryKey', 'Fawry', s['fawryKeySet'] == true ? 'merchant ••••' : (lang == 'ar' ? 'غير مُعيّن' : 'not set')),
    ];

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 780;
            final cards = [
              _card(
                title: lang == 'ar' ? 'وضع البوابة' : 'Gateway mode',
                subtitle: lang == 'ar'
                    ? 'المحاكاة توجّه العمليات لبيئة اختبار ولا تحرّك أموالاً'
                    : 'Simulate routes charges to a sandbox and never moves money',
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final m in const ['live', 'simulate'])
                      V2Pill(
                        label: m == 'live' ? 'Live' : 'Simulate',
                        on: mode == m,
                        onTap: () => _patch({'mode': m}, '${lang == 'ar' ? 'الوضع الآن' : 'Gateway set to'} $m'),
                      ),
                  ],
                ),
              ),
              _card(
                title: lang == 'ar' ? 'إعفاء الرسوم' : 'Fee waiver',
                subtitle: lang == 'ar'
                    ? 'يعفي رسوم الأمان على الحجوزات الجديدة'
                    : 'Waives the platform trust fee on new bookings',
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: V2Pill(
                    label: waiver
                        ? (lang == 'ar' ? 'مُفعّل — تُتخطى الرسوم' : 'Waiver ON — trust fee skipped')
                        : (lang == 'ar' ? 'مُعطّل — تُحصّل الرسوم' : 'Waiver OFF — trust fee charged'),
                    on: waiver,
                    onTap: () => _patch({'feeWaiverEnabled': !waiver},
                        waiver ? (lang == 'ar' ? 'أُلغي الإعفاء' : 'Fee waiver disabled') : (lang == 'ar' ? 'فُعّل الإعفاء' : 'Fee waiver enabled')),
                  ),
                ),
              ),
              _card(
                title: lang == 'ar' ? 'المزوّدون والويب هوك' : 'Providers & webhooks',
                child: Column(
                  children: [
                    for (final r in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(r.$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono, color: Ops.mutedSoft)),
                                ],
                              ),
                            ),
                            V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _editKey(r.$1, r.$2), size: V2BtnSize.sm),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ];
            if (!wide) {
              return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 14), child: c)]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _card({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Ops.muted, height: 1.4)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
