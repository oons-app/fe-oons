import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';
import 'package:oons/admin_v2/ui/list_view.dart';
import 'package:oons/data/api.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  List<Map<String, dynamic>> logs = [];
  bool loading = true;
  String? error;
  String q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/audit', query: {if (q.isNotEmpty) 'q': q});
      setState(() {
        logs = asMapList(data['logs']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'audit.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    ref.listen(v2QueryProvider, (_, next) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        q = next.trim();
        _load();
      });
    });

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${logs.length} ${lang == 'ar' ? 'إدخال' : 'entries'}',
      emptyText: lang == 'ar' ? 'لا سجلات' : 'Nothing here yet',
      actionsWidth: 8,
      columns: [
        V2Col(lang == 'ar' ? 'الوقت' : 'Time', fixed: 150),
        V2Col(lang == 'ar' ? 'الإجراء' : 'Action', flex: 1.2),
        V2Col(lang == 'ar' ? 'الفريق' : 'Staff', flex: 1),
        V2Col(lang == 'ar' ? 'الهدف' : 'Target', flex: 1),
      ],
      rows: [
        for (final l in logs)
          V2GridRow(
            cells: [
              Text(formatDay(l['at'] ?? l['createdAt'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono, color: Ops.muted)),
              Text('${l['action'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${l['actor'] ?? l['userName'] ?? l['staff'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono, color: Ops.muted)),
              Text('${l['target'] ?? l['entity'] ?? l['resourceType'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono)),
            ],
          ),
      ],
    );
  }
}
