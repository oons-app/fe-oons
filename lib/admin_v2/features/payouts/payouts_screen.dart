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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  List<Map<String, dynamic>> payouts = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Pending', 'Held', 'Paid'];

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
      final data = await staffClient.get('/admin/payouts');
      setState(() {
        payouts = asMapList(data['payouts']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  String _status(Map p) {
    final s = '${p['status'] ?? 'pending'}'.toLowerCase();
    if (s == 'held') return 'Held';
    if (s == 'paid' || s == 'released') return 'Paid';
    return 'Pending';
  }

  int _count(String f) => f == 'All' ? payouts.length : payouts.where((p) => _status(p) == f).length;

  List<Map<String, dynamic>> get _rows {
    var list = payouts;
    if (filter != 'All') list = list.where((p) => _status(p) == filter).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((p) => p.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _act(Map p, String action, String verb) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: action == 'release'
          ? (lang == 'ar' ? 'تحرير السحب؟' : 'Release payout?')
          : (lang == 'ar' ? 'تجميد السحب؟' : 'Hold payout?'),
      body: '${money(asInt(p['amount']), lang)} → ${personName(p['providerName'] ?? p, lang, fallbackId: '${p['providerId'] ?? ''}')} · ${p['method'] ?? ''}',
      confirmLabel: verb,
      danger: action == 'hold',
      roleLabel: roleLabel(ref.read(staffSessionProvider).effectiveRole),
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/payouts/${idOf(p)}/$action');
      if (mounted) {
        v2Toast(context, action == 'release'
            ? (lang == 'ar' ? 'تم التحرير' : 'Payout released')
            : (lang == 'ar' ? 'تم التجميد' : 'Payout held'));
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
    if (!staffCan(role, 'payouts.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'payouts.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا سحوبات' : 'Nothing here yet',
      actionsWidth: canWrite ? 150 : 8,
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'السحب' : 'Payout', fixed: 110),
        V2Col(lang == 'ar' ? 'المهنية' : 'Professional', flex: 1),
        V2Col(lang == 'ar' ? 'الطريقة' : 'Method', fixed: 100),
        V2Col(lang == 'ar' ? 'الحساب' : 'Account', fixed: 130),
        V2Col(lang == 'ar' ? 'المبلغ' : 'Amount', fixed: 108),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 100),
      ],
      rows: [
        for (final p in _rows)
          V2GridRow(
            cells: [
              Text('#${shortId(idOf(p))}',
                  style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
              Text(personName(p['providerName'] ?? p, lang, fallbackId: '${p['providerId'] ?? ''}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${p['method'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text('${p['account'] ?? p['payoutHandle'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono)),
              Text(money(asInt(p['amount']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Align(alignment: AlignmentDirectional.centerStart, child: V2StatusPill.forLabel(_status(p))),
            ],
            actions: [
              if (canWrite && _status(p) != 'Paid')
                V2Btn(label: lang == 'ar' ? 'تحرير' : 'Release', onPressed: () => _act(p, 'release', lang == 'ar' ? 'تحرير' : 'Release'), kind: V2BtnKind.primary, size: V2BtnSize.row),
              if (canWrite && _status(p) == 'Pending')
                V2Btn(label: lang == 'ar' ? 'تجميد' : 'Hold', onPressed: () => _act(p, 'hold', lang == 'ar' ? 'تجميد' : 'Hold'), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
