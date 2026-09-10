import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

class CategoryRequestsScreen extends ConsumerStatefulWidget {
  const CategoryRequestsScreen({super.key});

  @override
  ConsumerState<CategoryRequestsScreen> createState() => _CategoryRequestsScreenState();
}

class _CategoryRequestsScreenState extends ConsumerState<CategoryRequestsScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/provider-categories');
      setState(() {
        requests = asMapList(data['requests'] ?? data['providerCategories']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _handle(String id, String action) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post('/admin/provider-categories/$id/$action');
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التنفيذ' : 'Done'); _loadRequests(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'categoryRequests')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(title: lang == 'ar' ? 'طلبات التخصص' : 'Category requests', lang: lang, resultCount: loading ? null : requests.length),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _loadRequests))
            : requests.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'المهنية' : 'Provider',
                      lang == 'ar' ? 'الفئة' : 'Category',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      lang == 'ar' ? 'التاريخ' : 'Date',
                      lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final r in requests)
                        [
                          Text(personName(r['providerName'] ?? r, lang, fallbackId: '${r['providerId'] ?? ''}')),
                          Text(locName(r['categoryName'], lang)),
                          V2StatusPill(label: statusLabel('${r['status']}', lang), tone: statusTone('${r['status']}')),
                          Text(formatDay(r['requestedAt'] ?? r['createdAt'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(onPressed: () => _handle(idOf(r), 'approve'), child: Text(lang == 'ar' ? 'موافقة' : 'Approve')),
                            TextButton(onPressed: () => _handle(idOf(r), 'reject'), child: Text(lang == 'ar' ? 'رفض' : 'Reject')),
                          ]),
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
