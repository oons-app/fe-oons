import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
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
import 'package:oons/data/api.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  List<Map<String, dynamic>> staff = [];
  bool loading = true;
  String? error;
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(staffSessionProvider).staffRole == roleSuper) {
        ref.read(v2HeaderConfigProvider.notifier).state =
            V2HeaderConfig(newLabel: 'Staff member', onNewRecord: _create);
      }
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/staff');
      setState(() {
        staff = asMapList(data['staff']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _create() async {
    final lang = ref.read(localeCodeProvider);
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    final areasCtl = TextEditingController();
    final waCtl = TextEditingController();
    var role = roleOps;
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'إضافة عضو فريق' : 'New staff member',
        confirmLabel: lang == 'ar' ? 'إضافة' : 'Add',
        bodyBuilder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: lang == 'ar' ? 'الاسم' : 'Name', child: TextField(controller: name)),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'البريد' : 'Email', child: TextField(controller: email)),
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'كلمة مرور مؤقتة (١٠+ أحرف)' : 'Temp password (10+ chars)',
                child: TextField(controller: pass, obscureText: true)),
            const SizedBox(height: 12),
            V2FormField(
              label: lang == 'ar' ? 'الدور' : 'Role',
              child: DropdownButtonFormField<String>(
                initialValue: role,
                items: [
                  for (final r in const [roleOps, roleFinance, roleVendor, roleAm])
                    DropdownMenuItem(value: r, child: Text(roleLabel(r))),
                ],
                onChanged: (v) => role = v ?? roleOps,
              ),
            ),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'مناطق مدير الحساب' : 'AM areas', child: TextField(controller: areasCtl)),
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'واتساب العمليات (اختياري)' : 'Ops WhatsApp (optional)',
                child: TextField(controller: waCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '01XXXXXXXXX'))),
          ],
        ),
        onValidate: () {
          if (pass.text.length < 10) {
            v2Toast(context, lang == 'ar' ? 'كلمة المرور ١٠ أحرف على الأقل' : 'Password must be at least 10 characters', error: true);
            return false;
          }
          return true;
        },
      );
      if (!ok) return;
      try {
        await staffClient.post('/admin/staff', data: {
          'email': email.text.trim(),
          'password': pass.text,
          'staffRole': role,
          if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
          if (areasCtl.text.trim().isNotEmpty) 'assignedAreas': areasCtl.text.trim(),
          if (waCtl.text.trim().isNotEmpty) 'whatsapp': waCtl.text.trim(),
        });
        if (mounted) {
          v2Toast(context, lang == 'ar' ? 'تمت الإضافة' : 'Staff added');
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      name.dispose();
      email.dispose();
      pass.dispose();
      areasCtl.dispose();
      waCtl.dispose();
    }
  }

  Future<void> _setWhatsApp(Map m) async {
    final lang = ref.read(localeCodeProvider);
    final ctl = TextEditingController(text: '${m['whatsapp'] ?? ''}');
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'واتساب العمليات' : 'Ops WhatsApp',
        bodyBuilder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang == 'ar'
                  ? 'الرقم المصرّح له باستخدام مساعد واتساب للعمليات لهذا العضو. اتركيه فارغاً للإلغاء.'
                  : "The number allowed to run the WhatsApp ops helper as this staff member. Leave blank to revoke.",
              style: const TextStyle(fontSize: 12.5, color: Ops.mutedSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            V2FormField(
                label: lang == 'ar' ? 'الرقم' : 'Number',
                child: TextField(controller: ctl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '01XXXXXXXXX'))),
          ],
        ),
      );
      if (!ok) return;
      try {
        await staffClient.patch('/admin/staff/${idOf(m)}', data: {'whatsapp': ctl.text.trim()});
        if (mounted) {
          v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated');
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      ctl.dispose();
    }
  }

  Future<void> _toggle(Map m) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/staff/${idOf(m)}', data: {'disabled': staffEnabled(m)});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  List<Map<String, dynamic>> get _rows {
    if (q.isEmpty) return staff;
    final n = q.toLowerCase();
    return staff.where((m) => m.values.join(' ').toLowerCase().contains(n)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final sess = ref.watch(staffSessionProvider);
    if (!canSeeScreen(sess.effectiveRole, 'staff')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final isSuper = sess.staffRole == roleSuper;
    ref.listen(v2QueryProvider, (_, nx) => setState(() => q = nx.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا أعضاء' : 'Nothing here yet',
      actionsWidth: isSuper ? 190 : 8,
      trailingActions: [
        V2Btn.ghost(lang == 'ar' ? 'مصفوفة الأدوار' : 'Role matrix',
            onPressed: () => context.go(V2Paths.matrix), size: V2BtnSize.sm),
        if (isSuper) V2Btn.primary(lang == 'ar' ? '+ عضو' : '+ New Staff', onPressed: _create, size: V2BtnSize.sm),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'الاسم' : 'Name', flex: 1),
        V2Col(lang == 'ar' ? 'البريد' : 'Email', flex: 1.2),
        V2Col(lang == 'ar' ? 'الدور' : 'Role', fixed: 120),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 100),
        V2Col(lang == 'ar' ? 'مناطق' : 'AM areas', flex: 1),
      ],
      rows: [
        for (final m in _rows)
          V2GridRow(
            cells: [
              Text('${m['name'] ?? ''}'.isEmpty ? shortId(idOf(m)) : '${m['name']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${m['email'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.inkSoft)),
                  if ('${m['whatsapp'] ?? ''}'.isNotEmpty)
                    Text('WA ${m['whatsapp']}', style: const TextStyle(fontSize: 10.5, fontFamily: Ops.mono, color: Ops.mutedSoft)),
                ],
              ),
              Align(alignment: AlignmentDirectional.centerStart, child: V2StatusPill(label: roleLabel(staffRoleOf(m)), tone: V2Tone.plum)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill(
                    label: staffEnabled(m) ? 'Active' : 'Inactive', tone: staffEnabled(m) ? V2Tone.ok : V2Tone.bad),
              ),
              Text('${m['assignedAreas'] ?? m['amAreas'] ?? '—'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Ops.muted)),
            ],
            actions: [
              if (isSuper) ...[
                V2Btn(label: lang == 'ar' ? 'واتساب' : 'WhatsApp', onPressed: () => _setWhatsApp(m), size: V2BtnSize.row),
                V2Btn(
                    label: staffEnabled(m) ? (lang == 'ar' ? 'تعطيل' : 'Disable') : (lang == 'ar' ? 'تفعيل' : 'Enable'),
                    onPressed: () => _toggle(m),
                    size: V2BtnSize.row),
              ],
            ],
          ),
      ],
    );
  }
}
