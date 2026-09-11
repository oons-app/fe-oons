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

class CategoryRequestsScreen extends ConsumerStatefulWidget {
  const CategoryRequestsScreen({super.key});

  @override
  ConsumerState<CategoryRequestsScreen> createState() => _CategoryRequestsScreenState();
}

class _CategoryRequestsScreenState extends ConsumerState<CategoryRequestsScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Requested', 'Approved', 'Rejected'];

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
      final results = await Future.wait([
        staffClient.get('/admin/provider-categories'),
        // A request bundled with real services (proAddCategoryWithServices)
        // is reviewed on the Service requests screen instead, as one
        // category-plus-services unit — exclude those bare rows here so a
        // bundle isn't decided in two different, inconsistent places.
        staffClient.get('/admin/service-requests').catchError((_) => <String, dynamic>{}),
      ]);
      final bundled = asMapList(results[1]['requests'])
          .map((it) => '${it['providerId']}/${it['categoryId']}')
          .toSet();
      final all = asMapList(results[0]['requests'] ?? results[0]['providerCategories']);
      setState(() {
        requests = all.where((r) => !bundled.contains('${r['providerId']}/${r['categoryId']}')).toList();
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  String _status(Map r) {
    final s = '${r['status']}'.toLowerCase();
    if (s.contains('approv')) return 'Approved';
    if (s.contains('reject')) return 'Rejected';
    return 'Requested';
  }

  int _count(String f) => f == 'All' ? requests.length : requests.where((r) => _status(r) == f).length;

  List<Map<String, dynamic>> get _rows {
    var list = requests;
    if (filter != 'All') list = list.where((r) => _status(r) == filter).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((r) => r.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _handle(Map r, String action) async {
    final lang = ref.read(localeCodeProvider);
    var note = '';
    if (action == 'reject') {
      // The backend now requires a note on reject — collect it here instead
      // of firing a silent reject with nothing for the provider to act on.
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'رفض الطلب' : 'Reject request',
        confirmLabel: lang == 'ar' ? 'رفض' : 'Reject',
        danger: true,
        bodyBuilder: (ctx, _) => V2FormField(
          label: lang == 'ar' ? 'السبب (هتشوفه المهنية)' : 'Reason (the provider will see this)',
          child: TextField(onChanged: (v) => note = v, maxLines: 2, autofocus: true),
        ),
        onValidate: () {
          if (note.trim().isEmpty) {
            v2Toast(context, lang == 'ar' ? 'لازم تكتبي السبب' : 'A reason is required', error: true);
            return false;
          }
          return true;
        },
      );
      if (!ok) return;
    }
    try {
      await staffClient.post('/admin/provider-categories/${idOf(r)}/$action',
          data: {if (note.trim().isNotEmpty) 'note': note.trim()});
      if (mounted) {
        v2Toast(context, action == 'approve'
            ? (lang == 'ar' ? 'تمت الموافقة' : 'Approved')
            : (lang == 'ar' ? 'تم الرفض' : 'Rejected'));
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'categoryRequests')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'provider_categories.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا طلبات' : 'Nothing here yet',
      actionsWidth: canWrite ? 150 : 8,
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'الخدمة المطلوبة' : 'Requested service', flex: 1),
        V2Col(lang == 'ar' ? 'المهنية' : 'Requested by', flex: 1),
        V2Col(lang == 'ar' ? 'المجال' : 'Vertical', fixed: 120),
        V2Col(lang == 'ar' ? 'التاريخ' : 'Date', fixed: 108),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 118),
      ],
      rows: [
        for (final r in _rows)
          V2GridRow(
            cells: [
              Text(locName(r['categoryName'] ?? r['name'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(personName(r['providerName'] ?? r, lang, fallbackId: '${r['providerId'] ?? ''}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text('${r['vertical'] ?? r['category'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(formatDayOnly(r['requestedAt'] ?? r['createdAt']),
                  style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill.forLabel(_status(r)),
              ),
            ],
            actions: [
              if (canWrite && _status(r) == 'Requested') ...[
                V2Btn(label: lang == 'ar' ? 'موافقة' : 'Approve', onPressed: () => _handle(r, 'approve'), kind: V2BtnKind.primary, size: V2BtnSize.row),
                V2Btn(label: lang == 'ar' ? 'رفض' : 'Reject', onPressed: () => _handle(r, 'reject'), kind: V2BtnKind.danger, size: V2BtnSize.row),
              ],
            ],
          ),
      ],
    );
  }
}
