import 'dart:async';
import 'package:flutter/foundation.dart';
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
    case 'lastSeen':
      va = parseTime(a['lastSeenAt']);
      vb = parseTime(b['lastSeenAt']);
      break;
    default:
      va = parseTime(a['createdAt']);
      vb = parseTime(b['createdAt']);
  }
  return compareSortValues(va, vb, asc: asc);
}

/// She counts as online when the app has been seen inside this window.
const customerOnlineWindow = Duration(minutes: 3);

@visibleForTesting
bool customerIsOnline(Map<String, dynamic> row, [DateTime? now]) {
  final seen = parseTime(row['lastSeenAt']);
  if (seen == null) return false;
  return (now ?? DateTime.now()).difference(seen).abs() <= customerOnlineWindow;
}

/// Device lines for the last-active tooltip. Empty when there is nothing to add
/// beyond a quiet timestamp.
@visibleForTesting
String customerActivityTip(Map<String, dynamic> row, String lang) {
  final when = formatWhen(row['lastSeenAt'], lang);
  if (when.isEmpty) return '';
  final ar = lang == 'ar';
  final online = customerIsOnline(row);
  final details = <String>[];
  final raw = row['activity'];
  if (raw is Map) {
    final a = <String, String>{};
    raw.forEach((k, v) => a['$k'] = '${v ?? ''}'.trim());
    void add(String label, String value) {
      if (value.isEmpty) return;
      details.add('$label: $value');
    }

    final model = a['model'] ?? '';
    final platform = a['platform'] ?? '';
    add(ar ? 'الجهاز' : 'Device', model.isNotEmpty ? model : _platformName(platform, ar));
    add(ar ? 'النظام' : 'System', a['os'] ?? '');
    add(ar ? 'المتصفح' : 'Browser', a['browser'] ?? '');
    final version = a['appVersion'] ?? '';
    final build = a['appBuild'] ?? '';
    if (version.isNotEmpty) {
      add(ar ? 'التطبيق' : 'App', build.isEmpty ? version : '$version ($build)');
    }
    add(ar ? 'اللغة' : 'Language', _localeName(a['locale'] ?? '', ar));
  }
  if (!online && details.isEmpty) return '';
  return [
    if (online) (ar ? 'متصلة الآن' : 'Online'),
    when,
    ...details,
  ].join('\n');
}

String _platformName(String platform, bool ar) {
  switch (platform) {
    case 'ios':
      return 'iOS';
    case 'android':
      return 'Android';
    case 'web':
      return ar ? 'الموقع' : 'Web';
    default:
      return platform;
  }
}

String _localeName(String code, bool ar) {
  switch (code) {
    case 'ar':
      return ar ? 'العربية' : 'Arabic';
    case 'en':
      return ar ? 'الإنجليزية' : 'English';
    default:
      return code;
  }
}

Widget customerLastActiveCell(Map<String, dynamic> row, String lang) {
  final when = formatWhen(row['lastSeenAt'], lang);
  if (when.isEmpty) {
    return const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted));
  }
  final online = customerIsOnline(row);
  final child = Row(
    children: [
      if (online) ...[
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Ops.green, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          when,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontFamily: Ops.mono,
            color: online ? Ops.greenInk : Ops.muted,
            fontWeight: online ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ],
  );
  final tip = customerActivityTip(row, lang);
  if (tip.isEmpty) return child;
  return Tooltip(message: tip, waitDuration: const Duration(milliseconds: 300), child: child);
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
  Timer? _presence;

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
    _presence = Timer.periodic(Ops.refreshEvery, (_) {
      if (!mounted || loading) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _presence?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          loading = true;
          error = null;
        });
      }
      final query = <String, dynamic>{'limit': 100};
      if (q.isNotEmpty) query['q'] = q;
      if (visits.isNotEmpty) query['visits'] = visits;
      final data = await staffClient.get('/admin/users', query: query);
      if (!mounted) return;
      setState(() {
        customers = asMapList(data['users'] ?? data['customers']);
        _applySort(lang: ref.read(localeCodeProvider));
        loading = false;
        error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || silent) return;
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

  Future<void> _block(Map c) async {
    final lang = ref.read(localeCodeProvider);
    final ar = lang == 'ar';
    final phone = '${c['phone'] ?? ''}'.trim();
    final name = personName(c, lang, fallbackId: idOf(c));
    if (phone.isEmpty) {
      if (mounted) v2Toast(context, ar ? 'مفيش رقم على الحساب' : 'This account has no phone number', error: true);
      return;
    }
    final ok = await v2Confirm(
      context,
      title: ar ? 'إيقاف الرقم' : 'Block this number',
      body: ar
          ? '$name ($phone) مش هتقدر تدخل التطبيق، ولا تكمل جلسة مفتوحة.'
          : '$name ($phone) will not be able to sign in or keep an open session.',
      confirmLabel: ar ? 'إيقاف' : 'Block',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await staffClient.post('/admin/blocked-phones', data: {'phone': phone, 'reason': 'customer'});
      if (mounted) v2Toast(context, ar ? 'تم إيقاف الرقم' : 'Number blocked');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
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
    final sess = ref.watch(staffSessionProvider);
    final role = sess.effectiveRole;
    if (!staffCan(role, 'users.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canImpersonate = staffCan(role, 'users.impersonate');
    final canBook = staffCan(role, 'bookings.write');
    final canBlock = sess.staffRole == roleSuper;

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
      actionsWidth: (canImpersonate || canBook ? 170 : 8) + (canBlock ? 88 : 0),
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
        V2Col(lang == 'ar' ? 'آخر نشاط' : 'Last active', fixed: 188, sortKey: 'lastSeen'),
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
              customerLastActiveCell(c, lang),
              '${c['lastStatus'] ?? ''}'.isEmpty
                  ? const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted))
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: V2StatusPill(
                          label: statusLabel('${c['lastStatus']}', lang), tone: statusTone('${c['lastStatus']}')),
                    ),
            ],
            actions: [
              if (canBlock)
                V2Btn.danger(lang == 'ar' ? 'إيقاف' : 'Ban', onPressed: () => _block(c), size: V2BtnSize.row),
              if (canImpersonate) V2Btn.imp('Impersonate', onPressed: () => _impersonate(c), size: V2BtnSize.row),
              if (canBook)
                V2Btn(label: lang == 'ar' ? 'حجز' : 'Book', onPressed: () => context.go(V2Paths.customer(idOf(c))), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
