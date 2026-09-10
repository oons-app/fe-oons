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
  bool feeWaiverEnabled = false;
  final webhookCtrl = TextEditingController();
  final paymobCtrl = TextEditingController();
  final fawryCtrl = TextEditingController();
  final waiverUntilCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    webhookCtrl.dispose();
    paymobCtrl.dispose();
    fawryCtrl.dispose();
    waiverUntilCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/settings/payments');
      setState(() {
        settings = data;
        mode = '${data['mode'] ?? 'simulate'}';
        feeWaiverEnabled = data['feeWaiverEnabled'] == true;
        webhookCtrl.text = '${data['webhookUrl'] ?? ''}';
        waiverUntilCtrl.text = '${data['feeWaiverUntil'] ?? ''}'.split('T').first;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _save() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final body = <String, dynamic>{
        'mode': mode,
        'webhookUrl': webhookCtrl.text.trim(),
        'feeWaiverEnabled': feeWaiverEnabled,
        'feeWaiverUntil': waiverUntilCtrl.text.trim(),
      };
      if (paymobCtrl.text.trim().isNotEmpty) body['paymobKey'] = paymobCtrl.text.trim();
      if (fawryCtrl.text.trim().isNotEmpty) body['fawryKey'] = fawryCtrl.text.trim();
      final data = await staffClient.patch('/admin/settings/payments', data: body);
      setState(() => settings = data);
      if (mounted) v2Toast(context, t(V2Copy.saved, lang));
      _load();
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'payments.settings')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'المدفوعات' : 'Payments',
          lang: lang,
          actions: [ElevatedButton(onPressed: loading ? null : _save, child: Text(t(V2Copy.save, lang)))],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                V2Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lang == 'ar' ? 'الوضع' : 'Mode', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    V2FilterChip(label: 'simulate', selected: mode == 'simulate', onTap: () => setState(() => mode = 'simulate')),
                    V2FilterChip(label: 'live', selected: mode == 'live', onTap: () => setState(() => mode = 'live')),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    settings?['liveAvailable'] == true
                        ? (lang == 'ar' ? 'Live جاهز' : 'Live credentials ready')
                        : (lang == 'ar' ? 'Live غير مكتمل' : 'Live credentials incomplete'),
                    style: const TextStyle(color: Ops.muted, fontSize: 12),
                  ),
                ])),
                const SizedBox(height: 12),
                V2Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lang == 'ar' ? 'إعفاء رسوم الثقة' : 'Trust fee waiver', style: const TextStyle(fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(lang == 'ar' ? 'تفعيل الإعفاء' : 'Enable fee waiver'),
                    value: feeWaiverEnabled,
                    onChanged: (v) => setState(() => feeWaiverEnabled = v),
                  ),
                  V2FormField(
                    label: lang == 'ar' ? 'حتى تاريخ (YYYY-MM-DD)' : 'Until (YYYY-MM-DD)',
                    child: TextField(controller: waiverUntilCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                  ),
                  Text(
                    settings?['feeWaiverActive'] == true
                        ? (lang == 'ar' ? 'الإعفاء نشط الآن' : 'Waiver is active now')
                        : (lang == 'ar' ? 'الإعفاء غير نشط' : 'Waiver not active'),
                    style: const TextStyle(color: Ops.muted, fontSize: 12),
                  ),
                ])),
                const SizedBox(height: 12),
                V2Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lang == 'ar' ? 'المفاتيح والويب هوك' : 'Keys & webhook', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  V2FormField(label: 'Webhook URL', child: TextField(controller: webhookCtrl, decoration: const InputDecoration(border: OutlineInputBorder()))),
                  const SizedBox(height: 12),
                  V2FormField(
                    label: settings?['paymobKeySet'] == true ? 'Paymob key (set — leave blank to keep)' : 'Paymob key',
                    child: TextField(controller: paymobCtrl, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
                  ),
                  const SizedBox(height: 12),
                  V2FormField(
                    label: settings?['fawryKeySet'] == true ? 'Fawry key (set — leave blank to keep)' : 'Fawry key',
                    child: TextField(controller: fawryCtrl, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder())),
                  ),
                ])),
                const SizedBox(height: 24),
              ]),
        ),
      ]),
    );
  }
}
