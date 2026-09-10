import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String q = '';

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
      final data = await staffClient.get('/admin/ops-batches');
      setState(() {
        batches = asMapList(data['batches']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
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

  List<Map<String, dynamic>> get _rows {
    if (q.isEmpty) return batches;
    final n = q.toLowerCase();
    return batches.where((b) => b.values.join(' ').toLowerCase().contains(n)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'batches')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا دفعات' : 'Nothing here yet',
      actionsWidth: 210,
      columns: [
        V2Col(lang == 'ar' ? 'الدفعة' : 'Batch', fixed: 120),
        V2Col(lang == 'ar' ? 'المهنية' : 'Professional', flex: 1),
        V2Col(lang == 'ar' ? 'الزيارات' : 'Visits', fixed: 80),
        V2Col(lang == 'ar' ? 'صافي المهنية' : 'Provider gross', fixed: 130),
        V2Col(lang == 'ar' ? 'سُوّيت' : 'Settled', fixed: 132),
      ],
      rows: [
        for (final b in _rows)
          V2GridRow(
            cells: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('#${shortId(idOf(b))}',
                      style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                  if ('${b['paidBy'] ?? ''}'.isNotEmpty)
                    Text('${b['paidBy']}', style: const TextStyle(fontSize: 11, color: Ops.mutedSoft)),
                ],
              ),
              Text(personName(b['providerName'] ?? b, lang, fallbackId: '${b['providerId'] ?? ''}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${asInt(b['visitCount'] ?? b['itemCount'])}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Text(money(asInt(b['providerNet'] ?? b['net'] ?? b['gross'] ?? b['totalAmount']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Text(formatDayOnly(b['paidAt'] ?? b['createdAt']),
                  style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
            ],
            actions: [
              if ('${b['receiptUrl'] ?? ''}'.isNotEmpty)
                V2Btn(label: lang == 'ar' ? 'إيصال' : 'Receipt', onPressed: () => _open('${b['receiptUrl']}'), size: V2BtnSize.row),
              if ('${b['excelUrl'] ?? ''}'.isNotEmpty)
                V2Btn(label: 'Excel', onPressed: () => _open('${b['excelUrl']}'), size: V2BtnSize.row),
              if ('${b['publicPayUrl'] ?? b['link'] ?? ''}'.isNotEmpty)
                V2Btn(label: lang == 'ar' ? 'رابط' : 'Link', onPressed: () => _open('${b['publicPayUrl'] ?? b['link']}'), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
