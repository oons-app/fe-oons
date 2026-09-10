import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class BatchesScreen extends ConsumerStatefulWidget {
  const BatchesScreen({super.key});
  @override
  ConsumerState<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends ConsumerState<BatchesScreen> {
  List<Map<String, dynamic>> batches = [];
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
      final data = await staffClient.get('/admin/ops-batches');
      setState(() { batches = asMapList(data['batches']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) v2Toast(context, 'Could not open link', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!canSeeScreen(staffState.effectiveRole, 'batches')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(title: lang == 'ar' ? 'سجل الدفعات' : 'Batch history', lang: lang, resultCount: loading ? null : batches.length),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : batches.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الدفعة' : 'Batch',
                      lang == 'ar' ? 'المهنية' : 'Provider',
                      lang == 'ar' ? 'الزيارات' : 'Visits',
                      lang == 'ar' ? 'الإجمالي' : 'Gross',
                      lang == 'ar' ? 'الصافي' : 'Net',
                      lang == 'ar' ? 'التاريخ' : 'Settled',
                      lang == 'ar' ? 'الملفات' : 'Files',
                    ],
                    rows: [
                      for (final b in batches)
                        [
                          identityCell(shortId(idOf(b)), '${b['paidBy'] ?? ''}'),
                          Text(personName(b['providerName'] ?? b, lang, fallbackId: '${b['providerId'] ?? ''}')),
                          Text('${asInt(b['visitCount'] ?? b['itemCount'])}', style: const TextStyle(fontFamily: Ops.mono)),
                          Text(money(asInt(b['gross'] ?? b['totalAmount']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                          Text(money(asInt(b['providerNet'] ?? b['net']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                          Text(formatDay(b['paidAt'] ?? b['createdAt'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if ('${b['receiptUrl'] ?? ''}'.isNotEmpty)
                              TextButton(onPressed: () => _open('${b['receiptUrl']}'), child: Text(lang == 'ar' ? 'إيصال' : 'Receipt')),
                            if ('${b['excelUrl'] ?? ''}'.isNotEmpty)
                              TextButton(onPressed: () => _open('${b['excelUrl']}'), child: const Text('Excel')),
                            if ('${b['publicPayUrl'] ?? b['link'] ?? ''}'.isNotEmpty)
                              TextButton(onPressed: () => _open('${b['publicPayUrl'] ?? b['link']}'), child: Text(lang == 'ar' ? 'رابط' : 'Link')),
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
