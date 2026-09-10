import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/download_stub.dart'
    if (dart.library.html) 'package:oons/admin_v2/data/download_web.dart' as download;
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

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  List<Map<String, dynamic>> entries = [];
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
      final data = await staffClient.get('/admin/ledger');
      setState(() {
        entries = asMapList(data['ledgers'] ?? data['ledger'] ?? data['entries']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final bytes = await staffClient.getBytes('/admin/ledger/export.csv');
      download.downloadBytes(bytes, 'oons-ledger.csv');
      if (mounted) v2Toast(context, t(V2Copy.exportCsv, lang));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  List<Map<String, dynamic>> get _rows {
    if (q.isEmpty) return entries;
    final n = q.toLowerCase();
    return entries.where((e) => e.values.join(' ').toLowerCase().contains(n)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'ledger.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا أرصدة' : 'Nothing here yet',
      actionsWidth: 8,
      trailingActions: [
        V2Btn.ghost(t(V2Copy.exportCsv, lang), onPressed: _exportCsv, size: V2BtnSize.sm, icon: Icons.download),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المهنية' : 'Professional', flex: 1),
        V2Col(lang == 'ar' ? 'متاح' : 'Available', fixed: 130),
        V2Col(lang == 'ar' ? 'محجوز' : 'Held', fixed: 130),
        V2Col(lang == 'ar' ? 'مدى الحياة' : 'Lifetime', fixed: 140),
      ],
      rows: [
        for (final e in _rows)
          V2GridRow(
            cells: [
              Text(personName(e, lang, fallbackId: '${e['providerId'] ?? idOf(e)}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(money(asInt(e['available']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Text(money(asInt(e['held']), lang), style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Text(money(asInt(e['lifetime'] ?? e['lifetimeEarnings']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
            ],
          ),
      ],
    );
  }
}
