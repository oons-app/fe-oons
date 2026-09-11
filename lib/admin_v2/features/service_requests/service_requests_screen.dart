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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

/// Queue of specialty requests bundled with their real configured service(s)
/// (proAddCategoryWithServices) — grouped by (provider, category) so staff
/// review the actual final output as one unit: Approve activates the
/// category and every item together, Reject or Request changes flips both
/// with a note the provider actually sees (unlike the old per-item decide,
/// which dropped the note after the audit log).
class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  ConsumerState<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _Bundle {
  _Bundle({required this.providerId, required this.categoryId});
  final String providerId;
  final String categoryId;
  final List<Map<String, dynamic>> items = [];

  Map get first => items.first;
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

  List<_Bundle> get _bundles {
    final byKey = <String, _Bundle>{};
    for (final r in requests) {
      final key = '${r['providerId']}/${r['categoryId']}';
      final b = byKey.putIfAbsent(key, () => _Bundle(providerId: '${r['providerId']}', categoryId: '${r['categoryId']}'));
      b.items.add(r);
    }
    var list = byKey.values.toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((b) => b.items.any((r) => r.values.join(' ').toLowerCase().contains(n))).toList();
    }
    return list;
  }

  Future<void> _decide(_Bundle b, String status) async {
    final lang = ref.read(localeCodeProvider);
    var note = '';
    if (status != 'approve') {
      final ok = await v2Form(
        context,
        title: status == 'reject'
            ? (lang == 'ar' ? 'رفض الطلب' : 'Reject request')
            : (lang == 'ar' ? 'اطلبي تعديل' : 'Request changes'),
        confirmLabel: status == 'reject' ? (lang == 'ar' ? 'رفض' : 'Reject') : (lang == 'ar' ? 'ابعتي' : 'Send'),
        danger: status == 'reject',
        bodyBuilder: (ctx, _) => V2FormField(
          label: lang == 'ar' ? 'السبب (هتشوفه المهنية)' : 'Reason (the provider will see this)',
          child: TextField(onChanged: (v) => note = v, maxLines: 3, autofocus: true),
        ),
      );
      if (!ok) return;
    }
    try {
      await staffClient.post(
        '/admin/service-requests/${b.providerId}/${b.categoryId}/decide',
        data: {'status': status, if (note.trim().isNotEmpty) 'note': note.trim()},
      );
      if (mounted) {
        v2Toast(
          context,
          status == 'approve'
              ? (lang == 'ar' ? 'اتفعّل التخصص والخدمات' : 'Specialty and services activated')
              : status == 'reject'
                  ? (lang == 'ar' ? 'اترفض الطلب' : 'Request rejected')
                  : (lang == 'ar' ? 'اتبعت طلب التعديل' : 'Changes requested'),
        );
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

    final bundles = _bundles;

    return ColoredBox(
      color: Ops.page,
      child: loading
          ? const Center(child: V2Loading())
          : error != null
              ? V2ErrorBanner(message: error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
                  children: [
                    Text('${bundles.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
                        style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
                    const SizedBox(height: 12),
                    if (bundles.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 38),
                        decoration: BoxDecoration(
                          color: Ops.card,
                          borderRadius: BorderRadius.circular(Ops.radiusCard),
                          border: Border.all(color: Ops.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(lang == 'ar' ? 'لا طلبات قيد الموافقة' : 'Nothing awaiting a decision',
                            style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      )
                    else
                      for (final b in bundles) ...[
                        _bundleCard(b, lang, canWrite),
                        const SizedBox(height: 14),
                      ],
                  ],
                ),
    );
  }

  Widget _bundleCard(_Bundle b, String lang, bool canWrite) {
    final first = b.first;
    final categoryStatus = '${first['categoryStatus'] ?? ''}';
    final categoryNote = '${first['categoryDecisionNote'] ?? ''}'.trim();
    final anyChangesRequested = b.items.any((r) => '${r['approvalState']}' == 'changes_requested');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(locName(first['categoryName'], lang),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (categoryStatus.isNotEmpty) V2StatusPill.forLabel(anyChangesRequested ? 'Changes requested' : categoryStatus),
            ],
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => context.go(V2Paths.provider(b.providerId)),
            child: Text(
              personName(first['providerName'] ?? first, lang, fallbackId: b.providerId),
              style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft, decoration: TextDecoration.underline),
            ),
          ),
          if (categoryNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Ops.impBg, borderRadius: BorderRadius.circular(10)),
              child: Text(categoryNote, style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          for (final r in b.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(locName(r['name'], lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Text(_detail(r, lang), style: const TextStyle(fontSize: 12, fontFamily: Ops.mono, color: Ops.muted)),
                ],
              ),
            ),
          if (canWrite) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                V2Btn(label: lang == 'ar' ? 'موافقة' : 'Approve', onPressed: () => _decide(b, 'approve'), kind: V2BtnKind.primary, size: V2BtnSize.row),
                const SizedBox(width: 6),
                V2Btn.ghost(lang == 'ar' ? 'اطلبي تعديل' : 'Request changes', onPressed: () => _decide(b, 'changes_requested'), size: V2BtnSize.row),
                const SizedBox(width: 6),
                V2Btn(label: lang == 'ar' ? 'رفض' : 'Reject', onPressed: () => _decide(b, 'reject'), kind: V2BtnKind.danger, size: V2BtnSize.row),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
