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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class RefundsScreen extends ConsumerStatefulWidget {
  const RefundsScreen({super.key});

  @override
  ConsumerState<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends ConsumerState<RefundsScreen> {
  List<Map<String, dynamic>> refunds = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Open', 'Closed'];

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
      final data = await staffClient.get('/admin/refunds');
      setState(() {
        refunds = asMapList(data['refunds']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  bool _closed(Map r) {
    final s = '${r['status']}'.toLowerCase();
    return s == 'closed' || s == 'resolved';
  }

  int _count(String f) =>
      f == 'All' ? refunds.length : refunds.where((r) => f == 'Closed' ? _closed(r) : !_closed(r)).length;

  List<Map<String, dynamic>> get _rows {
    var list = refunds;
    if (filter != 'All') list = list.where((r) => filter == 'Closed' ? _closed(r) : !_closed(r)).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((r) => r.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _resolve(Map r) async {
    final lang = ref.read(localeCodeProvider);
    var note = '';
    var status = 'closed';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'حل المرتجع' : 'Resolve refund',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(label: lang == 'ar' ? 'ملاحظة (مطلوبة)' : 'Note (required)', child: TextField(onChanged: (v) => note = v, maxLines: 3)),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'الحالة' : 'Status',
            child: DropdownButtonFormField<String>(
              initialValue: status,
              items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'closed', child: Text('Closed'))],
              onChanged: (v) => status = v ?? 'closed',
            ),
          ),
        ],
      ),
      onValidate: () {
        if (note.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'الملاحظة مطلوبة' : 'A note is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/refunds/${idOf(r)}/resolve', data: {'note': note.trim(), 'status': status});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم حل المرتجع' : 'Refund resolved');
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
    if (!(staffCan(role, 'bookings.read') || canSeeScreen(role, 'refunds'))) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canWrite = staffCan(role, 'bookings.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا مرتجعات' : 'Nothing here yet',
      actionsWidth: canWrite ? 96 : 8,
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المرجع' : 'Ref', fixed: 140),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 128),
        V2Col(lang == 'ar' ? 'إجمالي العميلة' : 'Client total', fixed: 120),
        V2Col(lang == 'ar' ? 'مبلغ المرتجع' : 'Refund amount', fixed: 130),
        V2Col(lang == 'ar' ? 'آخر تحديث' : 'Updated', flex: 1),
      ],
      rows: [
        for (final r in _rows)
          V2GridRow(
            onTap: '${r['bookingId'] ?? idOf(r)}'.isNotEmpty
                ? () => context.go(V2Paths.booking('${r['bookingId'] ?? idOf(r)}'))
                : null,
            cells: [
              Text('${r['ref'] ?? '#${shortId(idOf(r))}'}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill(label: statusLabel('${r['status']}', lang), tone: statusTone('${r['status']}')),
              ),
              Text(money(asInt(r['total']), lang), style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Text(money(asInt(r['refundAmount']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Text(formatDay(r['updatedAt'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono)),
            ],
            actions: [
              if (canWrite && !_closed(r))
                V2Btn(label: lang == 'ar' ? 'حل' : 'Resolve', onPressed: () => _resolve(r), kind: V2BtnKind.primary, size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
