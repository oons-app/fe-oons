import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Newest registrations first. Empty values always sink to the bottom.
@visibleForTesting
int compareCustomerRows(Map<String, dynamic> a, Map<String, dynamic> b, String key, bool asc, String lang) {
  Object? va;
  Object? vb;
  switch (key) {
    case 'name':
      va = personName(a, lang, fallbackId: idOf(a)).toLowerCase();
      vb = personName(b, lang, fallbackId: idOf(b)).toLowerCase();
      break;
    case 'phone':
      va = '${a['phone'] ?? ''}';
      vb = '${b['phone'] ?? ''}';
      break;
    case 'area':
      va = areaLabel(a['area'] ?? a['areaName'], lang).toLowerCase();
      vb = areaLabel(b['area'] ?? b['areaName'], lang).toLowerCase();
      break;
    case 'bookingCount':
      va = asInt(a['bookingCount']);
      vb = asInt(b['bookingCount']);
      break;
    case 'lastVisit':
      va = parseTime(a['lastSlot']) ?? '${a['lastStatus'] ?? ''}';
      vb = parseTime(b['lastSlot']) ?? '${b['lastStatus'] ?? ''}';
      break;
    default:
      va = parseTime(a['createdAt']);
      vb = parseTime(b['createdAt']);
  }
  final ae = _sortEmpty(va);
  final be = _sortEmpty(vb);
  if (ae && be) return 0;
  if (ae) return 1;
  if (be) return -1;
  final cmp = _sortCompare(va, vb);
  return asc ? cmp : -cmp;
}

bool _sortEmpty(Object? v) {
  if (v == null) return true;
  if (v is String) return v.trim().isEmpty;
  return false;
}

int _sortCompare(Object? a, Object? b) {
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  if (a is num && b is num) return a.compareTo(b);
  return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Map<String, dynamic>> customers = [];
  bool loading = true;
  String? error;
  String q = '';
  String visits = ''; // '', any, none, live, done, dispute
  bool advanced = false;
  String sortKey = 'createdAt';
  bool sortAsc = false;
  Timer? _debounce;

  static const _visitFilters = [
    ('any', 'Has visits'),
    ('none', 'No visits'),
    ('live', 'Live'),
    ('done', 'Done'),
    ('dispute', 'Dispute'),
  ];

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
      final query = <String, dynamic>{'limit': 100};
      if (q.isNotEmpty) query['q'] = q;
      if (visits.isNotEmpty) query['visits'] = visits;
      final data = await staffClient.get('/admin/users', query: query);
      setState(() {
        customers = asMapList(data['users'] ?? data['customers']);
        _applySort(lang: ref.read(localeCodeProvider));
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  void _applySort({String? lang}) {
    final code = lang ?? ref.read(localeCodeProvider) ?? 'ar';
    customers.sort((a, b) => compareCustomerRows(a, b, sortKey, sortAsc, code));
  }

  void _onSort(String key) {
    setState(() {
      if (sortKey == key) {
        sortAsc = !sortAsc;
      } else {
        sortKey = key;
        sortAsc = key == 'name' || key == 'phone' || key == 'area';
      }
      _applySort();
    });
  }

  Future<void> _impersonate(Map c) async {
    final lang = ref.read(localeCodeProvider);
    final id = idOf(c);
    if (id.isEmpty) return;
    try {
      final r = await staffClient.post('/admin/users/$id/impersonate');
      final token = '${r['accessToken'] ?? r['impersonateToken'] ?? ''}';
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(
          id: id, name: personName(c, lang, fallbackId: id), token: token, kind: 'customer');
      if (mounted) context.go(V2Paths.impersonateSubject(id, kind: 'customer'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'users.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canImpersonate = staffCan(role, 'users.impersonate');
    final canBook = staffCan(role, 'bookings.write');

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
      resultLabel: '${customers.length} ${lang == 'ar' ? 'مسجّلة' : 'registered'}',
      emptyText: lang == 'ar' ? 'لا عميلات مطابقة' : 'Nothing here yet',
      actionsWidth: canImpersonate || canBook ? 170 : 8,
      sortKey: sortKey,
      sortAsc: sortAsc,
      onSort: _onSort,
      trailingActions: [
        V2Btn.ghost(
          advanced ? (lang == 'ar' ? 'إخفاء الفلاتر' : 'Hide filters') : (lang == 'ar' ? 'فلاتر متقدمة' : 'Advanced'),
          onPressed: () => setState(() => advanced = !advanced),
          size: V2BtnSize.sm,
        ),
      ],
      filters: [
        if (advanced)
          for (final f in _visitFilters)
            V2FilterChip(
              label: f.$2,
              selected: visits == f.$1,
              onTap: () {
                setState(() => visits = visits == f.$1 ? '' : f.$1);
                _load();
              },
            ),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'العميلة' : 'Customer', flex: 1.1, sortKey: 'name'),
        V2Col(lang == 'ar' ? 'الهاتف' : 'Phone', fixed: 140, sortKey: 'phone'),
        V2Col(lang == 'ar' ? 'المنطقة' : 'Area', fixed: 120, sortKey: 'area'),
        V2Col(lang == 'ar' ? 'الحجوزات' : 'Bookings', fixed: 100, sortKey: 'bookingCount'),
        V2Col(lang == 'ar' ? 'انضمّت' : 'Joined', fixed: 110, sortKey: 'createdAt'),
        V2Col(lang == 'ar' ? 'آخر حجز' : 'Last visit', fixed: 120, sortKey: 'lastVisit'),
      ],
      rows: [
        for (final c in customers)
          V2GridRow(
            onTap: () => context.go(V2Paths.customer(idOf(c))),
            cells: [
              Text(personName(c, lang, fallbackId: idOf(c)),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${c['phone'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.inkSoft)),
              Text(areaLabel(c['area'] ?? c['areaName'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text('${asInt(c['bookingCount'])}', style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Text(formatDayOnly(c['createdAt']), style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
              '${c['lastStatus'] ?? ''}'.isEmpty
                  ? const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted))
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: V2StatusPill(
                          label: statusLabel('${c['lastStatus']}', lang), tone: statusTone('${c['lastStatus']}')),
                    ),
            ],
            actions: [
              if (canImpersonate) V2Btn.imp('Impersonate', onPressed: () => _impersonate(c), size: V2BtnSize.row),
              if (canBook)
                V2Btn(label: lang == 'ar' ? 'حجز' : 'Book', onPressed: () => context.go(V2Paths.customer(idOf(c))), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
