import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/corporate');
      setState(() { accounts = asMapList(data['accounts'] ?? data['corporate']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _upsert({Map<String, dynamic>? account}) async {
    final lang = ref.read(localeCodeProvider);
    final editing = account != null;
    String legalName = '${account?['legalName'] ?? account?['name'] ?? ''}';
    String taxId = '${account?['taxId'] ?? ''}';
    String billingEmail = '${account?['billingEmail'] ?? account?['contact'] ?? ''}';
    final confirmed = await v2Form(
      context,
      title: editing
          ? (lang == 'ar' ? 'تعديل حساب الشركة' : 'Edit corporate account')
          : (lang == 'ar' ? 'إنشاء حساب شركة' : 'Create corporate account'),
      confirmLabel: editing ? (lang == 'ar' ? 'حفظ' : 'Save') : (lang == 'ar' ? 'إنشاء' : 'Create'),
      bodyBuilder: (ctx, setLocal) => Column(children: [
        V2FormField(
          label: lang == 'ar' ? 'الاسم القانوني' : 'Legal name',
          child: TextField(
            controller: TextEditingController(text: legalName),
            onChanged: (v) => legalName = v,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
        V2FormField(
          label: lang == 'ar' ? 'الرقم الضريبي' : 'Tax ID',
          child: TextField(
            controller: TextEditingController(text: taxId),
            onChanged: (v) => taxId = v,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
        V2FormField(
          label: lang == 'ar' ? 'بريد الفواتير' : 'Billing email',
          child: TextField(
            controller: TextEditingController(text: billingEmail),
            onChanged: (v) => billingEmail = v,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
      ]),
      onValidate: () => legalName.trim().isNotEmpty,
    );
    if (!confirmed) return;
    try {
      await staffClient.post('/admin/corporate', data: {
        if (account != null && idOf(account).isNotEmpty) 'id': idOf(account),
        'legalName': legalName.trim(),
        'taxId': taxId.trim(),
        'billingEmail': billingEmail.trim(),
      });
      if (mounted) {
        v2Toast(context, editing ? (lang == 'ar' ? 'تم التحديث' : 'Updated') : (lang == 'ar' ? 'تم الإنشاء' : 'Created'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);

    if (!canSeeScreen(staffState.effectiveRole, 'corporate')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    final canWrite = staffCan(staffState.effectiveRole, 'staff.write');
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'الشركات' : 'Corporate',
          lang: lang,
          resultCount: loading ? null : accounts.length,
          actions: [
            if (canWrite)
              ElevatedButton.icon(
                onPressed: () => _upsert(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(lang == 'ar' ? 'إنشاء' : 'Create'),
              ),
          ],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : accounts.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الاسم القانوني' : 'Legal name',
                      lang == 'ar' ? 'بريد الفواتير' : 'Billing email',
                      lang == 'ar' ? 'الرقم الضريبي' : 'Tax ID',
                      if (canWrite) lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final account in accounts)
                        [
                          Text('${account['legalName'] ?? account['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${account['billingEmail'] ?? account['contact'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          Text('${account['taxId'] ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: Ops.mono)),
                          if (canWrite)
                            TextButton(
                              onPressed: () => _upsert(account: account),
                              child: Text(lang == 'ar' ? 'تعديل' : 'Edit'),
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
