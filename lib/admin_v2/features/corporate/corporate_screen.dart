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
import 'package:oons/data/api.dart';

class CorporateScreen extends ConsumerStatefulWidget {
  const CorporateScreen({super.key});

  @override
  ConsumerState<CorporateScreen> createState() => _CorporateScreenState();
}

class _CorporateScreenState extends ConsumerState<CorporateScreen> {
  List<Map<String, dynamic>> accounts = [];
  bool loading = true;
  String? error;
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && staffCan(ref.read(staffSessionProvider).effectiveRole, 'staff.write')) {
        ref.read(v2HeaderConfigProvider.notifier).state =
            V2HeaderConfig(newLabel: 'Corporate account', onNewRecord: () => _upsert(null));
      }
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/corporate');
      setState(() {
        accounts = asMapList(data['accounts'] ?? data['corporate']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _upsert(Map? a) async {
    final lang = ref.read(localeCodeProvider);
    final name = TextEditingController(text: '${a?['legalName'] ?? a?['name'] ?? ''}');
    final tax = TextEditingController(text: '${a?['taxId'] ?? ''}');
    final email = TextEditingController(text: '${a?['billingEmail'] ?? a?['contact'] ?? ''}');
    final seats = TextEditingController(text: '${a?['seats'] ?? ''}');
    final ok = await v2Form(
      context,
      title: a == null
          ? (lang == 'ar' ? 'حساب شركة جديد' : 'New corporate account')
          : (lang == 'ar' ? 'تعديل حساب الشركة' : 'Edit corporate account'),
      bodyBuilder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(label: lang == 'ar' ? 'الاسم القانوني' : 'Company', child: TextField(controller: name)),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'بريد الفواتير' : 'Billing contact', child: TextField(controller: email)),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'الرقم الضريبي' : 'Tax ID', child: TextField(controller: tax)),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'المقاعد' : 'Seats', child: TextField(controller: seats, keyboardType: TextInputType.number)),
        ],
      ),
      onValidate: () {
        if (name.text.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'الاسم مطلوب' : 'Company name is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/corporate', data: {
        if (a != null && idOf(a).isNotEmpty) 'id': idOf(a),
        'legalName': name.text.trim(),
        'taxId': tax.text.trim(),
        'billingEmail': email.text.trim(),
        if (seats.text.trim().isNotEmpty) 'seats': int.tryParse(seats.text.trim()),
      });
      if (mounted) {
        v2Toast(context, a == null ? (lang == 'ar' ? 'تم الإنشاء' : 'Account created') : (lang == 'ar' ? 'تم التحديث' : 'Account updated'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  List<Map<String, dynamic>> get _rows {
    if (q.isEmpty) return accounts;
    final n = q.toLowerCase();
    return accounts.where((a) => a.values.join(' ').toLowerCase().contains(n)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'corporate')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'staff.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا حسابات شركات' : 'Nothing here yet',
      actionsWidth: canWrite ? 90 : 8,
      trailingActions: [
        if (canWrite) V2Btn.primary(lang == 'ar' ? '+ حساب' : '+ New Account', onPressed: () => _upsert(null), size: V2BtnSize.sm),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'الشركة' : 'Company', flex: 1),
        V2Col(lang == 'ar' ? 'جهة الاتصال' : 'Contact', flex: 1),
        V2Col(lang == 'ar' ? 'المقاعد' : 'Seats', fixed: 90),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 110),
      ],
      rows: [
        for (final a in _rows)
          V2GridRow(
            cells: [
              Text('${a['legalName'] ?? a['name'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${a['billingEmail'] ?? a['contact'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.inkSoft)),
              Text('${a['seats'] ?? '—'}', style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill.forLabel(a['active'] == false ? 'Inactive' : 'Active'),
              ),
            ],
            actions: [
              if (canWrite) V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _upsert(a), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
