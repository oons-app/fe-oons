import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

/// Customer referral programme: when a customer's invited friend completes a
/// first booking, the inviter gets a one-time coupon. Marketing sets the
/// discount, an optional cap, how long it lasts, and can switch it off.
class V2ReferralSettings extends StatefulWidget {
  const V2ReferralSettings({super.key, required this.lang, required this.canWrite, this.onChanged});
  final String lang;
  final bool canWrite;
  final VoidCallback? onChanged;

  @override
  State<V2ReferralSettings> createState() => _V2ReferralSettingsState();
}

class _V2ReferralSettingsState extends State<V2ReferralSettings> {
  final percent = TextEditingController();
  final capEgp = TextEditingController();
  final days = TextEditingController();
  bool enabled = true;
  bool loaded = false;
  bool saving = false;
  String? error;

  bool get ar => widget.lang == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    percent.dispose();
    capEgp.dispose();
    days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await staffClient.get('/admin/settings/referral');
      if (!mounted) return;
      setState(() {
        enabled = d['enabled'] != false;
        percent.text = '${(d['percent'] as num?)?.toInt() ?? 50}';
        capEgp.text = '${((d['maxDiscount'] as num?)?.toInt() ?? 50000) ~/ 100}';
        days.text = '${(d['validDays'] as num?)?.toInt() ?? 90}';
        loaded = true;
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _save() async {
    final p = int.tryParse(percent.text.trim());
    final cap = int.tryParse(capEgp.text.trim().isEmpty ? '0' : capEgp.text.trim());
    final d = int.tryParse(days.text.trim());
    if (p == null || p < 1 || p > 100 || cap == null || cap < 0 || d == null || d < 1 || d > 365) {
      v2Toast(context, ar ? 'راجع الأرقام: الخصم ١–١٠٠، المدة ١–٣٦٥ يوما' : 'Check the numbers: discount 1–100, validity 1–365 days', error: true);
      return;
    }
    final ok = await v2Confirm(
      context,
      title: ar ? 'حفظ إعدادات الدعوات' : 'Save referral settings',
      body: ar
          ? 'تسري الأرقام الجديدة على المكافآت التي تصدر من الآن. المكافآت الصادرة لا تتغير.'
          : 'The new numbers apply to rewards issued from now on. Rewards already issued do not change.',
      confirmLabel: ar ? 'حفظ' : 'Save',
    );
    if (!ok || !mounted) return;
    setState(() => saving = true);
    try {
      await staffClient.patch('/admin/settings/referral', data: {
        'enabled': enabled,
        'percent': p,
        'maxDiscount': cap * 100,
        'validDays': d,
      });
      if (mounted) {
        v2Toast(context, ar ? 'تم الحفظ' : 'Saved');
        widget.onChanged?.call();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _num(String label, TextEditingController c, {String? hint}) => SizedBox(
        width: 150,
        child: V2FormField(
          label: label,
          child: TextField(
            controller: c,
            enabled: widget.canWrite,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontFamily: Ops.mono),
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return V2SectionCard(
      title: ar ? 'دعوة صديقة: مكافأة العميلة' : 'Customer referral reward',
      subtitle: ar
          ? 'عندما تكمل صديقة مدعوّة أول حجز، تحصل صاحبة الدعوة على كوبون لمرة واحدة. لا ينطبق على الاشتراكات.'
          : 'When an invited friend completes her first booking, the customer who invited her gets a one-time coupon. Does not apply to subscriptions.',
      trailing: [
        if (loaded) V2StatusPill(label: enabled ? (ar ? 'يعمل' : 'On') : (ar ? 'متوقف' : 'Off'), tone: enabled ? V2Tone.ok : V2Tone.neutral),
      ],
      child: error != null
          ? V2ErrorBanner(message: error!, onRetry: _load)
          : !loaded
              ? const SizedBox(height: 40, child: Align(alignment: AlignmentDirectional.centerStart, child: Text('…')))
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    V2FilterChip(
                      label: ar ? 'تفعيل الدعوات' : 'Invites on',
                      selected: enabled,
                      onTap: widget.canWrite ? () => setState(() => enabled = !enabled) : () {},
                    ),
                    _num(ar ? 'الخصم ٪' : 'Discount %', percent, hint: '50'),
                    _num(ar ? 'حد أقصى ج.م (٠ = بدون)' : 'Cap EGP (0 = none)', capEgp, hint: '500'),
                    _num(ar ? 'الصلاحية (أيام)' : 'Valid (days)', days, hint: '90'),
                    if (widget.canWrite) V2Btn.primary(saving ? '…' : (ar ? 'حفظ' : 'Save'), onPressed: saving ? null : _save),
                  ],
                ),
    );
  }
}
