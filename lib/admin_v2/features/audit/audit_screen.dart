import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});
  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  List<Map<String, dynamic>> auditLogs = [];
  bool loading = true;
  String? error;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final q = <String, dynamic>{};
      if (query.isNotEmpty) q['q'] = query;
      final data = await staffClient.get('/admin/audit', query: q);
      setState(() { auditLogs = asMapList(data['logs']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'audit.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'سجل التدقيق' : 'Audit trail',
          lang: lang,
          resultCount: loading ? null : auditLogs.length,
          filters: TextField(
            onChanged: (v) { query = v; _load(); },
            decoration: InputDecoration(
              hintText: lang == 'ar' ? 'بحث...' : 'Search actor / action / entity...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Ops.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ops.radiusCtl)),
            ),
          ),
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : auditLogs.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الوقت' : 'Time',
                      lang == 'ar' ? 'الإجراء' : 'Action',
                      lang == 'ar' ? 'الفريق' : 'Staff',
                      lang == 'ar' ? 'الهدف' : 'Target',
                    ],
                    rows: [
                      for (final log in auditLogs)
                        [
                          Text(formatDay(log['at'] ?? log['createdAt'], lang), style: const TextStyle(fontSize: 11, color: Ops.muted, fontFamily: Ops.mono)),
                          V2StatusPill(label: '${log['action'] ?? ''}', tone: V2Tone.info),
                          Text('${log['actor'] ?? log['userName'] ?? ''}', style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono)),
                          Text('${log['entity'] ?? log['resourceType'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12)),
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
