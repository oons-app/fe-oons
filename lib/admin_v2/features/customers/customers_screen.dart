import 'dart:async';
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
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
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
        V2Col(lang == 'ar' ? 'العميلة' : 'Customer', flex: 1.1),
        V2Col(lang == 'ar' ? 'الهاتف' : 'Phone', fixed: 140),
        V2Col(lang == 'ar' ? 'المنطقة' : 'Area', fixed: 120),
        V2Col(lang == 'ar' ? 'الحجوزات' : 'Bookings', fixed: 100),
        V2Col(lang == 'ar' ? 'انضمّت' : 'Joined', fixed: 110),
        V2Col(lang == 'ar' ? 'آخر حجز' : 'Last visit', fixed: 120),
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
