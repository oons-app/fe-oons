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
import 'package:oons/data/api.dart';

class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});

  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {
  List<Map<String, dynamic>> claims = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _filters = ['All', 'Open', 'Escalated', 'Closed'];

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
      final data = await staffClient.get('/admin/claims');
      setState(() {
        claims = asMapList(data['claims']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  bool _isClosed(Map c) {
    final s = '${c['status']}'.toLowerCase();
    return s == 'resolved' || s == 'closed' || s == 'rejected';
  }

  int _count(String f) {
    if (f == 'All') return claims.length;
    return claims.where((c) {
      final s = '${c['status']}'.toLowerCase();
      if (f == 'Closed') return _isClosed(c);
      return s == f.toLowerCase();
    }).length;
  }

  List<Map<String, dynamic>> get _rows {
    var list = claims;
    if (filter != 'All') {
      list = list.where((c) {
        if (filter == 'Closed') return _isClosed(c);
        return '${c['status']}'.toLowerCase() == filter.toLowerCase();
      }).toList();
    }
    if (q.isNotEmpty) {
      final needle = q.toLowerCase();
      list = list.where((c) => c.values.join(' ').toLowerCase().contains(needle)).toList();
    }
    return list;
  }

  Future<void> _resolve(Map c) async {
    final lang = ref.read(localeCodeProvider);
    var note = '';
    final ok = await v2Form(
      context,
      title: '${lang == 'ar' ? 'إغلاق المطالبة' : 'Close claim'} #${shortId(idOf(c))}',
      confirmLabel: lang == 'ar' ? 'إغلاق المطالبة' : 'Close claim',
      bodyBuilder: (ctx, _) => V2FormField(
        label: lang == 'ar' ? 'ملاحظة الحل (مطلوبة)' : 'Resolution note (required)',
        child: TextField(onChanged: (v) => note = v, maxLines: 3),
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
      await staffClient.post('/admin/claims/${idOf(c)}/resolve', data: {'status': 'resolved', 'note': note.trim()});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم إغلاق المطالبة' : 'Claim closed');
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
    if (!staffCan(role, 'claims.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canWrite = staffCan(role, 'claims.write');
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا مطالبات' : 'Nothing here yet',
      actionsWidth: canWrite ? 96 : 8,
      filters: [
        for (final f in _filters)
          V2FilterChip(
            label: f,
            count: _count(f),
            selected: filter == f,
            onTap: () => setState(() => filter = f),
          ),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المطالبة' : 'Claim', fixed: 118),
        V2Col(lang == 'ar' ? 'الحجز' : 'Booking', fixed: 130),
        V2Col(lang == 'ar' ? 'العميلة' : 'Customer', flex: 1),
        V2Col(lang == 'ar' ? 'المالك' : 'Owner', flex: 0.9),
        V2Col(lang == 'ar' ? 'فُتحت' : 'Opened', fixed: 108),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 118),
      ],
      rows: [
        for (final c in _rows)
          V2GridRow(
            cells: [
              Text('#${shortId(idOf(c))}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () {
                  final bid = '${c['bookingId'] ?? ''}';
                  if (bid.isNotEmpty) context.go(V2Paths.booking(bid));
                },
                child: Text('#${shortId('${c['bookingId'] ?? ''}')}',
                    style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.plum)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${c['customer'] ?? c['customerName'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  Text('${c['kind'] ?? c['type'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Ops.mutedSoft)),
                ],
              ),
              Text('${c['owner'] ?? c['resolvedByAdminId'] ?? '—'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(formatDayOnly(c['createdAt']), style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill(label: statusLabel('${c['status']}', lang), tone: statusTone('${c['status']}')),
              ),
            ],
            actions: [
              if (canWrite && !_isClosed(c))
                V2Btn(label: lang == 'ar' ? 'حل' : 'Resolve', onPressed: () => _resolve(c), kind: V2BtnKind.primary, size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
