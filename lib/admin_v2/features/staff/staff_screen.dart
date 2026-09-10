import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/staff');
      setState(() { staff = asMapList(data['staff']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _createStaff() async {
    final lang = ref.read(localeCodeProvider);
    String? email, password, role = roleOps, name;
    String? formError;
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'إضافة فريق' : 'Add staff',
      confirmLabel: lang == 'ar' ? 'إضافة' : 'Add',
      bodyBuilder: (ctx, setLocal) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        V2FormField(label: lang == 'ar' ? 'الاسم' : 'Name', child: TextField(onChanged: (v) => name = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: lang == 'ar' ? 'البريد' : 'Email', child: TextField(onChanged: (v) => email = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(
          label: lang == 'ar' ? 'كلمة المرور (١٠ أحرف على الأقل)' : 'Password (min 10 characters)',
          child: TextField(
            obscureText: true,
            onChanged: (v) {
              password = v;
              setLocal(() {
                formError = (v.length < 10) ? (lang == 'ar' ? 'كلمة المرور يجب ألا تقل عن ١٠ أحرف' : 'Password must be at least 10 characters') : null;
              });
            },
            decoration: InputDecoration(border: const OutlineInputBorder(), errorText: formError),
          ),
        ),
        const SizedBox(height: 12),
        V2FormField(
          label: lang == 'ar' ? 'الدور' : 'Role',
          child: DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: roleOps, child: Text(roleLabel(roleOps))),
              DropdownMenuItem(value: roleFinance, child: Text(roleLabel(roleFinance))),
              DropdownMenuItem(value: roleVendor, child: Text(roleLabel(roleVendor))),
              DropdownMenuItem(value: roleAm, child: Text(roleLabel(roleAm))),
            ],
            onChanged: (v) => setLocal(() => role = v),
          ),
        ),
      ]),
    );
    if (!confirmed) return;
    if ((password ?? '').length < 10) {
      if (mounted) v2Toast(context, lang == 'ar' ? 'كلمة المرور يجب ألا تقل عن ١٠ أحرف' : 'Password must be at least 10 characters', error: true);
      return;
    }
    try {
      await staffClient.post('/admin/staff', data: {
        'email': email,
        'password': password,
        'staffRole': role,
        if ((name ?? '').isNotEmpty) 'name': name,
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تمت الإضافة' : 'Staff added'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _toggle(String id, bool disable) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/staff/$id', data: {'disabled': disable});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'staff')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'الفريق' : 'Staff',
          lang: lang,
          resultCount: loading ? null : staff.length,
          actions: [
            TextButton.icon(
              onPressed: () => context.go(V2Paths.matrix),
              icon: const Icon(Icons.table_chart, size: 16),
              label: Text(lang == 'ar' ? 'مصفوفة الصلاحيات' : 'Matrix'),
            ),
            if (staffState.staffRole == roleSuper)
              ElevatedButton.icon(onPressed: _createStaff, icon: const Icon(Icons.add, size: 16), label: Text(lang == 'ar' ? 'إضافة' : 'Add staff')),
          ],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : staff.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الاسم' : 'Name',
                      lang == 'ar' ? 'البريد' : 'Email',
                      lang == 'ar' ? 'دور الفريق' : 'Staff Role',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      if (staffState.staffRole == roleSuper) lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final m in staff)
                        [
                          Text('${m['name'] ?? ''}'.isEmpty ? shortId(idOf(m)) : '${m['name']}'),
                          Text('${m['email'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                          V2StatusPill(
                            label: roleLabel(staffRoleOf(m)),
                            tone: V2Tone.plum,
                          ),
                          V2StatusPill(
                            label: staffEnabled(m) ? (lang == 'ar' ? 'نشط' : 'Enabled') : (lang == 'ar' ? 'معطل' : 'Disabled'),
                            tone: staffEnabled(m) ? V2Tone.ok : V2Tone.bad,
                          ),
                          if (staffState.staffRole == roleSuper)
                            TextButton(
                              onPressed: () => _toggle(idOf(m), staffEnabled(m)),
                              child: Text(staffEnabled(m) ? (lang == 'ar' ? 'تعطيل' : 'Disable') : (lang == 'ar' ? 'تفعيل' : 'Enable')),
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
