import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Queue of provider-added services awaiting staff activation. Unlike
/// provider-category requests, a decided item leaves this list entirely
/// (there's no persisted history row) — it's live in the provider's catalog
/// or gone, so there's no "Approved / Rejected" filter to keep here.
class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  ConsumerState<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends ConsumerState<ServiceRequestsScreen> {
  List<Map<String, dynamic>> requests = [];
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
      final data = await staffClient.get('/admin/service-requests');
      setState(() {
        requests = asMapList(data['requests']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _rows {
    if (q.isEmpty) return requests;
    final n = q.toLowerCase();
    return requests.where((r) => r.values.join(' ').toLowerCase().contains(n)).toList();
  }

  Future<void> _handle(Map r, String action) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post('/admin/service-requests/${r['providerId']}/${r['itemId']}/$action');
      if (mounted) {
        v2Toast(context, action == 'approve'
            ? (lang == 'ar' ? 'اتفعّلت الخدمة' : 'Service activated')
            : (lang == 'ar' ? 'اترفضت الخدمة' : 'Service rejected'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  String _detail(Map r, String lang) {
    final price = money(asInt(r['price']), lang);
    final isCleaning = '${r['kind']}' == 'cleaning';
    if (!isCleaning) {
      final mins = asInt(r['durationMin']);
      final dur = mins >= 60
          ? (lang == 'ar' ? '${(mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1)} س' : '${(mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1)}h')
          : (lang == 'ar' ? '$mins د' : '${mins}m');
      return '$price · $dur';
    }
    final from = asInt(r['sizeFromSqm']);
    final to = r['sizeToSqm'];
    final range = to == null ? (lang == 'ar' ? 'أكبر من $from م²' : '> $from m²') : (lang == 'ar' ? '$from–$to م²' : '$from–$to m²');
    final workers = asInt(r['workerCount']);
    final workersLabel = lang == 'ar' ? '$workers عاملة' : '$workers worker(s)';
    return '$price · $range · $workersLabel';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'serviceRequests')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'service_requests.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا خدمات قيد الموافقة' : 'Nothing awaiting activation',
      actionsWidth: canWrite ? 150 : 8,
      columns: [
        V2Col(lang == 'ar' ? 'الخدمة' : 'Service', flex: 1),
        V2Col(lang == 'ar' ? 'المهنية' : 'Provider', flex: 1),
        V2Col(lang == 'ar' ? 'التخصص' : 'Category', fixed: 130),
        V2Col(lang == 'ar' ? 'التفاصيل' : 'Details', flex: 1),
      ],
      rows: [
        for (final r in _rows)
          V2GridRow(
            cells: [
              Text(locName(r['name'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(personName(r['providerName'] ?? r, lang, fallbackId: '${r['providerId'] ?? ''}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(locName(r['categoryName'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(_detail(r, lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
            ],
            actions: [
              if (canWrite) ...[
                V2Btn(label: lang == 'ar' ? 'تفعيل' : 'Activate', onPressed: () => _handle(r, 'approve'), kind: V2BtnKind.primary, size: V2BtnSize.row),
                V2Btn(label: lang == 'ar' ? 'رفض' : 'Reject', onPressed: () => _handle(r, 'reject'), kind: V2BtnKind.danger, size: V2BtnSize.row),
              ],
            ],
          ),
      ],
    );
  }
}
