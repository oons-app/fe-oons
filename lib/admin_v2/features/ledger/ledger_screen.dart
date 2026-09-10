import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/download_stub.dart' if (dart.library.html) 'package:oons/admin_v2/data/download_web.dart' as download;
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/ledger');
      setState(() {
        entries = asMapList(data['ledgers'] ?? data['ledger'] ?? data['entries']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _exportCsv() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final bytes = await staffClient.getBytes('/admin/ledger/export.csv');
      download.downloadBytes(bytes, 'ledger.csv');
      if (mounted) v2Toast(context, t(V2Copy.saved, lang));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'ledger.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'الأرصدة' : 'Ledger',
          lang: lang,
          resultCount: loading ? null : entries.length,
          actions: [ElevatedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.download, size: 16), label: Text(t(V2Copy.exportCsv, lang)))],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : entries.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'المهنية' : 'Professional',
                      lang == 'ar' ? 'الهاتف' : 'Phone',
                      lang == 'ar' ? 'متاح' : 'Available',
                      lang == 'ar' ? 'محتجز' : 'Held',
                      lang == 'ar' ? 'الخدمة' : 'Service',
                    ],
                    rows: [
                      for (final e in entries)
                        [
                          identityCell(personName(e, lang, fallbackId: '${e['providerId'] ?? ''}'), shortId('${e['providerId'] ?? idOf(e)}')),
                          Text('${e['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
                          Text(money(asInt(e['available']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                          Text(money(asInt(e['held']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                          Text(locName(e['service'], lang)),
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
