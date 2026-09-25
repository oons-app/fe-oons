import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen> {
  Map<String, dynamic>? settings;
  bool loading = true;
  String? error;
  final _iosMin = TextEditingController();
  final _androidMin = TextEditingController();
  final _iosUrl = TextEditingController();
  final _androidUrl = TextEditingController();
  final _msgEn = TextEditingController();
  final _msgAr = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _iosMin.dispose();
    _androidMin.dispose();
    _iosUrl.dispose();
    _androidUrl.dispose();
    _msgEn.dispose();
    _msgAr.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> data) {
    settings = data;
    _iosMin.text = '${data['iosMinBuild'] ?? 0}';
    _androidMin.text = '${data['androidMinBuild'] ?? 0}';
    _iosUrl.text = '${data['iosStoreUrl'] ?? ''}';
    _androidUrl.text = '${data['androidStoreUrl'] ?? ''}';
    _msgEn.text = '${data['messageEn'] ?? ''}';
    _msgAr.text = '${data['messageAr'] ?? ''}';
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/settings/app-update');
      setState(() {
        _apply(data);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  int? _parseMin(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 0) return null;
    return n;
  }

  Future<void> _save() async {
    final lang = ref.read(localeCodeProvider);
    final ios = _parseMin(_iosMin.text);
    final android = _parseMin(_androidMin.text);
    if (ios == null || android == null) {
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'رقم البناء يجب أن يكون ٠ أو أعلى' : 'Build numbers must be 0 or higher', error: true);
      }
      return;
    }
    setState(() => saving = true);
    try {
      final data = await staffClient.patch('/admin/settings/app-update', data: {
        'iosMinBuild': ios,
        'androidMinBuild': android,
        'iosStoreUrl': _iosUrl.text.trim(),
        'androidStoreUrl': _androidUrl.text.trim(),
        'messageEn': _msgEn.text.trim(),
        'messageAr': _msgAr.text.trim(),
      });
      setState(() => _apply(data));
      if (mounted) v2Toast(context, lang == 'ar' ? 'تم الحفظ' : 'Saved');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _force(String platform) async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    final ctl = TextEditingController(
      text: platform == 'android' ? _androidMin.text : _iosMin.text,
    );
    try {
      final ok = await v2Form(
        context,
        title: ar ? 'فرض التحديث' : 'Force update',
        danger: true,
        confirmLabel: ar ? 'فرض الآن' : 'Force now',
        bodyBuilder: (ctx, _) => V2FormField(
          label: ar ? 'أقل رقم بناء مسموح (٠ يلغي الفرض)' : 'Minimum allowed build (0 lifts the force)',
          child: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
      );
      if (!ok) return;
      final min = _parseMin(ctl.text);
      if (min == null) {
        if (mounted) v2Toast(context, ar ? 'رقم بناء غير صالح' : 'Need a valid build number', error: true);
        return;
      }
      final confirm = await v2Confirm(
        context,
        title: ar ? 'تأكيد فرض التحديث' : 'Confirm force update',
        body: min == 0
            ? (ar ? 'سيُرفع القفل عن هذا النظام. التطبيقات القديمة ستعمل من جديد.' : 'This lifts the lock. Older apps will work again.')
            : (ar
                ? 'كل تطبيق برقم بناء أقل من $min على هذا النظام سيتوقف حتى تُثبَّت النسخة الجديدة من المتجر.'
                : 'Every $platform build below $min will be blocked until the user installs from the store.'),
        confirmLabel: ar ? 'فرض' : 'Force',
        danger: true,
      );
      if (!confirm) return;
      final data = await staffClient.post('/admin/settings/app-update/force', data: {
        'platform': platform,
        'minBuild': min,
      });
      setState(() => _apply(data));
      if (mounted) {
        v2Toast(context, min == 0 ? (ar ? 'أُلغي الفرض' : 'Force lifted') : (ar ? 'فُرض التحديث' : 'Force update set'));
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    } finally {
      ctl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final ar = lang == 'ar';
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'app.force_update')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final s = settings ?? {};
    final iosForced = s['iosForced'] == true;
    final androidForced = s['androidForced'] == true;

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          Text(
            ar
                ? 'يُقفل التطبيق الأصلي فقط. الويب (ليدي / التشغيل) لا يتأثر. رقم البناء هو الرقم بعد + في pubspec (الآن ١.٠.٢+١٦). التطبيقات التي نُشرت قبل هذا الفحص لا يمكن فرض تحديثها.'
                : 'This locks native store builds only. Web (lady / ops) is unaffected. The build number is the +N in pubspec (currently 1.0.2+16). Apps shipped before this check cannot be forced.',
            style: const TextStyle(fontSize: 13, color: Ops.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 780;
            final cards = [
              _statusCard(
                title: 'iOS',
                forced: iosForced,
                min: s['iosMinBuild'] ?? 0,
                ar: ar,
                onForce: () => _force('ios'),
                onLift: iosForced ? () => _forceMin('ios', 0) : null,
              ),
              _statusCard(
                title: 'Android',
                forced: androidForced,
                min: s['androidMinBuild'] ?? 0,
                ar: ar,
                onForce: () => _force('android'),
                onLift: androidForced ? () => _forceMin('android', 0) : null,
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
          const SizedBox(height: 14),
          _card(
            title: ar ? 'الحد الأدنى وروابط المتجر' : 'Minimum builds & store links',
            subtitle: ar ? '٠ = لا فرض. احفظي بعد التعديل، أو استخدمي أزرار الفرض أعلاه.' : '0 = no force. Save after editing, or use the force buttons above.',
            child: Column(
              children: [
                _field(ar ? 'أقل بناء iOS' : 'iOS min build', _iosMin, number: true),
                _field(ar ? 'أقل بناء Android' : 'Android min build', _androidMin, number: true),
                _field(ar ? 'رابط آب ستور' : 'App Store URL', _iosUrl),
                _field(ar ? 'رابط بلاي ستور' : 'Play Store URL', _androidUrl),
                _field(ar ? 'رسالة إنجليزي (اختياري)' : 'English message (optional)', _msgEn, maxLines: 3),
                _field(ar ? 'رسالة عربي (اختياري)' : 'Arabic message (optional)', _msgAr, maxLines: 3),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: V2Btn.primary(
                    ar ? 'حفظ الإعدادات' : 'Save settings',
                    onPressed: saving ? null : _save,
                  ),
                ),
                if (s['updatedBy'] != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    ar ? 'آخر تعديل: ${s['updatedBy']}' : 'Last change: ${s['updatedBy']}',
                    style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft, fontFamily: Ops.mono),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: V2Btn.danger(
              ar ? 'فرض على النظامين' : 'Force both platforms',
              onPressed: () => _force('both'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _forceMin(String platform, int min) async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    final confirm = await v2Confirm(
      context,
      title: ar ? 'إلغاء الفرض' : 'Lift force update',
      body: ar ? 'التطبيقات القديمة ستعمل من جديد على هذا النظام.' : 'Older apps on this platform will work again.',
      confirmLabel: ar ? 'إلغاء الفرض' : 'Lift',
      danger: true,
    );
    if (!confirm) return;
    try {
      final data = await staffClient.post('/admin/settings/app-update/force', data: {
        'platform': platform,
        'minBuild': min,
      });
      setState(() => _apply(data));
      if (mounted) v2Toast(context, ar ? 'أُلغي الفرض' : 'Force lifted');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _statusCard({
    required String title,
    required bool forced,
    required Object min,
    required bool ar,
    required VoidCallback onForce,
    VoidCallback? onLift,
  }) {
    return _card(
      title: title,
      subtitle: forced
          ? (ar ? 'مفروض — البناء $min فما فوق فقط' : 'Forced — build $min and above only')
          : (ar ? 'غير مفروض. كل البناءات تعمل.' : 'Not forced. Every build can open.'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          V2Btn.danger(ar ? 'فرض التحديث' : 'Force update', onPressed: onForce, size: V2BtnSize.sm),
          if (onLift != null) V2Btn.ghost(ar ? 'إلغاء الفرض' : 'Lift force', onPressed: onLift, size: V2BtnSize.sm),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl, {bool number = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: V2FormField(
        label: label,
        child: TextField(
          controller: ctl,
          maxLines: maxLines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: const TextStyle(fontSize: 13.5),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
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
