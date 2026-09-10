import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin/api.dart';
import 'package:oons/admin/charts.dart';
import 'package:oons/admin/download_stub.dart' if (dart.library.html) 'package:oons/admin/download_web.dart';
import 'package:oons/admin/filters.dart';
import 'package:oons/admin/overlays.dart';
import 'package:oons/admin/paths.dart';
import 'package:oons/admin/session.dart';
import 'package:oons/admin/shell.dart';
import 'package:oons/admin/widgets.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/api.dart';
import 'package:oons/l10n/copy.dart';
import 'package:url_launcher/url_launcher.dart';

Map<String, dynamic> _copy(WidgetRef ref) => (Copy.of(langOf(ref))['admin'] as Map).cast<String, dynamic>();

bool _validCoord(dynamic lat, dynamic lng) {
  final la = (lat as num?)?.toDouble() ?? 0;
  final ln = (lng as num?)?.toDouble() ?? 0;
  return la.abs() > 1e-4 && ln.abs() > 1e-4;
}

bool _hasHandshake(Map b) =>
    _validCoord(b['handshakeClientLat'], b['handshakeClientLng']) ||
    _validCoord(b['handshakeProLat'], b['handshakeProLng']) ||
    b['handshakeClientAt'] != null;

String _st(Map c, String s) => '${c['st_$s'] ?? s}';
String _esc(Map c, String s) => '${c['esc_$s'] ?? s}';
String _svc(Map c, String s) => '${c['svc_$s'] ?? s}';
String _role(Map c, String s) => '${c['role_$s'] ?? s}';
int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

const _bookingStatuses = [
  'pending_payment',
  'paid',
  'on_the_way',
  'in_progress',
  'completed',
  'disputed',
  'refunded',
  'rescheduled',
  'cancelled_client',
  'cancelled_provider',
  'released',
];

const _staffRoles = [roleOps, roleFinance, roleVendor, roleAm, roleSuper];
const _services = ['beauty', 'cleaning', 'chef', 'childcare'];
const _areas = ['madinaty', 'rehab', 'capital'];
const _payoutStatuses = ['pending', 'held', 'paid'];

String _slot(dynamic v, String lang) {
  if (v == null) return '';
  final t = DateTime.tryParse('$v');
  if (t == null) return '$v';
  return formatSlot(t.toLocal(), lang);
}

String _when(dynamic v) {
  final s = '$v';
  if (s.length >= 16) return s.substring(0, 16).replaceFirst('T', ' ');
  return s;
}

List<ChartSlice> _slices(dynamic raw, String key, String Function(String) lab) {
  if (raw is! List) return [];
  return [
    for (final e in raw)
      if (e is Map) ChartSlice(label: lab('${e[key] ?? ''}'), value: (e['count'] as num?)?.toDouble() ?? 0),
  ];
}

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final email = TextEditingController(text: 'admin@oons.local');
  final password = TextEditingController();
  String? err;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await ref.read(staffSessionProvider.notifier).login(email.text.trim(), password.text);
    } on ApiException catch (e) {
      setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: adminPagePad(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: T.action,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const BrandMark(size: 44),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('${c['loginTitle']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: T.ink)),
                    const SizedBox(height: 8),
                    Text('${c['loginSub']}', textAlign: TextAlign.center, style: const TextStyle(color: T.muted, height: 1.45)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: T.surface,
                        borderRadius: BorderRadius.circular(T.radiusLg),
                        border: Border.all(color: T.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(controller: email, decoration: InputDecoration(labelText: '${c['email']}'), textDirection: TextDirection.ltr),
                          const SizedBox(height: 12),
                          TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: '${c['password']}'), onSubmitted: (_) => _submit()),
                          if (err != null) ...[const SizedBox(height: 12), Text(err!, style: const TextStyle(color: T.warmInk))],
                          const SizedBox(height: 20),
                          Material(
                            color: T.action,
                            borderRadius: BorderRadius.circular(11),
                            child: InkWell(
                              onTap: busy ? null : _submit,
                              borderRadius: BorderRadius.circular(11),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Text(
                                  busy ? '${c['loading']}' : '${c['signIn']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFFF6F0EF), fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  Map data = {};
  String? err;
  String preset = '14';
  bool busy = false;
  bool reindexing = false;
  List heatmapCells = [];
  List vettingRows = [];
  late DateTime from;
  late DateTime to;

  @override
  void initState() {
    super.initState();
    final now = dayOnly(DateTime.now());
    from = now.subtract(const Duration(days: 7));
    to = now.add(const Duration(days: 6));
    _load();
  }

  void _preset(String id) {
    final now = dayOnly(DateTime.now());
    setState(() {
      preset = id;
      if (id == '7') {
        from = now.subtract(const Duration(days: 6));
        to = now;
      } else if (id == '30') {
        from = now.subtract(const Duration(days: 23));
        to = now.add(const Duration(days: 6));
      } else if (id == 'upcoming') {
        from = now;
        to = now.add(const Duration(days: 13));
      } else {
        from = now.subtract(const Duration(days: 7));
        to = now.add(const Duration(days: 6));
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/home', query: dateQuery(from, to));
      List heat = [];
      List vet = [];
      try {
        final h = await staffApi.get('/admin/heatmap');
        heat = h['cells'] as List? ?? h['areas'] as List? ?? [];
      } catch (_) {}
      try {
        final v = await staffApi.get('/admin/vetting-sla');
        vet = v['rows'] as List? ?? v['providers'] as List? ?? v['items'] as List? ?? [];
      } catch (_) {}
      if (mounted) setState(() { data = r; heatmapCells = heat; vettingRows = vet; err = null; });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reindex() async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final ok = await showOpsConfirm(
      context,
      title: '${c['reindexSearch']}',
      body: '${c['reindexConfirm']}',
      confirmLabel: '${c['reindexSearch']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      roleLabel: _role(c, role),
    );
    if (!ok) return;
    
    setState(() => reindexing = true);
    try {
      await staffApi.post('/admin/search/reindex');
      if (mounted) opsToast(context, '${c['reindexDone']}');
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => reindexing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final statusSlices = _slices(data['bookingsByStatus'], 'status', (s) => _st(c, s));
    final daySlices = _slices(data['bookingsByDay'], 'day', (s) => s.length >= 10 ? s.substring(5) : s);
    final svcSlices = _slices(data['providersByService'], 'service', (s) => _svc(c, s));
    final recent = data['recentBookings'] is List ? data['recentBookings'] as List : const [];
    final pendingProviders = _n(data['pendingProviders']);
    final pendingPayouts = _n(data['pendingPayouts']);
    final followUps = _n(data['openDisputes']) + _n(data['liveVisits']);
    final openDisputes = _n(data['openDisputes']);
    return ListView(
      padding: adminPagePad(context),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['attentionTitle']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.ink)),
                  const SizedBox(height: 4),
                  Text('${c['attentionSub']}', style: const TextStyle(fontSize: 13, color: T.muted)),
                ],
              ),
            ),
            IconButton(
              onPressed: busy ? null : _load,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: T.muted))
                  : const Icon(Icons.refresh, size: 20, color: T.ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, box) {
            final w = box.maxWidth;
            final cols = w >= 1100 ? 4 : w >= 720 ? 2 : 1;
            final cardW = (w - (cols - 1) * 14) / cols;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: cardW,
                  child: AdminAttentionCard(
                    label: '${c['attnProviders']}',
                    count: '$pendingProviders',
                    unit: '${c['attnProvidersUnit']}',
                    state: pendingProviders > 0 ? '${c['attnNeeded']}' : '${c['attnOk']}',
                    hint: '${c['attnProvidersHint']}',
                    tone: pendingProviders > 0 ? AdminTone.warn : AdminTone.ok,
                    onTap: () => context.go(AdminPaths.providers),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: AdminAttentionCard(
                    label: '${c['attnPayouts']}',
                    count: '$pendingPayouts',
                    unit: '${c['attnPayoutsUnit']}',
                    state: pendingPayouts > 0 ? '${c['attnNeeded']}' : '${c['attnOk']}',
                    hint: '${c['attnPayoutsHint']}',
                    tone: pendingPayouts > 0 ? AdminTone.warn : AdminTone.ok,
                    onTap: () => context.go(AdminPaths.payouts),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: AdminAttentionCard(
                    label: '${c['attnBookings']}',
                    count: '$followUps',
                    unit: '${c['attnBookingsUnit']}',
                    state: followUps > 0 ? '${c['attnFollow']}' : '${c['attnOk']}',
                    hint: '${c['attnBookingsHint']}',
                    tone: followUps > 0 ? AdminTone.bad : AdminTone.ok,
                    onTap: () => context.go(AdminPaths.bookings),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: AdminAttentionCard(
                    label: '${c['attnDisputes']}',
                    count: '$openDisputes',
                    unit: '${c['attnDisputesUnit']}',
                    state: openDisputes > 0 ? '${c['attnNeeded']}' : '${c['attnOk']}',
                    hint: '${c['attnDisputesHint']}',
                    tone: openDisputes > 0 ? AdminTone.bad : AdminTone.ok,
                    onTap: () => context.go('${AdminPaths.bookings}?status=disputed'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          AdminFilterChip(label: '${c['days7']}', selected: preset == '7', onTap: () => _preset('7')),
          AdminFilterChip(label: '${c['days14']}', selected: preset == '14', onTap: () => _preset('14')),
          AdminFilterChip(label: '${c['days30']}', selected: preset == '30', onTap: () => _preset('30')),
          AdminFilterChip(label: '${c['upcoming']}', selected: preset == 'upcoming', onTap: () => _preset('upcoming')),
          DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: (d) { if (d == null) return; setState(() { from = d; preset = ''; }); _load(); }),
          DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: (d) { if (d == null) return; setState(() { to = d; preset = ''; }); _load(); }),
        ]),
        if (err != null) ...[const SizedBox(height: 12), AdminErrorBanner(message: err!, onRetry: _load)],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, box) {
            final w = box.maxWidth;
            final cols = w >= 1100 ? 3 : w >= 720 ? 2 : 1;
            final cardW = (w - (cols - 1) * 12) / cols;
            final kpis = <Widget>[
              if (data.containsKey('bookingsToday'))
                AdminKpiCard(label: '${c['bookingsToday']}', value: '${data['bookingsToday']}', note: '${c['kpiTodayNote']}'),
              if (data.containsKey('liveVisits'))
                AdminKpiCard(label: '${c['liveVisits']}', value: '${data['liveVisits']}', note: '${c['kpiLiveNote']}'),
              if (data.containsKey('vettedProviders'))
                AdminKpiCard(label: '${c['vettedProviders']}', value: '${data['vettedProviders']}'),
              if (data.containsKey('totalUsers'))
                AdminKpiCard(label: '${c['totalUsers']}', value: '${data['totalUsers']}'),
              if (data.containsKey('pendingPayouts'))
                AdminKpiCard(label: '${c['pendingPayouts']}', value: '${data['pendingPayouts']}'),
              if (data.containsKey('establishedQuietPairs'))
                AdminKpiCard(
                  label: '${c['establishedQuietPairs'] ?? 'Established quiet pairs'}',
                  value: '${data['establishedQuietPairs']}',
                  note: '${c['establishedQuietNote'] ?? 'Established client–pro pairs idle 60+ days'}',
                ),
              if (data.containsKey('totalBookings'))
                AdminKpiCard(label: '${c['totalBookings']}', value: '${data['totalBookings']}'),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final k in kpis) SizedBox(width: cardW, child: k)],
            );
          },
        ),
        if (statusSlices.isNotEmpty || daySlices.isNotEmpty || svcSlices.isNotEmpty) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (statusSlices.isNotEmpty)
                _Panel(title: '${c['chartStatus']}', width: 440, child: AdminBarChart(slices: statusSlices)),
              if (daySlices.isNotEmpty)
                _Panel(title: '${c['chartDays']}', width: 520, child: AdminLineChart(slices: daySlices)),
              if (svcSlices.isNotEmpty)
                _Panel(title: '${c['chartService']}', width: 440, child: AdminDonutChart(slices: svcSlices)),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HomeActionCard(
              title: '${c['homeHeatmap']}',
              body: heatmapCells.isEmpty
                  ? '${c['heatmapSub']}'
                  : heatmapCells.take(4).map((raw) {
                      final m = raw is Map ? raw : {};
                      return '${m['area']}: ${m['supply']}/${m['demand']}';
                    }).join(' · '),
              onTap: () => context.go(AdminPaths.heatmap),
            ),
            _HomeActionCard(
              title: '${c['homeVetting']}',
              body: vettingRows.isEmpty
                  ? '${c['vettingSub']}'
                  : '${vettingRows.length} pending · ${c['vettingSub']}',
              onTap: () => context.go(AdminPaths.vetting),
            ),
            _HomeActionCard(
              title: '${c['homePayments']}',
              body: '${c['paymentsSub'] ?? c['payments'] ?? 'Payment settings'}',
              onTap: () => context.go(AdminPaths.payments),
            ),
            _HomeActionCard(
              title: '${c['reindexSearch']}',
              body: reindexing ? '${c['loading']}' : 'POST /admin/search/reindex',
              onTap: reindexing ? null : _reindex,
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('${c['recent']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: T.ink)),
          const SizedBox(height: 8),
          _Table(
            headers: ['${c['colRef']}', '${c['colStatus']}', '${c['colTotal']}', '${c['colService']}'],
            rows: [
              for (final b in recent)
                if (b is Map)
                  [
                    '${b['ref'] ?? ''}',
                    _st(c, '${b['status'] ?? ''}'),
                    money(_n(b['total']), lang),
                    locName(b['serviceName'], lang),
                  ],
            ],
            onTap: (i) {
              final b = recent[i];
              if (b is Map) context.go(AdminPaths.booking('${b['id']}'));
            },
          ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.width = 400});
  final String title;
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) {
    final inner = MediaQuery.sizeOf(context).width - (adminCompact(context) ? 32 : 48);
    final w = width > inner ? inner : width;
    return Container(
      width: w,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusLg),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: T.ink)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}


class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({required this.title, required this.body, this.onTap});
  final String title;
  final String body;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Material(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(T.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(T.radiusLg),
              border: Border.all(color: T.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.ink)),
                const SizedBox(height: 6),
                Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: T.muted, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminProvidersScreen extends ConsumerStatefulWidget {
  const AdminProvidersScreen({super.key});
  @override
  ConsumerState<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends ConsumerState<AdminProvidersScreen> {
  String filter = '';
  String service = '';
  List rows = [];
  String? err;
  bool busy = false;
  final q = TextEditingController();
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/providers', query: {
        if (filter.isNotEmpty) 'vetted': filter,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (service.isNotEmpty) 'service': service,
        ...dateQuery(from, to),
        'limit': 80,
      });
      if (mounted) {
        setState(() {
          rows = r['providers'] as List? ?? [];
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _clear() {
    q.clear();
    setState(() { filter = ''; service = ''; from = null; to = null; });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'providers.read',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.go(AdminPaths.vetting),
                  child: Text('${c['openSla'] ?? 'Open SLA queue'}'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final role = effectiveStaffRole(ref.read(staffSessionProvider));
                          final ok = await showOpsConfirm(
                            context,
                            title: '${c['reindexSearch']}',
                            body: '${c['reindexConfirm'] ?? 'Rebuild provider search index?'}',
                            confirmLabel: '${c['reindexSearch']}',
                            roleLabel: _role(c, role),
                          );
                          if (!ok) return;
                          try {
                            await staffApi.post('/admin/search/reindex');
                            if (context.mounted) opsToast(context, '${c['reindexDone']}');
                          } on ApiException catch (e) {
                            if (context.mounted) opsToast(context, e.message, error: true);
                          }
                        },
                  child: Text('${c['reindexSearch']}'),
                ),
              ],
            ),
          ),
          FilterWrap(title: '${c['providers']}', children: [
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: busy ? null : _load),
            FilterDrop<String>(
              value: service,
              items: [
                DropdownMenuItem(value: '', child: Text('${c['filterService']}')),
                for (final s in _services) DropdownMenuItem(value: s, child: Text(_svc(c, s))),
              ],
              onChanged: busy ? null : (v) { setState(() => service = v ?? ''); _load(); },
            ),
            DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: busy ? null : (d) { setState(() => from = d); _load(); }),
            DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: busy ? null : (d) { setState(() => to = d); _load(); }),
            _Chip('${c['all']}', filter == '', busy ? null : () { setState(() => filter = ''); _load(); }),
            _Chip('${c['pending']}', filter == '0', busy ? null : () { setState(() => filter = '0'); _load(); }),
            _Chip('${c['vetted']}', filter == '1', busy ? null : () { setState(() => filter = '1'); _load(); }),
            FilterApply(label: '${c['apply']}', onTap: busy ? null : _load),
            FilterClear(label: '${c['clear']}', onTap: busy ? null : _clear),
          ]),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          Expanded(
            child: busy && rows.isEmpty
                ? AdminLoading(label: '${c['loading']}')
                : rows.isEmpty
                    ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                    : _Table(
                        headers: ['${c['colName']}', '${c['colService']}', '${c['colPhone']}', '${c['rating']}', '${c['colStatus']}'],
                        rows: [
                          for (final p in rows)
                            [
                              locName(p['firstName'], lang),
                              _svc(c, '${p['service'] ?? ''}'),
                              '${p['phone'] ?? ''}',
                              '${p['rating'] ?? 0}',
                              (p['vettedAt'] == null || '${p['vettedAt']}'.startsWith('0001')) ? '${c['pending']}' : '${c['vetted']}',
                            ],
                        ],
                        onTap: (i) => context.go(AdminPaths.provider('${rows[i]['id']}')),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.on, this.tap);
  final String label;
  final bool on;
  final VoidCallback? tap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? T.action : T.surface,
      child: InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label, style: TextStyle(color: on ? T.white : (tap == null ? T.muted : T.ink), fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }
}

class AdminProviderDetailScreen extends ConsumerStatefulWidget {
  const AdminProviderDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AdminProviderDetailScreen> createState() => _AdminProviderDetailScreenState();
}

class _AdminProviderDetailScreenState extends ConsumerState<AdminProviderDetailScreen> {
  Map? p;
  String? err;
  bool busy = false;
  bool sexMarkerConfirmed = false;
  int fishGraceDays = 14;
  final notes = TextEditingController();
  final reason = TextEditingController();
  final graceNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/providers/${widget.id}');
      if (mounted) {
        notes.text = '${r['staffNotes'] ?? ''}';
        reason.text = '${r['rejectReason'] ?? ''}';
        setState(() { p = r; err = null; });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    notes.dispose();
    reason.dispose();
    graceNote.dispose();
    super.dispose();
  }

  bool _vetted(Map p) => p['vettedAt'] != null && !'${p['vettedAt']}'.startsWith('0001');
  bool _rejected(Map p) => p['rejectedAt'] != null && !'${p['rejectedAt']}'.startsWith('0001');

  DateTime? _graceUntil(Map p) {
    final raw = '${p['fishGraceUntil'] ?? ''}';
    if (raw.isEmpty || raw.startsWith('0001')) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _graceActive(Map p) {
    final u = _graceUntil(p);
    return u != null && u.isAfter(DateTime.now());
  }

  bool _payoutFrozen(Map p) {
    final raw = '${p['payoutFrozenAt'] ?? ''}';
    return raw.isNotEmpty && !raw.startsWith('0001');
  }

  Future<void> _vet() async {
    final c = _copy(ref);
    final role = effectiveStaffRole(ref.read(staffSessionProvider));
    final ok = await showOpsConfirm(
      context,
      title: '${c['confirmVetTitle'] ?? c['vet']}',
      body: '${c['confirmVetBody'] ?? 'Mark this professional as vetted and bookable?'}',
      confirmLabel: '${c['vet']}',
      roleLabel: _role(c, role),
    );
    if (!ok || !mounted) return;

    if (!sexMarkerConfirmed) {
      adminSnack(context, '${c['sexMarkerConfirm']}', error: true);
      return;
    }
    final hasFish = '${p?['fishPhotoUrl'] ?? ''}'.isNotEmpty;
    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/providers/${widget.id}/vet', data: {
        'sexMarkerConfirmed': true,
        if (!hasFish) 'fishGraceDays': fishGraceDays,
        if (!hasFish && graceNote.text.trim().isNotEmpty) 'fishGraceNote': graceNote.text.trim(),
      });
      if (mounted) {
        setState(() { p = r; busy = false; });
        unawaited(AppAnalytics.providerVettingApproved(providerId: widget.id));
        adminSnack(context, '${c['vetDone']}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => busy = false);
        adminSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _grantFishGrace() async {
    final c = _copy(ref);
    if (!sexMarkerConfirmed) {
      adminSnack(context, '${c['sexMarkerConfirm']}', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/providers/${widget.id}/fish-grace', data: {
        'days': fishGraceDays,
        if (graceNote.text.trim().isNotEmpty) 'note': graceNote.text.trim(),
      });
      if (mounted) {
        setState(() { p = r; busy = false; });
        adminSnack(context, '${c['fishGraceDone']}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => busy = false);
        adminSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _reverify() async {
    final c = _copy(ref);
    final role = effectiveStaffRole(ref.read(staffSessionProvider));
    final ok = await showOpsConfirm(
      context,
      title: '${c['confirmReverifyTitle'] ?? c['reverify']}',
      body: '${c['confirmReverifyBody'] ?? 'Schedule re-verification in one year?'}',
      confirmLabel: '${c['reverify']}',
      roleLabel: _role(c, role),
    );
    if (!ok || !mounted) return;

    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/providers/${widget.id}/reverify');
      if (mounted) {
        setState(() {
          if (p != null) p = {...p!, ...r};
          busy = false;
        });
        adminSnack(context, '${c['reverifyDone']}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => busy = false);
        adminSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _reject() async {
    final c = _copy(ref);
    final role = effectiveStaffRole(ref.read(staffSessionProvider));
    final ok = await showOpsConfirm(
      context,
      title: '${c['confirmRejectTitle'] ?? c['reject']}',
      body: '${c['confirmRejectBody'] ?? 'Reject this professional application?'}',
      confirmLabel: '${c['reject']}',
      roleLabel: _role(c, role),
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/providers/${widget.id}/reject', data: {'reason': reason.text.trim()});
      unawaited(AppAnalytics.providerVettingRejected(providerId: widget.id, reason: reason.text.trim()));
      if (mounted) {
        setState(() => p = r);
        adminSnack(context, '${c['rejectDone']}');
      }
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _impersonate() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/providers/${widget.id}/impersonate');
      final token = '${r['accessToken'] ?? ''}';
      if (token.isEmpty) throw ApiException(0, 'No token returned.');
      
      final proName = locName(p!['firstName'], langOf(ref));
      ref.read(staffSessionProvider.notifier).startImpersonation(
        id: widget.id,
        name: proName,
        token: token,
        kind: 'provider',
      );
      
      if (mounted) {
        context.go(AdminPaths.impersonateProvider(widget.id));
      }
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveNotes() async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/providers/${widget.id}/notes', data: {'notes': notes.text});
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _suspend() async {
    final c = _copy(ref);
    final reasonController = TextEditingController();
    
    final ok = await showOpsPanel(
      context,
      title: '${c['suspendProvider']}',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${c['suspendReason']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: '${c['suspendReason']}',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      confirmLabel: '${c['suspend']}',
      danger: true,
      onValidate: () => reasonController.text.trim().isNotEmpty,
    );
    
    if (ok && mounted) {
      setState(() => busy = true);
      try {
        final r = await staffApi.post('/admin/providers/${widget.id}/suspend', 
            data: {'reason': reasonController.text.trim()});
        if (mounted) {
          setState(() => p = r);
          opsToast(context, '${c['providerSuspended']}');
        }
      } on ApiException catch (e) {
        if (mounted) opsToast(context, e.message, error: true);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    reasonController.dispose();
  }

  Future<void> _reinstate() async {
    final c = _copy(ref);
    final ok = await showOpsConfirm(
      context,
      title: '${c['reinstateProvider']}',
      body: '${c['reinstateProviderConfirm']}',
      confirmLabel: '${c['reinstate']}',
    );
    
    if (ok && mounted) {
      setState(() => busy = true);
      try {
        final r = await staffApi.post('/admin/providers/${widget.id}/reinstate');
        if (mounted) {
          setState(() => p = r);
          opsToast(context, '${c['providerReinstated']}');
        }
      } on ApiException catch (e) {
        if (mounted) opsToast(context, e.message, error: true);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  Future<void> _updateDocStatus(String kind, String status, {String? note}) async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      final data = {'status': status};
      if (note != null && note.isNotEmpty) data['note'] = note;
      
      final r = await staffApi.post('/admin/providers/${widget.id}/docs/$kind', data: data);
      if (mounted) {
        setState(() => p = r);
        opsToast(context, '${c['docStatusUpdated']}');
      }
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _acceptDoc(String kind) async {
    await _updateDocStatus(kind, 'accepted');
  }

  Future<void> _rejectDoc(String kind) async {
    final c = _copy(ref);
    final noteController = TextEditingController();
    
    final ok = await showOpsPanel(
      context,
      title: '${c['rejectDocument']}',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${c['rejectionNote']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            decoration: InputDecoration(
              labelText: '${c['rejectionNote']}',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      confirmLabel: '${c['reject']}',
      danger: true,
    );
    
    if (ok && mounted) {
      await _updateDocStatus(kind, 'rejected', note: noteController.text.trim());
    }
    noteController.dispose();
  }

  Future<void> _addService() async {
    final c = _copy(ref);
    final nameEnController = TextEditingController();
    final nameArController = TextEditingController();
    final durationController = TextEditingController(text: '60');
    final priceController = TextEditingController();
    
    final ok = await showOpsPanel(
      context,
      title: '${c['addService']}',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameEnController,
            decoration: InputDecoration(
              labelText: '${c['serviceNameEn']}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameArController,
            decoration: InputDecoration(
              labelText: '${c['serviceNameAr']}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: durationController,
            decoration: InputDecoration(
              labelText: '${c['durationMinutes']}',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            decoration: InputDecoration(
              labelText: '${c['priceEgp']}',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      onValidate: () => 
        nameEnController.text.trim().isNotEmpty && 
        nameArController.text.trim().isNotEmpty &&
        durationController.text.trim().isNotEmpty &&
        priceController.text.trim().isNotEmpty,
    );
    
    if (ok && mounted) {
      final currentItems = List.from(p?['items'] as List? ?? []);
      final priceEgp = double.tryParse(priceController.text.trim()) ?? 0;
      final pricePiastres = (priceEgp * 100).round();
      
      currentItems.add({
        'name': {
          'en': nameEnController.text.trim(),
          'ar': nameArController.text.trim(),
        },
        'durationMin': int.tryParse(durationController.text.trim()) ?? 60,
        'price': pricePiastres,
      });
      
      await _updateProvider({'items': currentItems});
    }
    
    nameEnController.dispose();
    nameArController.dispose();
    durationController.dispose();
    priceController.dispose();
  }

  Future<void> _editService(Map service) async {
    final c = _copy(ref);
    final nameEn = service['name'] is Map ? '${(service['name'] as Map)['en'] ?? ''}' : '';
    final nameAr = service['name'] is Map ? '${(service['name'] as Map)['ar'] ?? ''}' : '';
    
    final nameEnController = TextEditingController(text: nameEn);
    final nameArController = TextEditingController(text: nameAr);
    final durationController = TextEditingController(text: '${service['durationMin'] ?? 60}');
    final priceEgp = (_n(service['price']) / 100).toStringAsFixed(2);
    final priceController = TextEditingController(text: priceEgp);
    
    final ok = await showOpsPanel(
      context,
      title: '${c['editService']}',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameEnController,
            decoration: InputDecoration(
              labelText: '${c['serviceNameEn']}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameArController,
            decoration: InputDecoration(
              labelText: '${c['serviceNameAr']}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: durationController,
            decoration: InputDecoration(
              labelText: '${c['durationMinutes']}',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            decoration: InputDecoration(
              labelText: '${c['priceEgp']}',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      onValidate: () => 
        nameEnController.text.trim().isNotEmpty && 
        nameArController.text.trim().isNotEmpty &&
        durationController.text.trim().isNotEmpty &&
        priceController.text.trim().isNotEmpty,
    );
    
    if (ok && mounted) {
      final currentItems = List.from(p?['items'] as List? ?? []);
      final serviceIndex = currentItems.indexWhere((item) => 
        item is Map && item['name'] is Map &&
        item['name']['en'] == nameEn && item['name']['ar'] == nameAr);
      
      if (serviceIndex >= 0) {
        final priceEgpVal = double.tryParse(priceController.text.trim()) ?? 0;
        final pricePiastres = (priceEgpVal * 100).round();
        
        currentItems[serviceIndex] = {
          'name': {
            'en': nameEnController.text.trim(),
            'ar': nameArController.text.trim(),
          },
          'durationMin': int.tryParse(durationController.text.trim()) ?? 60,
          'price': pricePiastres,
        };
        
        await _updateProvider({'items': currentItems});
      }
    }
    
    nameEnController.dispose();
    nameArController.dispose();
    durationController.dispose();
    priceController.dispose();
  }

  Future<void> _updateProvider(Map<String, dynamic> data) async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      final r = await staffApi.patch('/admin/providers/${widget.id}', data: data);
      if (mounted) {
        setState(() => p = r);
        opsToast(context, '${c['saved']}');
      }
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleArea(String areaCode, bool selected) async {
    final currentAreas = List<String>.from(p?['areas'] as List? ?? []);
    
    if (selected && !currentAreas.contains(areaCode)) {
      currentAreas.add(areaCode);
    } else if (!selected && currentAreas.contains(areaCode)) {
      currentAreas.remove(areaCode);
    }
    
    await _updateProvider({'areas': currentAreas});
  }

  Future<void> _editPayout() async {
    final c = _copy(ref);
    final methodController = TextEditingController(text: '${p?['payoutMethod'] ?? ''}');
    final handleController = TextEditingController(text: '${p?['payoutHandle'] ?? ''}');
    
    final ok = await showOpsPanel(
      context,
      title: '${c['editPayout']}',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: methodController,
            decoration: InputDecoration(
              labelText: '${c['payoutMethod']}',
              border: const OutlineInputBorder(),
              hintText: 'instapay, bank, etc.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: handleController,
            decoration: InputDecoration(
              labelText: '${c['payoutHandle']}',
              border: const OutlineInputBorder(),
              hintText: 'Account number or handle',
            ),
          ),
        ],
      ),
      onValidate: () => methodController.text.trim().isNotEmpty,
    );
    
    if (ok && mounted) {
      await _updateProvider({
        'payoutMethod': methodController.text.trim(),
        'payoutHandle': handleController.text.trim(),
      });
    }
    
    methodController.dispose();
    handleController.dispose();
  }

  String _workDays(Map p, String lang) {
    final days = p['workDays'];
    if (days is! List || days.isEmpty) return '—';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const arNames = ['اتنين', 'تلات', 'أربع', 'خميس', 'جمعة', 'سبت', 'حد'];
    return days.map((d) {
      final i = (d is num ? d.toInt() : int.tryParse('$d') ?? 0) - 1;
      if (i < 0 || i > 6) return '$d';
      return lang == 'ar' ? arNames[i] : names[i];
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    if (p == null) return AdminLoading(label: err ?? '${c['loading']}');
    final prov = p!;
    final hasId = '${prov['idPhotoUrl'] ?? ''}'.isNotEmpty;
    final hasFish = '${prov['fishPhotoUrl'] ?? ''}'.isNotEmpty;
    final overview = ListView(
      padding: adminPagePad(context),
      children: [
        AdminPageHeader(
          title: '${locName(prov['firstName'], lang)} ${locName(prov['lastName'], lang)}'.trim(),
          subtitle: '${prov['phone'] ?? ''} · ${_svc(c, '${prov['service'] ?? ''}')}',
          onBack: () => context.pop(),
          onRefresh: _load,
          busy: busy,
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_vetted(prov))
            AdminStatusPill(label: '${c['vetted']}', tone: AdminTone.ok)
          else if (_rejected(prov))
            AdminStatusPill(label: '${c['rejected']}', tone: AdminTone.bad)
          else
            AdminStatusPill(label: '${c['pending']}', tone: AdminTone.warn),
          if (prov['suspendedAt'] != null && !'${prov['suspendedAt']}'.startsWith('0001'))
            AdminStatusPill(label: '${c['suspended']}', tone: AdminTone.bad),
          if (_payoutFrozen(prov))
            AdminStatusPill(label: '${c['payoutFrozenFish']}', tone: AdminTone.bad)
          else if (_graceActive(prov))
            AdminStatusPill(
              label: '${c['fishGraceActive']} ${_graceUntil(prov)!.toIso8601String().substring(0, 10)}',
              tone: AdminTone.warn,
            )
          else if (hasFish)
            AdminStatusPill(label: '${c['fishValidated']}', tone: AdminTone.ok)
          else
            AdminStatusPill(label: '${c['fishMissing']}', tone: AdminTone.bad),
          if (!hasId) AdminStatusPill(label: '${c['idMissing']}', tone: AdminTone.bad),
        ]),
        const SizedBox(height: 16),
        AdminSection(
          title: '${c['profile']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInfoRow(label: '${c['legalName']}', value: '${prov['legalName'] ?? ''}'),
              AdminInfoRow(label: '${c['nationalId']}', value: '${prov['nationalId'] ?? ''}', mono: true),
              AdminInfoRow(label: '${c['birthDate']}', value: '${prov['birthDate'] ?? ''}'),
              AdminInfoRow(label: '${c['residence']}', value: '${prov['residenceLine'] ?? ''}'),
              AdminInfoRow(label: '${c['specialty']}', value: locName(prov['specialty'], lang)),
              AdminInfoRow(label: '${c['yearsExp']}', value: '${prov['years'] ?? ''}'),
              if ('${prov['slug'] ?? ''}'.isNotEmpty) AdminInfoRow(label: '${c['slug']}', value: '/p/${prov['slug']}', mono: true),
              AdminInfoRow(label: '${c['rating']}', value: '${prov['rating'] ?? 0} · ${prov['reviewCount'] ?? 0} ${c['reviews']}'),
              if (prov['bio'] != null) ...[
                const SizedBox(height: 8),
                Text('${c['bio']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: T.muted)),
                Text(locName(prov['bio'], lang)),
              ],
            ],
          ),
        ),
        if (_rejected(prov))
          AdminSection(
            title: '${c['rejected']}',
            child: Text('${prov['rejectReason'] ?? ''}', style: const TextStyle(color: T.danger)),
          ),
        if (staffCan(role, 'providers.impersonate'))
          AdminSection(
            title: '${c['impersonate']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['impersonateHint']}', style: const TextStyle(fontSize: 12, color: T.muted, height: 1.45)),
                const SizedBox(height: 10),
                _FillButton(label: '${c['impersonate']}', onTap: busy ? null : _impersonate, busy: busy),
              ],
            ),
          ),
        if (staffCan(role, 'providers.write'))
          AdminSection(
            title: '${c['providerStatus']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prov['suspendedAt'] != null && !'${prov['suspendedAt']}'.startsWith('0001')) ...[
                  Text('${c['providerSuspendedNote']}', style: const TextStyle(fontSize: 12, color: T.muted)),
                  const SizedBox(height: 10),
                  _FillButton(label: '${c['reinstate']}', onTap: busy ? null : _reinstate, busy: busy),
                ] else ...[
                  Text('${c['suspendProviderNote']}', style: const TextStyle(fontSize: 12, color: T.muted)),
                  const SizedBox(height: 10),
                  _FillButton(label: '${c['suspend']}', onTap: busy ? null : _suspend, danger: true, filled: false, busy: busy),
                ],
              ],
            ),
          ),
        if (staffCan(role, 'notes.write'))
          AdminSection(
            title: '${c['notes']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: '${c['notes']}', border: const OutlineInputBorder())),
                const SizedBox(height: 8),
                _FillButton(label: '${c['saveNotes']}', onTap: busy ? null : _saveNotes, busy: busy),
              ],
            ),
          ),
        if (staffCan(role, 'providers.vet')) ...[
          AdminSection(
            title: '${c['vet']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sexMarkerConfirmed,
                  onChanged: (v) => setState(() => sexMarkerConfirmed = v ?? false),
                  title: Text('${c['sexMarkerConfirm']}', style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                TextField(controller: reason, decoration: InputDecoration(labelText: '${c['rejectReason']}', border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                _FillButton(label: '${c['vet']}', onTap: busy || !sexMarkerConfirmed ? null : _vet, busy: busy),
                const SizedBox(height: 8),
                _FillButton(label: '${c['reject']}', onTap: busy ? null : _reject, filled: false, danger: true, busy: busy),
                const SizedBox(height: 8),
                _FillButton(label: '${c['reverify']}', onTap: busy ? null : _reverify, filled: false, busy: busy),
              ],
            ),
          ),
          if (!hasFish)
            AdminSection(
              title: '${c['fishGrace']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['fishGraceHint']}', style: const TextStyle(fontSize: 12.5, height: 1.4, color: T.muted)),
                  const SizedBox(height: 10),
                  Text('${c['fishGraceDays']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30, 60].map((d) {
                      final on = fishGraceDays == d;
                      return ChoiceChip(
                        label: Text('$d'),
                        selected: on,
                        onSelected: (_) => setState(() => fishGraceDays = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: graceNote,
                    decoration: InputDecoration(labelText: '${c['fishGraceNote']}', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  _FillButton(
                    label: '${c['fishGraceGrant']}',
                    onTap: busy || !sexMarkerConfirmed ? null : _grantFishGrace,
                    busy: busy,
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    final documents = ListView(
      padding: adminPagePad(context),
      children: [
        AdminSection(
          title: '${c['documents']}',
          child: Column(
            children: [
              AdminPhotoBlock(label: '${c['idPhoto']}', url: '${prov['idPhotoUrl'] ?? ''}', loader: staffApi.uploadBytes),
              if (staffCan(role, 'id.photos') && hasId) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => _acceptDoc('id'),
                      icon: const Icon(Icons.check, size: 16, color: Colors.green),
                      label: Text('${c['docAccept']}'),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => _rejectDoc('id'),
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: Text('${c['docReject']}'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              AdminPhotoBlock(label: '${c['fishPhoto']}', url: '${prov['fishPhotoUrl'] ?? ''}', loader: staffApi.uploadBytes),
              if (staffCan(role, 'id.photos') && hasFish) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => _acceptDoc('fish'),
                      icon: const Icon(Icons.check, size: 16, color: Colors.green),
                      label: Text('${c['docAccept']}'),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : () => _rejectDoc('fish'),
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: Text('${c['docReject']}'),
                    ),
                  ],
                ),
              ],
              if (!hasId) ...[const SizedBox(height: 8), Text('${c['noIdWarn']}', style: const TextStyle(color: T.danger, fontSize: 12))],
              if (!hasFish) ...[const SizedBox(height: 8), Text('${c['noFishWarn']}', style: const TextStyle(color: T.danger, fontSize: 12))],
            ],
          ),
        ),
        if (prov['consents'] is Map)
          AdminSection(
            title: '${c['consents']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in [
                  ('terms', '${c['consentTerms']}'),
                  ('data', '${c['consentData']}'),
                  ('backgroundCheck', '${c['consentBg']}'),
                  ('womenOnly', '${c['consentWomen']}'),
                  ('tax', '${c['consentTax']}'),
                ])
                  AdminInfoRow(
                    label: row.$2,
                    value: (prov['consents'] as Map)[row.$1] == true ? '${c['yes']}' : '${c['no']}',
                  ),
                if (prov['consentedAt'] != null) AdminInfoRow(label: '${c['colAt']}', value: _when(prov['consentedAt'])),
              ],
            ),
          ),
      ],
    );

    final services = ListView(
      padding: adminPagePad(context),
      children: [
        AdminSection(
          title: '${c['services']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prov['items'] is! List || (prov['items'] as List).isEmpty)
                Text('${c['empty']}', style: const TextStyle(color: T.muted))
              else
                for (final item in prov['items'] as List)
                  if (item is Map)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${locName(item['name'], lang)} · ${item['durationMin'] ?? ''} ${c['minutes']} · ${money(_n(item['price']), lang)}'),
                          ),
                          if (staffCan(role, 'providers.write'))
                            TextButton(
                              onPressed: busy ? null : () => _editService(item),
                              child: Text('${c['edit']}'),
                            ),
                        ],
                      ),
                    ),
              const SizedBox(height: 16),
              if (staffCan(role, 'providers.write'))
                _FillButton(
                  label: '${c['addService']}',
                  onTap: busy ? null : () => _addService(),
                  filled: false,
                  busy: busy,
                ),
            ],
          ),
        ),
      ],
    );

    final coverage = ListView(
      padding: adminPagePad(context),
      children: [
        AdminSection(
          title: '${c['areas']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (staffCan(role, 'areas.write')) ...[
                Text('${c['toggleAreas']}', style: const TextStyle(fontSize: 12, color: T.muted, height: 1.45)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final areaCode in _areas)
                      ChoiceChip(
                        label: Text(areaName(areaCode, lang)),
                        selected: (prov['areas'] as List? ?? []).contains(areaCode),
                        onSelected: busy ? null : (selected) => _toggleArea(areaCode, selected),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (prov['areas'] is List)
                    for (final a in prov['areas'] as List)
                      AdminStatusPill(label: areaName('$a', lang), tone: AdminTone.neutral),
                ],
              ),
            ],
          ),
        ),
        AdminSection(
          title: '${c['schedule']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInfoRow(label: '${c['workDays']}', value: _workDays(prov, lang)),
              AdminInfoRow(
                label: '${c['slotHours']}',
                value: prov['slotHours'] is List && (prov['slotHours'] as List).isNotEmpty ? (prov['slotHours'] as List).join(', ') : '—',
              ),
            ],
          ),
        ),
      ],
    );

    final portfolio = ListView(
      padding: adminPagePad(context),
      children: [
        AdminSection(
          title: '${c['portfolio']}',
          child: prov['portfolio'] is List && (prov['portfolio'] as List).isNotEmpty
              ? SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (prov['portfolio'] as List).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final url = '${(prov['portfolio'] as List)[i]}';
                      return _PortfolioThumb(url: url);
                    },
                  ),
                )
              : Text('${c['empty']}', style: const TextStyle(color: T.muted)),
        ),
      ],
    );

    final moneyTab = ListView(
      padding: adminPagePad(context),
      children: [
        AdminSection(
          title: '${c['payoutsInfo']}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminInfoRow(label: '${c['payoutMethod']}', value: '${prov['payoutMethod'] ?? ''}'),
              AdminInfoRow(label: '${c['payoutHandle']}', value: '${prov['payoutHandle'] ?? ''}', mono: true),
              if (staffCan(role, 'providers.write')) ...[
                const SizedBox(height: 16),
                _FillButton(
                  label: '${c['editPayout']}',
                  onTap: busy ? null : _editPayout,
                  filled: false,
                  busy: busy,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return AdminGate(
      perm: 'providers.read',
      child: DefaultTabController(
        length: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: T.bg,
              child: TabBar(
                isScrollable: true,
                labelColor: T.ink,
                unselectedLabelColor: T.muted,
                indicatorColor: T.warm,
                tabs: [
                  Tab(text: '${c['tabOverview'] ?? 'Overview'}'),
                  Tab(text: '${c['tabDocs'] ?? c['documents']}'),
                  Tab(text: '${c['tabServices'] ?? c['services']}'),
                  Tab(text: '${c['tabCoverage'] ?? c['areas']}'),
                  Tab(text: '${c['tabPortfolio'] ?? c['portfolio']}'),
                  Tab(text: '${c['tabMoney'] ?? c['payoutsInfo']}'),
                ],
              ),
            ),
            const Divider(height: 1, color: T.line),
            Expanded(
              child: TabBarView(
                children: [overview, documents, services, coverage, portfolio, moneyTab],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PortfolioThumb extends StatefulWidget {
  const _PortfolioThumb({required this.url});
  final String url;

  @override
  State<_PortfolioThumb> createState() => _PortfolioThumbState();
}

class _PortfolioThumbState extends State<_PortfolioThumb> {
  Uint8List? bytes;

  @override
  void initState() {
    super.initState();
    staffApi.uploadBytes(widget.url).then((b) { if (mounted) setState(() => bytes = b); });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(border: Border.all(color: T.line, width: T.rule)),
      child: bytes != null ? Image.memory(bytes!, fit: BoxFit.cover) : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key, this.live = false});
  final bool live;
  @override
  ConsumerState<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  final q = TextEditingController();
  final providerId = TextEditingController();
  String status = '';
  String service = '';
  DateTime? from;
  DateTime? to;
  bool unpaidOpsOnly = false;
  bool bulkMode = false;
  List rows = [];
  final selected = <String>{};
  String? err;
  bool busy = false;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.live) {
      poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    q.dispose();
    providerId.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/bookings', query: {
        if (widget.live) 'live': '1',
        if (!widget.live && status.isNotEmpty) 'status': status,
        if (service.isNotEmpty) 'service': service,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (providerId.text.trim().isNotEmpty) 'providerId': providerId.text.trim(),
        if (unpaidOpsOnly) 'unpaidOps': '1',
        ...dateQuery(from, to),
        'limit': 80,
      });
      if (mounted) {
        setState(() {
          rows = r['bookings'] as List? ?? [];
          selected.removeWhere((id) => !rows.any((b) => '${(b as Map)['id']}' == id));
          err = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() { rows = []; err = '$e'; });
    } finally {
      if (mounted && !silent) setState(() => busy = false);
    }
  }

  void _clear() {
    q.clear();
    providerId.clear();
    setState(() { status = ''; service = ''; from = null; to = null; unpaidOpsOnly = false; selected.clear(); });
    _load();
  }

  void _toggle(String id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else {
        selected.add(id);
      }
    });
  }

  void _selectAllEligible() {
    setState(() {
      for (final raw in rows) {
        final b = raw as Map;
        final id = '${b['id']}';
        final st = '${b['status']}';
        final paid = b['opsPaid'] == true;
        if ((st == 'completed' || st == 'released') && !paid) selected.add(id);
      }
    });
  }

  List<Map> get _selectedRows => [
        for (final raw in rows)
          if (raw is Map && selected.contains('${raw['id']}')) raw,
      ];

  Future<void> _openPay() async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final picks = _selectedRows;
    if (picks.isEmpty) return;
    final pids = picks.map((b) => '${b['providerId']}').toSet();
    if (pids.length != 1) {
      adminSnack(context, '${c['bulkPayNeedSamePro']}', error: true);
      return;
    }
    
    final earn = picks.fold<int>(0, (n, b) => n + _n(b['providerEarning']));
    final clientTotal = picks.fold<int>(0, (n, b) => n + _n(b['totalPiastres']));
    final provider = picks.first['provider'] as Map?;
    final firstName = locName(provider?['firstName'], lang);
    final phone = '${provider?['phone'] ?? ''}';
    final proName = firstName.isNotEmpty ? firstName : (phone.isNotEmpty ? phone : 'Provider ${picks.first['providerId']}');
    
    final result = await showOpsBulkSettle(
      context,
      title: '${c['bulkPayTitle']}',
      providerLabel: proName,
      visitCount: picks.length,
      clientTotalPiastres: clientTotal,
      providerGrossPiastres: earn,
      lang: lang,
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      confirmLabel: '${c['settleSend']}',
    );
    
    if (result != null) {
      try {
        final bytes = await result.receipt.readAsBytes();
        final r = await staffApi.postMultipart(
          '/admin/bookings/bulk-pay',
          fields: {
            'bookingIds': picks.map((b) => '${b['id']}').join(','),
            if (result.note.isNotEmpty) 'note': result.note,
          },
          fileField: 'receipt',
          bytes: bytes,
          filename: result.receipt.name.isNotEmpty ? result.receipt.name : 'receipt.jpg',
        );
        final wa = r['whatsAppSent'] == true;
        final link = '${r['link'] ?? ''}';
        opsToast(context, wa ? '${c['bulkPayDone']}' : '${c['bulkPayDoneNoWa']}');
        if (link.isNotEmpty) {
          await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
        }
        selected.clear();
        setState(() => bulkMode = false);
        await _load();
      } on ApiException catch (e) {
        opsToast(context, e.message, error: true);
      } catch (e) {
        opsToast(context, '$e', error: true);
      }
    }
  }

  Future<void> _exportCsv() async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      final query = {
        if (widget.live) 'live': '1',
        if (!widget.live && status.isNotEmpty) 'status': status,
        if (service.isNotEmpty) 'service': service,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (providerId.text.trim().isNotEmpty) 'providerId': providerId.text.trim(),
        if (unpaidOpsOnly) 'unpaidOps': '1',
        ...dateQuery(from, to),
      };
      final bytes = await staffApi.getBytes('/admin/bookings/export.csv', query: query);
      downloadBytes(bytes, 'oons-bookings.csv');
      if (mounted) opsToast(context, '${c['exportStarted']}');
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) opsToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final canPay = staffCan(role, 'payouts.write') && !widget.live;
    return AdminGate(
      perm: 'bookings.read',
      child: Column(
        children: [
          FilterWrap(title: '${widget.live ? c['liveNav'] : c['bookings']}', children: [
            if (widget.live) AdminStatusPill(label: '${c['autoRefresh']}', tone: AdminTone.ok),
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: _load, width: 200),
            if (!widget.live)
              FilterDrop<String>(
                value: status,
                items: [
                  DropdownMenuItem(value: '', child: Text('${c['all']}')),
                  for (final s in _bookingStatuses) DropdownMenuItem(value: s, child: Text(_st(c, s))),
                ],
                onChanged: (v) { setState(() => status = v ?? ''); _load(); },
              ),
            FilterDrop<String>(
              value: service,
              items: [
                DropdownMenuItem(value: '', child: Text('${c['filterService']}')),
                for (final s in _services) DropdownMenuItem(value: s, child: Text(_svc(c, s))),
              ],
              onChanged: (v) { setState(() => service = v ?? ''); _load(); },
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: providerId,
                decoration: InputDecoration(hintText: '${c['providerIdFilter']}', isDense: true),
                onSubmitted: (_) => _load(),
              ),
            ),
            DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: (d) { setState(() => from = d); _load(); }),
            DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: (d) { setState(() => to = d); _load(); }),
            if (!widget.live)
              FilterChip(
                label: Text('${c['unpaidOpsOnly']}'),
                selected: unpaidOpsOnly,
                onSelected: (v) { setState(() => unpaidOpsOnly = v); _load(); },
              ),
            FilterApply(label: '${c['apply']}', onTap: _load),
            FilterClear(label: '${c['clear']}', onTap: _clear),
            TextButton.icon(
              onPressed: busy ? null : _exportCsv,
              icon: const Icon(Icons.download, size: 16),
              label: Text('${c['exportCsv']}'),
            ),
          ]),
          if (canPay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (bulkMode) ...[
                    TextButton(onPressed: _selectAllEligible, child: Text(lang == 'ar' ? 'حددي القابلة للدفع' : 'Select payable')),
                    TextButton(onPressed: selected.isEmpty ? null : () => setState(selected.clear), child: Text(lang == 'ar' ? 'إلغاء التحديد' : 'Clear selection')),
                    const Spacer(),
                    if (selected.isNotEmpty) Text('${selected.length} ${c['selectedN']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => setState(() => bulkMode = false),
                      child: Text('${c['exitBulkPay']}'),
                    ),
                  ] else ...[
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: busy ? null : () => setState(() => bulkMode = true),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text('${c['bulkPay']}'),
                    ),
                  ],
                ],
              ),
            ),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final b = rows[i] as Map;
                            final id = '${b['id']}';
                            final on = selected.contains(id);
                            final opsPaid = b['opsPaid'] == true;
                            return Material(
                              color: on ? T.actionSoft : T.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.go(AdminPaths.booking(id)),
                                onLongPress: canPay ? () => _toggle(id) : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: Row(
                                    children: [
                                      if (canPay && bulkMode)
                                        Checkbox(
                                          value: on,
                                          onChanged: (_) => _toggle(id),
                                        ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('${b['ref'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(width: 8),
                                          AdminStatusPill(label: _st(c, '${b['status'] ?? ''}'), tone: AdminTone.neutral),
                                          if (opsPaid) ...[
                                            const SizedBox(width: 6),
                                            AdminStatusPill(label: '${c['opsPaid']}', tone: AdminTone.ok),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_slot(b['slotStart'], lang)} · ${locName((b['provider'] is Map ? (b['provider'] as Map)['firstName'] : null), lang)} · ${money(_n(b['total']), lang)}'
                                        '${_n(b['providerEarning']) > 0 ? ' · ${c['colEarn']} ${money(_n(b['providerEarning']), lang)}' : ''}',
                                        style: const TextStyle(fontSize: 12.5, color: T.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                        ),
                      if (bulkMode && selected.isNotEmpty)
                        OpsBulkBar(
                          count: selected.length,
                          grossLabel: money(_selectedRows.fold<int>(0, (n, b) => n + _n(b['providerEarning'])), lang),
                          onClear: () => setState(() => selected.clear()),
                          onSettle: _openPay,
                          busy: busy,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminBookingDetailScreen extends ConsumerStatefulWidget {
  const AdminBookingDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AdminBookingDetailScreen> createState() => _AdminBookingDetailScreenState();
}

class _AdminBookingDetailScreenState extends ConsumerState<AdminBookingDetailScreen> {
  Map? b;
  String? err;
  String force = 'paid';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/bookings/${widget.id}');
      if (mounted) {
        final st = '${r['status'] ?? 'paid'}';
        setState(() {
          b = r;
          force = _bookingStatuses.contains(st) ? st : 'paid';
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resolve(String outcome) async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final ok = await showOpsConfirm(
      context,
      title: '${c['resolveDispute']}',
      body: '${c['resolveDisputeConfirm']}: $outcome',
      confirmLabel: '${c['resolve']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      roleLabel: _role(c, role),
      danger: true,
    );
    if (!ok) return;
    
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/bookings/${widget.id}/dispute/resolve', data: {'outcome': outcome});
      await _load();
      if (mounted) opsToast(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _force() async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final ok = await showOpsConfirm(
      context,
      title: '${c['forceStatus']}',
      body: '${c['forceStatusConfirm']}: ${_st(c, force)}',
      confirmLabel: '${c['applyStatus']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      roleLabel: _role(c, role),
      danger: true,
    );
    if (!ok) return;
    
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/bookings/${widget.id}/status', data: {'status': force});
      await _load();
      if (mounted) opsToast(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _addr(Map? addr, String lang) => addr == null ? '' : adminFormatAddress(addr, lang);

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    if (b == null) return AdminLoading(label: err ?? '${c['loading']}');
    final client = b!['client'] is Map ? b!['client'] as Map : null;
    final pro = b!['provider'] is Map ? b!['provider'] as Map : null;
    final addr = b!['address'] is Map ? b!['address'] as Map : null;
    final timeline = b!['timeline'] is List ? b!['timeline'] as List : const [];
    return AdminGate(
      perm: 'bookings.read',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          AdminPageHeader(
            title: '${b!['ref']}',
            subtitle: '${_st(c, '${b!['status']}')} · ${_esc(c, '${b!['escrow']}')} · ${money(_n(b!['total']), lang)}',
            onBack: () => context.pop(),
            onRefresh: _load,
            busy: busy,
          ),
          AdminSection(
            title: '${c['slot']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminInfoRow(label: '${c['slot']}', value: _slot(b!['slotStart'], lang)),
                AdminInfoRow(label: '${c['duration']}', value: '${b!['durationMin'] ?? ''} ${c['minutes']}'),
                if (_n(b!['refundAmount']) > 0) AdminInfoRow(label: '${c['refundAmount']}', value: money(_n(b!['refundAmount']), lang)),
                if (b!['notes'] != null && '${b!['notes']}'.isNotEmpty) AdminInfoRow(label: '${c['bookingNotes']}', value: '${b!['notes']}'),
              ],
            ),
          ),
          if (addr != null && _addr(addr, lang).isNotEmpty)
            AdminSection(
              title: '${c['address']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_addr(addr, lang), style: const TextStyle(fontSize: 13, height: 1.45)),
                  if ((addr['lat'] as num?) != null && ((addr['lat'] as num?) ?? 0) != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AdminInfoRow(label: '${c['coordinates']}', value: '${addr['lat']}, ${addr['lng']}', mono: true),
                    ),
                ],
              ),
            ),
          if (b!['lineItems'] is List && (b!['lineItems'] as List).isNotEmpty)
            AdminSection(
              title: '${c['lineItems']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in b!['lineItems'] as List)
                    if (item is Map)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${locName(item['label'], lang)} · ${money(_n(item['amount']), lang)}', style: const TextStyle(fontSize: 13)),
                      ),
                ],
              ),
            ),
          AdminSection(
            title: '${c['payments']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paymentMethodLabel('${b!['paymentMethod'] ?? ''}', lang).isNotEmpty)
                  AdminInfoRow(label: '${c['paymentMethod']}', value: paymentMethodLabel('${b!['paymentMethod']}', lang))
                else if ('${b!['paymentMethod'] ?? ''}'.isNotEmpty)
                  AdminInfoRow(label: '${c['paymentMethod']}', value: '${b!['paymentMethod']}'),
                if ('${b!['fawryCode'] ?? ''}'.isNotEmpty) AdminInfoRow(label: 'Fawry', value: '${b!['fawryCode']}', mono: true),
                if (b!['providerAcceptedAt'] != null) AdminInfoRow(label: '${c['providerAccepted']}', value: _when(b!['providerAcceptedAt'])),
                if (b!['checkedOutAt'] != null) AdminInfoRow(label: '${c['st_completed']}', value: _when(b!['checkedOutAt'])),
                if ((b!['lastLat'] as num?) != null && ((b!['lastLat'] as num?) ?? 0) != 0)
                  AdminInfoRow(label: '${c['coordinates']}', value: '${b!['lastLat']}, ${b!['lastLng']}', mono: true),
                if (b!['sosAt'] != null) AdminInfoRow(label: 'SOS', value: '${_when(b!['sosAt'])} · ${b!['sosBy'] ?? ''}', mono: true),
              ],
            ),
          ),
          if (client != null)
            AdminSection(
              title: '${c['client']}',
              child: InkWell(
                onTap: () => context.go(AdminPaths.customer('${client['id']}')),
                child: Text('${locName(client['firstName'], lang)} · ${client['phone'] ?? ''} · ${areaName('${client['area'] ?? ''}', lang)}', style: const TextStyle(color: T.action)),
              ),
            ),
          if (pro != null)
            AdminSection(
              title: '${c['professional']}',
              child: InkWell(
                onTap: () => context.go(AdminPaths.provider('${pro['id']}')),
                child: Text('${locName(pro['firstName'], lang)} · ${pro['phone'] ?? ''} · ${_svc(c, '${pro['service'] ?? ''}')}', style: const TextStyle(color: T.action)),
              ),
            ),
          if (timeline.isNotEmpty)
            AdminSection(
              title: '${c['timeline']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final ev in timeline)
                    if (ev is Map)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${_when(ev['at'])} · ${(Copy.of(lang)['timeline'] as Map?)?['${ev['key']}'] ?? ev['key'] ?? ''}'),
                      ),
                ],
              ),
            ),
          if ('${b!['entryPhotoUrl'] ?? ''}'.isNotEmpty || _hasHandshake(b!))
            AdminSection(
              title: '${c['handshake']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ('${b!['entryPhotoUrl'] ?? ''}'.isNotEmpty)
                    AdminPhotoBlock(label: '${c['entryProof']}', url: '${b!['entryPhotoUrl']}', loader: staffApi.uploadBytes),
                  if (_validCoord(b!['handshakeClientLat'], b!['handshakeClientLng']))
                    AdminInfoRow(
                      label: '${c['client']}',
                      value: '${b!['handshakeClientLat']}, ${b!['handshakeClientLng']}${b!['handshakeClientAt'] != null ? ' · ${_when(b!['handshakeClientAt'])}' : ''}',
                      mono: true,
                    ),
                  if (_validCoord(b!['handshakeProLat'], b!['handshakeProLng']))
                    AdminInfoRow(
                      label: '${c['professional']}',
                      value: '${b!['handshakeProLat']}, ${b!['handshakeProLng']}',
                      mono: true,
                    ),
                ],
              ),
            ),
          if (err != null) AdminErrorBanner(message: err!),
          if ('${b!['status']}' == 'disputed' && staffCan(role, 'bookings.write'))
            AdminSection(
              title: '${c['openDisputes']}',
              child: Wrap(spacing: 8, children: [
                _Chip('${c['refund']}', false, busy ? null : () => _resolve('refund')),
                _Chip('${c['release']}', false, busy ? null : () => _resolve('release')),
                _Chip('${c['split']}', false, busy ? null : () => _resolve('split')),
              ]),
            ),
          if (staffCan(role, 'bookings.write'))
            AdminSection(
              title: '${c['forceStatus']}',
              child: adminCompact(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButton<String>(
                          value: force,
                          isExpanded: true,
                          items: [for (final s in _bookingStatuses) DropdownMenuItem(value: s, child: Text(_st(c, s)))],
                          onChanged: (v) => setState(() => force = v ?? force),
                        ),
                        const SizedBox(height: 8),
                        InkButton(label: '${c['applyStatus']}', onTap: _force, trailing: false, busy: busy),
                      ],
                    )
                  : Row(children: [
                      DropdownButton<String>(
                        value: force,
                        items: [for (final s in _bookingStatuses) DropdownMenuItem(value: s, child: Text(_st(c, s)))],
                        onChanged: (v) => setState(() => force = v ?? force),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 140, child: InkButton(label: '${c['applyStatus']}', onTap: _force, trailing: false, busy: busy)),
                    ]),
            ),
        ],
      ),
    );
  }
}

class AdminPayoutsScreen extends ConsumerStatefulWidget {
  const AdminPayoutsScreen({super.key});
  @override
  ConsumerState<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends ConsumerState<AdminPayoutsScreen> {
  List rows = [];
  final q = TextEditingController();
  String status = '';
  DateTime? from;
  DateTime? to;
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/payouts', query: {
        'limit': 80,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (status.isNotEmpty) 'status': status,
        ...dateQuery(from, to),
      });
      if (mounted) setState(() { rows = r['payouts'] as List? ?? []; err = null; });
    } catch (e) {
      if (mounted) setState(() { rows = []; err = '$e'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _clear() {
    q.clear();
    setState(() { status = ''; from = null; to = null; });
    _load();
  }

  Future<void> _act(String id, String op) async {
    final c = _copy(ref);
    final role = effectiveStaffRole(ref.read(staffSessionProvider));
    final ok = await showOpsConfirm(
      context,
      title: op == 'release' ? '${c['confirmReleaseTitle'] ?? c['release']}' : '${c['confirmHoldTitle'] ?? c['hold']}',
      body: op == 'release'
          ? '${c['confirmReleaseBody'] ?? 'Release this payout to the professional?'}'
          : '${c['confirmHoldBody'] ?? 'Hold this payout?'}',
      confirmLabel: op == 'release' ? '${c['release']}' : '${c['hold']}',
      roleLabel: _role(c, role),
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/payouts/$id/$op');
      await _load();
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final canWrite = staffCan(role, 'payouts.write');
    return AdminGate(
      perm: 'payouts.read',
      child: Column(
        children: [
          FilterWrap(title: '${c['payouts']}', children: [
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: busy ? null : _load),
            FilterDrop<String>(
              value: status,
              items: [
                DropdownMenuItem(value: '', child: Text('${c['all']}')),
                for (final s in _payoutStatuses) DropdownMenuItem(value: s, child: Text(_st(c, s))),
              ],
              onChanged: busy ? null : (v) { setState(() => status = v ?? ''); _load(); },
            ),
            DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: busy ? null : (d) { setState(() => from = d); _load(); }),
            DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: busy ? null : (d) { setState(() => to = d); _load(); }),
            FilterApply(label: '${c['apply']}', onTap: busy ? null : _load),
            FilterClear(label: '${c['clear']}', onTap: busy ? null : _clear),
          ]),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          Expanded(
            child: busy && rows.isEmpty
                ? AdminLoading(label: '${c['loading']}')
                : rows.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: T.line),
                    itemBuilder: (ctx, i) {
                      final p = rows[i] as Map;
                      return InkWell(
                        onTap: () {
                          final pid = '${p['providerId'] ?? ''}';
                          if (pid.isNotEmpty) context.go(AdminPaths.provider(pid));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${p['providerName'] ?? p['providerId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${_when(p['createdAt'])} · ${_st(c, '${p['status']}')} · ${p['method']}', style: const TextStyle(color: T.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(money(_n(p['amount']), lang), style: const TextStyle(fontFamily: T.mono, fontWeight: FontWeight.w700)),
                              if (canWrite && '${p['status']}' != 'paid') ...[
                                const SizedBox(width: 8),
                                TextButton(onPressed: busy ? null : () => _act('${p['id']}', 'hold'), child: Text(busy ? '${c['loading']}' : '${c['hold']}')),
                                TextButton(onPressed: busy ? null : () => _act('${p['id']}', 'release'), child: Text('${c['release']}')),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminLedgerScreen extends ConsumerStatefulWidget {
  const AdminLedgerScreen({super.key});
  @override
  ConsumerState<AdminLedgerScreen> createState() => _AdminLedgerScreenState();
}

class _AdminLedgerScreenState extends ConsumerState<AdminLedgerScreen> {
  List rows = [];
  final q = TextEditingController();
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/ledger', query: {
        'limit': 80,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
      });
      if (mounted) setState(() { rows = r['ledgers'] as List? ?? []; err = null; });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      final query = {
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
      };
      final bytes = await staffApi.getBytes('/admin/ledger/export.csv', query: query);
      downloadBytes(bytes, 'oons-ledger.csv');
      if (mounted) opsToast(context, '${c['exportStarted']}');
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } catch (e) {
      if (mounted) opsToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'ledger.read',
      child: Column(
        children: [
          FilterWrap(title: '${c['ledger']}', children: [
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: busy ? null : _load),
            FilterApply(label: '${c['apply']}', onTap: busy ? null : _load),
            FilterClear(label: '${c['clear']}', onTap: busy ? null : () { q.clear(); _load(); }),
            TextButton.icon(
              onPressed: busy ? null : _exportCsv,
              icon: const Icon(Icons.download, size: 16),
              label: Text('${c['exportCsv']}'),
            ),
          ]),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          Expanded(
            child: busy && rows.isEmpty
                ? AdminLoading(label: '${c['loading']}')
                : rows.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : _Table(
                    headers: ['${c['colName']}', '${c['colPhone']}', '${c['colService']}', '${c['colAvailable']}', '${c['colHeld']}'],
                    rows: [
                      for (final l in rows)
                        [
                          locName(l['firstName'], lang),
                          '${l['phone'] ?? ''}',
                          _svc(c, '${l['service'] ?? ''}'),
                          money(_n(l['available']), lang),
                          money(_n(l['held']), lang),
                        ],
                    ],
                    onTap: (i) {
                      final id = '${rows[i]['providerId'] ?? ''}';
                      if (id.isNotEmpty) context.go(AdminPaths.provider(id));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminStaffScreen extends ConsumerStatefulWidget {
  const AdminStaffScreen({super.key});
  @override
  ConsumerState<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends ConsumerState<AdminStaffScreen> {
  List rows = [];
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  String role = roleOps;
  String? err;
  bool busy = false;

  final q = TextEditingController();
  String roleFilter = '';
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/staff', query: {
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (roleFilter.isNotEmpty) 'role': roleFilter,
        ...dateQuery(from, to),
      });
      if (mounted) setState(() { rows = r['staff'] as List? ?? []; err = null; });
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _create() async {
    setState(() { err = null; busy = true; });
    try {
      await staffApi.post('/admin/staff', data: {
        'email': email.text.trim(),
        'password': password.text,
        'name': name.text.trim(),
        'staffRole': role,
      });
      email.clear();
      password.clear();
      name.clear();
      await _load();
    } on ApiException catch (e) {
      setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _patch(String id, Map data) async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/staff/$id', data: data);
      await _load();
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword(String id) async {
    final c = _copy(ref);
    final ctrl = TextEditingController();
    final ok = await showOpsForm(
      context,
      title: '${c['resetPassword']}',
      confirmLabel: '${c['save']}',
      cancelLabel: '${c['no']}',
      fields: [
        OpsFormField(
          label: '${c['newPassword']}',
          child: TextField(controller: ctrl, obscureText: true),
        ),
      ],
    );
    final pwd = ctrl.text;
    ctrl.dispose();
    if (ok && pwd.length >= 10) {
      await _patch(id, {'password': pwd});
    } else if (ok && mounted) {
      setState(() => err = 'Password must be at least 10 characters.');
    }
  }

  Future<void> _editAssignments(Map s) async {
    final c = _copy(ref);
    final clients = TextEditingController(text: (s['assignedClientIds'] as List? ?? []).join(', '));
    final pros = TextEditingController(text: (s['assignedProviderIds'] as List? ?? []).join(', '));
    final ok = await showOpsForm(
      context,
      title: '${c['assignments']}',
      confirmLabel: '${c['save']}',
      cancelLabel: '${c['no']}',
      fields: [
        OpsFormField(
          label: '${c['assignClients']}',
          child: TextField(controller: clients, textDirection: TextDirection.ltr),
        ),
        OpsFormField(
          label: '${c['assignProviders']}',
          child: TextField(controller: pros, textDirection: TextDirection.ltr),
        ),
      ],
    );
    if (ok) {
      await _patch('${s['id']}', {
        'assignedClientIds': clients.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'assignedProviderIds': pros.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      });
    }
    clients.dispose();
    pros.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final me = '${ref.watch(staffSessionProvider).staff?['email'] ?? ''}';
    return AdminGate(
      perm: 'staff.write',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          Row(
            children: [
              Expanded(child: Text('${c['staff']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () => context.go(AdminPaths.matrix),
                child: Text('${c['openMatrix']}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (busy) const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: busy ? null : _load),
            FilterDrop<String>(
              value: roleFilter,
              items: [
                DropdownMenuItem(value: '', child: Text('${c['role']}')),
                for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(_role(c, r))),
              ],
              onChanged: (v) { setState(() => roleFilter = v ?? ''); _load(); },
            ),
            DateBtn(label: '${c['from']}', value: from, lang: langOf(ref), onChanged: (d) { setState(() => from = d); _load(); }),
            DateBtn(label: '${c['to']}', value: to, lang: langOf(ref), onChanged: (d) { setState(() => to = d); _load(); }),
            FilterApply(label: '${c['apply']}', onTap: _load),
            FilterClear(label: '${c['clear']}', onTap: () { q.clear(); setState(() { roleFilter = ''; from = null; to = null; }); _load(); }),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: 220, child: TextField(controller: email, decoration: InputDecoration(labelText: '${c['email']}', isDense: true))),
            SizedBox(width: 180, child: TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: '${c['password']}', isDense: true))),
            SizedBox(width: 160, child: TextField(controller: name, decoration: InputDecoration(labelText: '${c['name']}', isDense: true))),
            DropdownButton<String>(
              value: role,
              items: [for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(_role(c, r)))],
              onChanged: (v) => setState(() => role = v ?? roleOps),
            ),
            SizedBox(width: 160, child: InkButton(label: '${c['createStaff']}', onTap: _create, trailing: false, busy: busy)),
          ]),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: T.danger))),
          const SizedBox(height: 24),
          for (final s in rows)
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.line))),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s['name'] ?? s['email']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${s['email']}', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: T.muted)),
                          ],
                        ),
                      ),
                      AdminStatusPill(label: _role(c, '${s['staffRole']}'), tone: AdminTone.neutral),
                      TextButton(
                        onPressed: () => context.go(AdminPaths.matrix),
                        child: Text('${c['matrix']}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _staffRoles.contains('${s['staffRole']}') ? '${s['staffRole']}' : roleOps,
                        items: [for (final r in _staffRoles) DropdownMenuItem(value: r, child: Text(_role(c, r)))],
                        onChanged: busy || '${s['email']}' == me ? null : (v) { if (v != null) _patch('${s['id']}', {'staffRole': v}); },
                      ),
                      Text(s['disabled'] == true ? '${c['yes']}' : '${c['no']}', style: const TextStyle(color: T.muted)),
                      if ('${s['email']}' != me) ...[
                        TextButton(onPressed: busy ? null : () => _patch('${s['id']}', {'disabled': s['disabled'] != true}), child: Text(s['disabled'] == true ? '${c['enable']}' : '${c['disable']}')),
                        TextButton(onPressed: busy ? null : () => _resetPassword('${s['id']}'), child: Text('${c['resetPassword']}')),
                        if ('${s['staffRole']}' == roleAm) TextButton(onPressed: busy ? null : () => _editAssignments(s), child: Text('${c['assignments']}')),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});
  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  Map data = {};
  final webhook = TextEditingController();
  final paymob = TextEditingController();
  final fawry = TextEditingController();
  final waiverUntil = TextEditingController();
  String? err;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    webhook.dispose();
    paymob.dispose();
    fawry.dispose();
    waiverUntil.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/settings/payments');
      if (mounted) {
        setState(() { data = r; err = null; });
        webhook.text = '${r['webhookUrl'] ?? ''}';
        final until = '${r['feeWaiverUntil'] ?? ''}';
        waiverUntil.text = until.length >= 10 ? until.substring(0, 10) : until;
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save({String? mode, bool? feeWaiverEnabled}) async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/settings/payments', data: {
        if (mode != null) 'mode': mode,
        'webhookUrl': webhook.text.trim(),
        if (paymob.text.trim().isNotEmpty) 'paymobKey': paymob.text.trim(),
        if (fawry.text.trim().isNotEmpty) 'fawryKey': fawry.text.trim(),
        if (feeWaiverEnabled != null) 'feeWaiverEnabled': feeWaiverEnabled,
        if (waiverUntil.text.trim().isNotEmpty) 'feeWaiverUntil': waiverUntil.text.trim(),
        if (feeWaiverEnabled == false) 'feeWaiverUntil': '',
      });
      await _load();
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final mode = '${data['mode'] ?? 'simulate'}';
    final liveAvail = data['liveAvailable'] == true;
    return AdminGate(
      perm: 'payments.settings',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          AdminPageHeader(title: '${c['payments']}', onRefresh: busy ? null : _load, busy: busy),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) AdminErrorBanner(message: err!, onRetry: _load),
          if (!liveAvail)
            AdminSection(
              title: '${c['livePay']}',
              child: Text('${c['liveWarn']}', style: const TextStyle(color: T.muted, fontSize: 13, height: 1.45)),
            ),
          AdminSection(
            title: '${c['payments']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Chip('${c['simulate']}', mode == 'simulate', busy ? null : () => _save(mode: 'simulate')),
                  _Chip('${c['livePay']}', mode == 'live', busy || !liveAvail ? null : () => _save(mode: 'live')),
                ]),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(langOf(ref) == 'ar' ? 'تجربة مجانية للرسوم' : 'Fee free trial'),
                  subtitle: Text(
                    data['feeWaiverActive'] == true
                        ? (langOf(ref) == 'ar' ? 'مفعّلة الآن — رسوم الثقة والعمولة = ٠' : 'Active now — trust fee & commission = 0')
                        : (langOf(ref) == 'ar' ? 'مطفية — كل الرسوم مطبّقة' : 'Off — all platform fees apply'),
                    style: const TextStyle(fontSize: 12, color: T.muted),
                  ),
                  value: data['feeWaiverEnabled'] == true,
                  onChanged: busy
                      ? null
                      : (v) => _save(feeWaiverEnabled: v),
                ),
                TextField(
                  controller: waiverUntil,
                  decoration: InputDecoration(
                    labelText: langOf(ref) == 'ar' ? 'نهاية التجربة (اختياري YYYY-MM-DD)' : 'Trial ends (optional YYYY-MM-DD)',
                    helperText: langOf(ref) == 'ar' ? 'فاضي = لحد ما تطفّيها من هنا' : 'Empty = until you turn it off here',
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy ? null : () => _save(feeWaiverEnabled: data['feeWaiverEnabled'] == true),
                    child: Text(langOf(ref) == 'ar' ? 'حفظ تاريخ النهاية' : 'Save end date'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: webhook, decoration: InputDecoration(labelText: '${c['webhook']}'), textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(controller: paymob, decoration: InputDecoration(
                  labelText: '${c['paymobKey']}',
                  helperText: data['paymobKeySet'] == true ? '${c['keySet']}' : '${c['keyMissing']}',
                ), textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(controller: fawry, decoration: InputDecoration(
                  labelText: '${c['fawryKey']}',
                  helperText: data['fawryKeySet'] == true ? '${c['keySet']}' : '${c['keyMissing']}',
                ), textDirection: TextDirection.ltr),
                const SizedBox(height: 16),
                _FillButton(label: '${c['save']}', onTap: busy ? null : () => _save(mode: mode), busy: busy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});
  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  List rows = [];
  final q = TextEditingController();
  DateTime? from;
  DateTime? to;
  int skip = 0;
  bool hasMore = true;
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) skip = 0;
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/audit', query: {
        'limit': 100,
        'skip': skip,
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        ...dateQuery(from, to),
      });
      final batch = r['logs'] as List? ?? [];
      if (mounted) {
        setState(() {
          if (more) {
            rows = [...rows, ...batch];
          } else {
            rows = batch;
          }
          skip = rows.length;
          hasMore = batch.length >= 100;
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'audit.read',
      child: Column(
        children: [
          FilterWrap(title: '${c['audit']}', children: [
            SearchField(controller: q, hint: '${c['searchHint']}', onSubmit: _load),
            DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: (d) { setState(() => from = d); _load(); }),
            DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: (d) { setState(() => to = d); _load(); }),
            FilterApply(label: '${c['apply']}', onTap: _load),
            FilterClear(label: '${c['clear']}', onTap: () { q.clear(); setState(() { from = null; to = null; }); _load(); }),
          ]),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          if (busy && rows.isEmpty) const Expanded(child: AdminLoading()),
          if (!busy || rows.isNotEmpty)
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                  : Column(
                      children: [
                        Expanded(
                          child: _Table(
                            headers: ['${c['colAt']}', '${c['colActor']}', '${c['colAction']}', '${c['colEntity']}'],
                            rows: [
                              for (final l in rows) [_when(l['at']), '${l['actor'] ?? ''}', '${l['action'] ?? ''}', '${l['entity'] ?? ''}'],
                            ],
                          ),
                        ),
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextButton(onPressed: busy ? null : () => _load(more: true), child: Text(busy ? '${c['loading']}' : '${c['loadMore']}')),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});
  @override
  ConsumerState<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  final q = TextEditingController();
  final first = TextEditingController();
  final last = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final notesQ = TextEditingController();
  List rows = [];
  String? err;
  bool busy = false;
  String area = '';
  String locale = '';
  String hasNotes = '';
  String visits = '';
  String service = '';
  bool advanced = false;
  DateTime? from;
  DateTime? to;
  DateTime? lastFrom;
  DateTime? lastTo;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    first.dispose();
    last.dispose();
    phone.dispose();
    address.dispose();
    notesQ.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/users', query: {
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (first.text.trim().isNotEmpty) 'first': first.text.trim(),
        if (last.text.trim().isNotEmpty) 'last': last.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
        if (notesQ.text.trim().isNotEmpty) 'notes': notesQ.text.trim(),
        if (area.isNotEmpty) 'area': area,
        if (locale.isNotEmpty) 'locale': locale,
        if (hasNotes.isNotEmpty) 'hasNotes': hasNotes,
        if (visits.isNotEmpty) 'visits': visits,
        if (service.isNotEmpty) 'service': service,
        ...dateQuery(from, to),
        if (lastFrom != null) 'lastFrom': ymd(lastFrom!),
        if (lastTo != null) 'lastTo': ymd(lastTo!),
        'limit': 80,
      });
      if (mounted) {
        setState(() {
          rows = r['users'] as List? ?? [];
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _clear() {
    q.clear();
    first.clear();
    last.clear();
    phone.clear();
    address.clear();
    notesQ.clear();
    setState(() {
      area = '';
      locale = '';
      hasNotes = '';
      visits = '';
      service = '';
      from = null;
      to = null;
      lastFrom = null;
      lastTo = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'users.read',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${c['customers']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    TextButton(
                      onPressed: () => setState(() => advanced = !advanced),
                      child: Text(advanced ? '${c['hideAdvanced']}' : '${c['advanced']}', style: const TextStyle(fontWeight: FontWeight.w700, color: T.action)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SearchField(controller: q, hint: '${c['customersHint']}', onSubmit: _load),
                  FilterDrop<String>(
                    value: area,
                    items: [
                      DropdownMenuItem(value: '', child: Text('${c['filterArea']}')),
                      for (final a in _areas) DropdownMenuItem(value: a, child: Text(areaName(a, lang))),
                    ],
                    onChanged: (v) { setState(() => area = v ?? ''); _load(); },
                  ),
                  DateBtn(label: '${c['from']}', value: from, lang: lang, onChanged: (d) { setState(() => from = d); _load(); }),
                  DateBtn(label: '${c['to']}', value: to, lang: lang, onChanged: (d) { setState(() => to = d); _load(); }),
                  FilterApply(label: '${c['apply']}', onTap: _load),
                  FilterClear(label: '${c['clear']}', onTap: _clear),
                ]),
                if (advanced) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: T.surface, border: Border.all(color: T.line, width: T.rule)),
                    child: Wrap(spacing: 10, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
                      LabeledField(label: '${c['firstName']}', controller: first, onSubmit: _load),
                      LabeledField(label: '${c['lastName']}', controller: last, onSubmit: _load),
                      LabeledField(label: '${c['colPhone']}', controller: phone, onSubmit: _load, forceLtr: true),
                      LabeledField(label: '${c['addressLine']}', controller: address, onSubmit: _load, width: 220),
                      LabeledField(label: '${c['notesContain']}', controller: notesQ, onSubmit: _load, width: 220),
                      LabeledDrop<String>(
                        label: '${c['localeFilter']}',
                        value: locale,
                        items: [
                          DropdownMenuItem(value: '', child: Text('${c['localeAny']}')),
                          DropdownMenuItem(value: 'ar', child: Text('${c['localeAr']}')),
                          DropdownMenuItem(value: 'en', child: Text('${c['localeEn']}')),
                        ],
                        onChanged: (v) { setState(() => locale = v ?? ''); _load(); },
                      ),
                      LabeledDrop<String>(
                        label: '${c['notesFilter']}',
                        value: hasNotes,
                        items: [
                          DropdownMenuItem(value: '', child: Text('${c['notesAny']}')),
                          DropdownMenuItem(value: '1', child: Text('${c['notesYes']}')),
                          DropdownMenuItem(value: '0', child: Text('${c['notesNo']}')),
                        ],
                        onChanged: (v) { setState(() => hasNotes = v ?? ''); _load(); },
                      ),
                      LabeledDrop<String>(
                        label: '${c['visitsFilter']}',
                        value: visits,
                        items: [
                          DropdownMenuItem(value: '', child: Text('${c['visitsAny']}')),
                          DropdownMenuItem(value: 'any', child: Text('${c['visitsYes']}')),
                          DropdownMenuItem(value: 'none', child: Text('${c['visitsNo']}')),
                          DropdownMenuItem(value: 'live', child: Text('${c['visitsLive']}')),
                          DropdownMenuItem(value: 'done', child: Text('${c['visitsDone']}')),
                          DropdownMenuItem(value: 'dispute', child: Text('${c['visitsDispute']}')),
                        ],
                        onChanged: (v) { setState(() => visits = v ?? ''); _load(); },
                      ),
                      LabeledDrop<String>(
                        label: '${c['filterService']}',
                        value: service,
                        items: [
                          DropdownMenuItem(value: '', child: Text('${c['filterService']}')),
                          for (final s in _services) DropdownMenuItem(value: s, child: Text(_svc(c, s))),
                        ],
                        onChanged: (v) { setState(() => service = v ?? ''); _load(); },
                      ),
                      DateBtn(label: '${c['lastFrom']}', value: lastFrom, lang: lang, onChanged: (d) { setState(() => lastFrom = d); _load(); }),
                      DateBtn(label: '${c['lastTo']}', value: lastTo, lang: lang, onChanged: (d) { setState(() => lastTo = d); _load(); }),
                    ]),
                  ),
                ],
                const SizedBox(height: 8),
                Text('${c['results']}: ${rows.length}', style: const TextStyle(color: T.muted, fontSize: 12)),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          Expanded(
            child: busy && rows.isEmpty
                ? AdminLoading(label: '${c['loading']}')
                : rows.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : _Table(
                    headers: ['${c['colName']}', '${c['colPhone']}', '${c['colArea']}', '${c['colBookings']}', '${c['colLast']}', '${c['colJoined']}'],
                    rows: [
                      for (final u in rows)
                        [
                          '${locName(u['firstName'], lang)} ${locName(u['lastName'], lang)}'.trim(),
                          '${u['phone']}',
                          areaName('${u['area']}', lang),
                          '${u['bookingCount'] ?? 0}',
                          u['lastSlot'] == null ? '—' : '${_st(c, '${u['lastStatus'] ?? ''}')} · ${_when(u['lastSlot'])}',
                          _when(u['createdAt']),
                        ],
                    ],
                    onTap: (i) => context.go(AdminPaths.customer('${rows[i]['id']}')),
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminPersonScreen extends ConsumerStatefulWidget {
  const AdminPersonScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AdminPersonScreen> createState() => _AdminPersonScreenState();
}

class _AdminPersonScreenState extends ConsumerState<AdminPersonScreen> {
  Map? user;
  List bookings = [];
  String? err;
  bool busy = false;
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/users/${widget.id}');
      if (mounted) {
        final u = r['user'] is Map ? r['user'] as Map : r;
        notes.text = '${u['staffNotes'] ?? ''}';
        setState(() {
          user = u;
          bookings = r['bookings'] as List? ?? [];
          err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/users/${widget.id}/notes', data: {'notes': notes.text});
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _impersonateUser() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.post('/admin/users/${widget.id}/impersonate');
      final token = '${r['accessToken'] ?? ''}';
      if (token.isEmpty) throw ApiException(0, 'No token returned.');
      
      final userName = '${locName(user!['firstName'], langOf(ref))} ${locName(user!['lastName'], langOf(ref))}'.trim();
      ref.read(staffSessionProvider.notifier).startImpersonation(
        id: widget.id,
        name: userName.isEmpty ? widget.id : userName,
        token: token,
        kind: 'customer',
      );
      
      if (mounted) {
        context.go(AdminPaths.impersonateCustomer(widget.id));
      }
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    if (user == null) return AdminLoading(label: err ?? '${c['loading']}');
    final addresses = user!['addresses'] is List ? user!['addresses'] as List : const [];
    final instructions = user!['instructions'] is List ? user!['instructions'] as List : const [];
    final savedIds = user!['savedIds'] is List ? user!['savedIds'] as List : const [];
    return AdminGate(
      perm: 'users.read',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          AdminPageHeader(
            title: '${locName(user!['firstName'], lang)} ${locName(user!['lastName'], lang)}'.trim(),
            subtitle: '${user!['phone'] ?? ''} · ${areaName('${user!['area'] ?? ''}', lang)}',
            onBack: () => context.pop(),
            onRefresh: _load,
            busy: busy,
          ),
          AdminSection(
            title: '${c['profile']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminInfoRow(label: '${c['locale']}', value: '${user!['locale'] ?? ''}'),
                AdminInfoRow(label: '${c['joined']}', value: _when(user!['createdAt'])),
                AdminInfoRow(label: '${c['rating']}', value: '${user!['rating'] ?? 0} · ${user!['reviewCount'] ?? 0} ${c['reviews']}'),
                AdminInfoRow(label: '${c['colBookings']}', value: '${bookings.length}'),
                if (savedIds.isNotEmpty) AdminInfoRow(label: '${c['savedPros']}', value: savedIds.join(', '), mono: true),
              ],
            ),
          ),
          if (addresses.isNotEmpty)
            AdminSection(
              title: '${c['addresses']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in addresses)
                    if (a is Map) AdminAddressTile(addr: a, lang: lang, labels: c),
                ],
              ),
            ),
          if (instructions.isNotEmpty)
            AdminSection(
              title: '${c['instructions']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in instructions)
                    if (i is Map) AdminInstructionTile(item: i),
                ],
              ),
            ),
          if (staffCan(role, 'notes.write'))
            AdminSection(
              title: '${c['notes']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: notes, maxLines: 3, decoration: InputDecoration(labelText: '${c['notes']}', border: const OutlineInputBorder())),
                  const SizedBox(height: 8),
                  _FillButton(label: '${c['saveNotes']}', onTap: busy ? null : _saveNotes, busy: busy),
                ],
              ),
            ),
          if (staffCan(role, 'users.impersonate'))
            AdminSection(
              title: '${c['impersonate']}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['impersonateUserHint']}', style: const TextStyle(fontSize: 12, color: T.muted, height: 1.45)),
                  const SizedBox(height: 10),
                  _FillButton(label: '${c['impersonateUser']}', onTap: busy ? null : _impersonateUser, busy: busy),
                ],
              ),
            ),
          AdminSection(
            title: '${c['bookings']}',
            child: bookings.isEmpty
                ? Text('${c['empty']}', style: const TextStyle(color: T.muted))
                : _Table(
                    headers: ['${c['colRef']}', '${c['colStatus']}', '${c['colTotal']}', '${c['colService']}'],
                    rows: [
                      for (final b in bookings)
                        ['${b['ref'] ?? ''}', _st(c, '${b['status'] ?? ''}'), money(_n(b['total']), lang), locName(b['serviceName'], lang)],
                    ],
                    onTap: (i) => context.go(AdminPaths.booking('${bookings[i]['id']}')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FillButton extends StatelessWidget {
  const _FillButton({required this.label, required this.onTap, this.filled = true, this.danger = false, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final btn = InkButton(
      label: label,
      onTap: onTap ?? () {},
      filled: filled,
      danger: danger,
      trailing: false,
      enabled: onTap != null,
      busy: busy,
    );
    if (adminCompact(context)) return btn;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(width: 180, child: btn),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.headers, required this.rows, this.onTap});
  final List<String> headers;
  final List<List<String>> rows;
  final void Function(int i)? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minW = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final tableW = minW < 640 ? 640.0 : minW;
        return Container(
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(T.radiusLg),
            border: Border.all(color: T.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableW,
            child: Table(
              columnWidths: {for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth()},
              border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFF0E9DE))),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF2EADF)),
                  children: [
                    for (final h in headers)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        child: Text(h, textAlign: TextAlign.start, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B5D69))),
                      ),
                  ],
                ),
                for (var i = 0; i < rows.length; i++)
                  TableRow(
                    children: [
                      for (final cell in rows[i])
                        Material(
                          color: T.surface,
                          child: InkWell(
                            onTap: onTap == null ? null : () => onTap!(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                              child: Text(cell, textAlign: TextAlign.start, style: const TextStyle(fontSize: 13, color: T.ink)),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  List rows = [];
  bool busy = false;
  String? err;
  String vertical = '';
  String statusFilter = ''; // '', active, locked_teaser

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/categories', query: {
        if (vertical.isNotEmpty) 'vertical': vertical,
        'teaser': '1',
      });
      setState(() {
        rows = ((r['categories'] as List?) ?? []);
        err = null;
      });
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List get _visible {
    if (statusFilter.isEmpty) return rows;
    return rows.where((raw) => '${(raw as Map)['status']}' == statusFilter).toList();
  }

  Future<void> _unlock(String v) async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final ok = await showOpsConfirm(
      context,
      title: '${c['unlockVertical']}',
      body: '${c['unlockConfirm']}\n\n${_svc(c, v)}\n${c['unlockHint']}',
      confirmLabel: '${c['unlockVertical']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      roleLabel: _role(c, role),
    );
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/categories/unlock/$v');
      opsToast(context, '${c['unlockVertical']}: ${_svc(c, v)}');
      await _load();
    } on ApiException catch (e) {
      opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggle(Map r) async {
    final id = '${r['id']}';
    final next = r['status'] == 'locked_teaser' ? 'active' : 'locked_teaser';
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/categories/$id', data: {'status': next});
      if (mounted) {
        final c = _copy(ref);
        adminSnack(context, next == 'active' ? '${c['catActivate']}' : '${c['catLock']}');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  Future<void> _createCategory() async {
    await _editCategory();
  }

  Future<void> _editCategory([Map? existing]) async {
    final c = _copy(ref);
    final en = TextEditingController(text: existing == null ? '' : locName(existing['name'], 'en'));
    final ar = TextEditingController(text: existing == null ? '' : locName(existing['name'], 'ar'));
    final slug = TextEditingController(text: '${existing?['slug'] ?? ''}');
    var vert = '${existing?['vertical'] ?? _services.first}';
    if (!_services.contains(vert)) vert = _services.first;
    var status = '${existing?['status'] ?? 'active'}';
    final ok = await showOpsPanel(
      context,
      title: '${existing == null ? c['createCategory'] : c['catEdit']}',
      confirmLabel: '${c['save'] ?? 'Save'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      bodyBuilder: (ctx, setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OpsFormField(label: '${c['enName']}', child: TextField(controller: en)),
          const SizedBox(height: 13),
          OpsFormField(label: '${c['arName']}', child: TextField(controller: ar)),
          const SizedBox(height: 13),
          OpsFormField(label: '${c['catSlug']}', child: TextField(controller: slug)),
          const SizedBox(height: 13),
          OpsFormField(
            label: '${c['vertical']}',
            child: DropdownButtonFormField<String>(
              value: vert,
              items: [for (final v in _services) DropdownMenuItem(value: v, child: Text(_svc(c, v)))],
              onChanged: (v) => setLocal(() => vert = v ?? vert),
            ),
          ),
          const SizedBox(height: 13),
          OpsFormField(
            label: '${c['status']}',
            child: DropdownButtonFormField<String>(
              value: status == 'locked_teaser' ? 'locked_teaser' : 'active',
              items: [
                DropdownMenuItem(value: 'active', child: Text('${c['catActive']}')),
                DropdownMenuItem(value: 'locked_teaser', child: Text('${c['catLocked']}')),
              ],
              onChanged: (v) => setLocal(() => status = v ?? 'active'),
            ),
          ),
        ],
      ),
    );
    final payload = {
      'name': {'en': en.text.trim(), 'ar': ar.text.trim()},
      'slug': slug.text.trim(),
      'vertical': vert,
      'status': status,
    };
    en.dispose();
    ar.dispose();
    slug.dispose();
    if (!ok) return;
    if ('${payload['slug']}'.isEmpty) {
      adminSnack(context, '${c['catSlug']}', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      if (existing == null) {
        await staffApi.post('/admin/categories', data: payload);
      } else {
        await staffApi.patch('/admin/categories/${existing['id']}', data: payload);
      }
      adminSnack(context, '${c['saved'] ?? 'Saved'}');
      await _load();
    } on ApiException catch (e) {
      adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reorder(Map r, int delta) async {
    final id = '${r['id']}';
    final idx = rows.indexWhere((e) => '${(e as Map)['id']}' == id);
    if (idx < 0) return;
    final next = idx + delta;
    if (next < 0 || next >= rows.length) return;
    final copy = List.of(rows);
    final item = copy.removeAt(idx);
    copy.insert(next, item);
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/categories/reorder', data: {
        'order': [
          for (var i = 0; i < copy.length; i++)
            {'id': '${(copy[i] as Map)['id']}', 'sortOrder': i},
        ],
      });
      await _load();
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final visible = _visible;
    final activeN = rows.where((r) => '${(r as Map)['status']}' == 'active').length;
    final lockedN = rows.where((r) => '${(r as Map)['status']}' == 'locked_teaser').length;
    final providersN = rows.fold<int>(0, (n, r) {
      final raw = (r as Map)['providerCount'];
      return n + (raw is num ? raw.toInt() : 0);
    });

    return AdminGate(
      perm: 'categories.write',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterWrap(title: '${c['categories']}', children: [
            _FillButton(label: '${c['createCategory']}', onTap: busy ? null : _createCategory, busy: busy),
            _Chip('${c['all']}', vertical == '', () { setState(() => vertical = ''); _load(); }),
            for (final v in _services)
              _Chip(_svc(c, v), vertical == v, () { setState(() => vertical = v); _load(); }),
            _Chip('${c['catActive']}', statusFilter == 'active', () {
              setState(() => statusFilter = statusFilter == 'active' ? '' : 'active');
            }),
            _Chip('${c['catLocked']}', statusFilter == 'locked_teaser', () {
              setState(() => statusFilter = statusFilter == 'locked_teaser' ? '' : 'locked_teaser');
            }),
            FilterApply(label: '${c['apply']}', onTap: _load),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CatStat(label: '${c['catCount']}', value: '${rows.length}'),
                _CatStat(label: '${c['catActiveCount']}', value: '$activeN', tone: AdminTone.ok),
                _CatStat(label: '${c['catLockedCount']}', value: '$lockedN', tone: AdminTone.warn),
                _CatStat(label: '${c['catProvidersTotal']}', value: '$providersN', tone: AdminTone.info),
              ],
            ),
          ),
          AdminSection(
            title: '${c['unlockVertical']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['unlockHint']}', style: const TextStyle(fontSize: 13, color: T.muted, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _services
                      .map((v) => _FillButton(
                            label: '${c['unlockVertical']} · ${_svc(c, v)}',
                            onTap: busy ? null : () => _unlock(v),
                            filled: false,
                            busy: busy,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: T.danger))),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: T.line),
                    itemBuilder: (ctx, i) {
                      final r = visible[i] as Map;
                      final name = r['name'] is Map ? Loc.fromJson(r['name'] as Map).of(lang) : '${r['name'] ?? r['slug']}';
                      final locked = r['status'] == 'locked_teaser';
                      final count = (r['providerCount'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_svc(c, '${r['vertical'] ?? ''}')} · ${locked ? c['catLocked'] : c['catActive']} · $count ${c['providersBadge']}',
                                    style: const TextStyle(fontSize: 12, color: T.muted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '${c['catReorder']}',
                              onPressed: busy ? null : () => _reorder(r, -1),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                            IconButton(
                              tooltip: '${c['catReorder']}',
                              onPressed: busy ? null : () => _reorder(r, 1),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                            ),
                            TextButton(onPressed: busy ? null : () => _editCategory(r), child: Text('${c['catEdit']}')),
                            TextButton(onPressed: busy ? null : () => _toggle(r), child: Text(locked ? '${c['catActivate']}' : '${c['catLock']}')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminAreasScreen extends ConsumerStatefulWidget {
  const AdminAreasScreen({super.key});
  @override
  ConsumerState<AdminAreasScreen> createState() => _AdminAreasScreenState();
}

class _AdminAreasScreenState extends ConsumerState<AdminAreasScreen> {
  List rows = [];
  bool busy = false;
  String? err;
  String city = '';
  String statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/areas', query: {
        if (city.isNotEmpty) 'city': city,
        if (statusFilter.isNotEmpty) 'status': statusFilter,
      });
      setState(() {
        rows = ((r['areas'] as List?) ?? []);
        err = null;
      });
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<String> get _cities {
    final out = <String>{};
    for (final raw in rows) {
      final id = '${(raw as Map)['cityId'] ?? ''}';
      if (id.isNotEmpty) out.add(id);
    }
    final list = out.toList()..sort();
    return list;
  }

  Future<void> _unlock(String cityId) async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final role = ref.watch(staffSessionProvider).staffRole;
    final ok = await showOpsConfirm(
      context,
      title: '${c['unlockCity']}',
      body: '${c['unlockCityConfirm']}\n\n$cityId\n${c['unlockCityHint']}',
      confirmLabel: '${c['unlockCity']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
      roleLabel: _role(c, role),
    );
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/areas/unlock/$cityId');
      opsToast(context, '${c['unlockCity']}: $cityId');
      await _load();
    } on ApiException catch (e) {
      opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggle(Map r) async {
    final id = '${r['id']}';
    final next = r['status'] == 'locked_teaser' ? 'active' : 'locked_teaser';
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/areas/$id', data: {'status': next});
      if (mounted) {
        final c = _copy(ref);
        adminSnack(context, next == 'active' ? '${c['catActivate']}' : '${c['catLock']}');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editTravelFee(Map r) async {
    final c = _copy(ref);
    final fee = TextEditingController(text: '${(_n(r['travelFee']) / 100).toStringAsFixed(0)}');
    final ok = await showOpsPanel(
      context,
      title: '${c['travelFee'] ?? 'Travel fee'}',
      confirmLabel: '${c['save'] ?? 'Save'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      bodyBuilder: (ctx, setLocal) => OpsFormField(
        label: '${c['travelFee'] ?? 'Travel fee (EGP)'}',
        child: TextField(controller: fee, keyboardType: TextInputType.number),
      ),
    );
    final egp = int.tryParse(fee.text.trim()) ?? 0;
    fee.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.patch('/admin/areas/${r['id']}', data: {'travelFee': egp * 100});
      opsToast(context, '${c['saved'] ?? 'Saved'}');
      await _load();
    } on ApiException catch (e) {
      opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createArea() async {
    final c = _copy(ref);
    final slug = TextEditingController();
    final cityId = TextEditingController();
    final nameEn = TextEditingController();
    final nameAr = TextEditingController();
    final fee = TextEditingController(text: '0');
    final ok = await showOpsPanel(
      context,
      title: '${c['areaCreate'] ?? 'Add coverage area'}',
      confirmLabel: '${c['save'] ?? 'Save'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      bodyBuilder: (ctx, setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OpsFormField(label: 'slug', child: TextField(controller: slug)),
          const SizedBox(height: 10),
          OpsFormField(label: 'cityId', child: TextField(controller: cityId)),
          const SizedBox(height: 10),
          OpsFormField(label: 'name.en', child: TextField(controller: nameEn)),
          const SizedBox(height: 10),
          OpsFormField(label: 'name.ar', child: TextField(controller: nameAr)),
          const SizedBox(height: 10),
          OpsFormField(label: '${c['travelFee'] ?? 'Travel fee (EGP)'}', child: TextField(controller: fee, keyboardType: TextInputType.number)),
        ],
      ),
    );
    final payload = {
      'slug': slug.text.trim(),
      'cityId': cityId.text.trim(),
      'name': {'en': nameEn.text.trim(), 'ar': nameAr.text.trim()},
      'cityName': {'en': cityId.text.trim(), 'ar': cityId.text.trim()},
      'travelFee': (int.tryParse(fee.text.trim()) ?? 0) * 100,
      'status': 'locked_teaser',
    };
    slug.dispose();
    cityId.dispose();
    nameEn.dispose();
    nameAr.dispose();
    fee.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/areas', data: payload);
      opsToast(context, '${c['saved'] ?? 'Saved'}');
      await _load();
    } on ApiException catch (e) {
      opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    final cities = _cities;
    final activeN = rows.where((r) => '${(r as Map)['status']}' == 'active').length;
    final lockedN = rows.where((r) => '${(r as Map)['status']}' == 'locked_teaser').length;

    return AdminGate(
      perm: 'areas.write',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterWrap(title: '${c['areas']}', children: [
            _Chip('${c['all']}', city == '', () { setState(() => city = ''); _load(); }),
            for (final id in cities)
              _Chip(id, city == id, () { setState(() => city = id); _load(); }),
            _Chip('${c['catActive']}', statusFilter == 'active', () {
              setState(() => statusFilter = statusFilter == 'active' ? '' : 'active');
              _load();
            }),
            _Chip('${c['catLocked']}', statusFilter == 'locked_teaser', () {
              setState(() => statusFilter = statusFilter == 'locked_teaser' ? '' : 'locked_teaser');
              _load();
            }),
            FilterApply(label: '${c['apply']}', onTap: _load),
            FilterApply(label: '${c['areaCreate'] ?? 'Add area'}', onTap: busy ? () {} : _createArea),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CatStat(label: '${c['areas']}', value: '${rows.length}'),
                _CatStat(label: '${c['catActiveCount']}', value: '$activeN', tone: AdminTone.ok),
                _CatStat(label: '${c['catLockedCount']}', value: '$lockedN', tone: AdminTone.warn),
              ],
            ),
          ),
          AdminSection(
            title: '${c['unlockCity']}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['unlockCityHint']}', style: const TextStyle(fontSize: 13, color: T.muted, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cities
                      .map((id) => _FillButton(
                            label: '${c['unlockCity']} · $id',
                            onTap: busy ? null : () => _unlock(id),
                            filled: false,
                            busy: busy,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (err != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(err!, style: const TextStyle(color: T.danger))),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : _Table(
                    headers: [
                      '${c['areaCity']}',
                      '${c['areaName']}',
                      '${c['travelFee'] ?? 'Travel'}',
                      '${c['status']}',
                      lang == 'ar' ? 'إجراء' : 'Action',
                    ],
                    rows: [
                      for (final raw in rows)
                        () {
                          final r = raw as Map;
                          final cityName = r['cityName'] is Map ? Loc.fromJson(r['cityName'] as Map).of(lang) : '${r['cityId']}';
                          final name = r['name'] is Map ? Loc.fromJson(r['name'] as Map).of(lang) : '${r['name'] ?? r['slug']}';
                          final locked = r['status'] == 'locked_teaser';
                          return [
                            cityName,
                            name,
                            money(_n(r['travelFee']), lang),
                            locked ? '${c['catLocked']}' : '${c['catActive']}',
                            locked ? '${c['catActivate']}' : '${c['catLock']}',
                          ];
                        }(),
                    ],
                    onTap: (i) async {
                      final r = rows[i] as Map;
                      final choice = await showModalBottomSheet<String>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(r['status'] == 'locked_teaser' ? '${c['catActivate']}' : '${c['catLock']}'),
                                onTap: () => Navigator.pop(ctx, 'toggle'),
                              ),
                              ListTile(
                                title: Text('${c['travelFee'] ?? 'Travel fee'}'),
                                onTap: () => Navigator.pop(ctx, 'fee'),
                              ),
                              ListTile(
                                title: Text('${c['delete'] ?? 'Delete'}', style: const TextStyle(color: T.warm)),
                                onTap: () => Navigator.pop(ctx, 'delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (choice == 'toggle') await _toggle(r);
                      if (choice == 'fee') await _editTravelFee(r);
                      if (choice == 'delete') {
                        final ok = await showOpsConfirm(
                          context,
                          title: '${c['delete'] ?? 'Delete'}',
                          body: '${r['slug'] ?? r['id']}',
                          confirmLabel: '${c['delete'] ?? 'Delete'}',
                          cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
                          danger: true,
                        );
                        if (!ok) return;
                        setState(() => busy = true);
                        try {
                          await staffApi.delete('/admin/areas/${r['id']}');
                          opsToast(context, '${c['saved'] ?? 'Saved'}');
                          await _load();
                        } on ApiException catch (e) {
                          opsToast(context, e.message, error: true);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CatStat extends StatelessWidget {
  const _CatStat({required this.label, required this.value, this.tone = AdminTone.neutral});
  final String label;
  final String value;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AdminTone.ok => T.trust,
      AdminTone.warn => T.pending,
      AdminTone.bad => T.warmInk,
      AdminTone.info => T.blueInk,
      AdminTone.neutral || AdminTone.plum => T.ink,
    };
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusLg),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: T.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class AdminCategoryRequestsScreen extends ConsumerStatefulWidget {
  const AdminCategoryRequestsScreen({super.key});
  @override
  ConsumerState<AdminCategoryRequestsScreen> createState() => _AdminCategoryRequestsScreenState();
}

class _AdminCategoryRequestsScreenState extends ConsumerState<AdminCategoryRequestsScreen> {
  List rows = [];
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/provider-categories');
      setState(() {
        rows = ((r['requests'] as List?) ?? (r['data'] as List?) ?? []);
        err = null;
      });
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _decide(String id, bool approve) async {
    final c = _copy(ref);
    final note = TextEditingController();
    final ok = await showOpsForm(
      context,
      title: approve ? '${c['approve']}' : '${c['reject']}',
      confirmLabel: approve ? '${c['approve']}' : '${c['reject']}',
      fields: [
        OpsFormField(label: '${c['notes']}', child: TextField(controller: note)),
      ],
    );
    if (!ok) return;
    setState(() => busy = true);
    try {
      final path = approve ? '/admin/provider-categories/$id/approve' : '/admin/provider-categories/$id/reject';
      await staffApi.post(path, data: {'note': note.text.trim()});
      adminSnack(context, approve ? '${c['approve']}' : '${c['reject']}');
      await _load();
    } on ApiException catch (e) {
      adminSnack(context, e.message, error: true);
    } finally {
      note.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'provider_categories.write',
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2),
          if (err != null) Padding(padding: const EdgeInsets.all(16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          _Table(
            headers: ['${c['providers']}', '${c['categories']}', '${c['vertical']}', ''],
            rows: [
              for (final raw in rows)
                () {
                  final r = raw as Map;
                  final pname = r['providerName'] is Map ? Loc.fromJson(r['providerName'] as Map).of(lang) : '${r['providerName'] ?? r['providerId']}';
                  final cname = r['categoryName'] is Map ? Loc.fromJson(r['categoryName'] as Map).of(lang) : '${r['categoryName'] ?? r['categoryId']}';
                  return [pname, cname, '${r['vertical'] ?? ''}', '${c['approve']} / ${c['reject']}'];
                }(),
            ],
            onTap: (i) async {
              final id = '${(rows[i] as Map)['id']}';
              final role = effectiveStaffRole(ref.read(staffSessionProvider));
              final approve = await showOpsConfirm(
                context,
                title: '${c['categoryRequests']}',
                body: '${c['confirmApproveRequest'] ?? 'Approve this category request?'}',
                confirmLabel: '${c['approve']}',
                roleLabel: _role(c, role),
              );
              if (approve) {
                await _decide(id, true);
              } else {
                final reject = await showOpsConfirm(
                  context,
                  title: '${c['categoryRequests']}',
                  body: '${c['confirmRejectRequest'] ?? 'Reject this category request?'}',
                  confirmLabel: '${c['reject']}',
                  roleLabel: _role(c, role),
                  danger: true,
                );
                if (reject) await _decide(id, false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class AdminClaimsScreen extends ConsumerStatefulWidget {
  const AdminClaimsScreen({super.key});
  @override
  ConsumerState<AdminClaimsScreen> createState() => _AdminClaimsScreenState();
}

class _AdminClaimsScreenState extends ConsumerState<AdminClaimsScreen> {
  List rows = [];
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/claims');
      setState(() {
        rows = ((r['claims'] as List?) ?? (r['data'] as List?) ?? []);
        err = null;
      });
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resolve(String id) async {
    final c = _copy(ref);
    final lang = langOf(ref);
    final note = TextEditingController();
    final ok = await showOpsForm(
      context,
      title: '${c['resolve']}',
      fields: [
        OpsFormField(
          label: '${c['notes']}',
          child: TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Optional resolution note'),
          ),
        ),
      ],
      confirmLabel: '${c['resolve']}',
      cancelLabel: lang == 'ar' ? 'إلغاء' : 'Cancel',
    );
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/claims/$id/resolve', data: {'status': 'resolved', 'note': note.text.trim()});
      adminSnack(context, '${c['resolve']}');
      await _load();
    } on ApiException catch (e) {
      adminSnack(context, e.message, error: true);
    } finally {
      note.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    return AdminGate(
      perm: 'claims.read',
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2),
          if (err != null) Padding(padding: const EdgeInsets.all(16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          _Table(
            headers: ['ID', '${c['colStatus']}', 'Kind', ''],
            rows: [
              for (final raw in rows)
                () {
                  final r = raw as Map;
                  return ['${r['id'] ?? r['_id']}', '${r['status']}', '${r['kind']}', '${c['resolve']}'];
                }(),
            ],
            onTap: busy
                ? null
                : (i) => _resolve('${(rows[i] as Map)['id'] ?? (rows[i] as Map)['_id']}'),
          ),
        ],
      ),
    );
  }
}

class AdminCouponsScreen extends ConsumerStatefulWidget {
  const AdminCouponsScreen({super.key});
  @override
  ConsumerState<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends ConsumerState<AdminCouponsScreen> {
  List rows = [];
  bool busy = false;
  String? err;
  final q = TextEditingController();
  String kind = '';
  String active = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/coupons', query: {
        if (q.text.trim().isNotEmpty) 'q': q.text.trim(),
        if (kind.isNotEmpty) 'kind': kind,
        if (active.isNotEmpty) 'active': active,
      });
      setState(() {
        rows = ((r['coupons'] as List?) ?? []);
        err = null;
      });
    } catch (e) {
      setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _discountLabel(Map r, Map c) {
    final type = '${r['discountType']}';
    final amount = _n(r['amount']);
    if (type == 'percent') return '$amount%';
    return '${(amount / 100).toStringAsFixed(0)} EGP';
  }

  Future<void> _openEditor({Map? existing}) async {
    final c = _copy(ref);
    final canWrite = staffCan(effectiveStaffRole(ref.read(staffSessionProvider)), 'coupons.write');
    final code = TextEditingController(text: '${existing?['code'] ?? ''}');
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : ('${existing['discountType']}' == 'percent'
              ? '${_n(existing['amount'])}'
              : '${(_n(existing['amount']) / 100).toStringAsFixed(0)}'),
    );
    final maxDisc = TextEditingController(
      text: _n(existing?['maxDiscount']) > 0 ? '${(_n(existing?['maxDiscount']) / 100).toStringAsFixed(0)}' : '',
    );
    final minSvc = TextEditingController(
      text: _n(existing?['minService']) > 0 ? '${(_n(existing?['minService']) / 100).toStringAsFixed(0)}' : '',
    );
    final maxRed = TextEditingController(text: _n(existing?['maxRedemptions']) > 0 ? '${_n(existing?['maxRedemptions'])}' : '');
    final maxUser = TextEditingController(text: _n(existing?['maxPerUser']) > 0 ? '${_n(existing?['maxPerUser'])}' : '');
    final owner = TextEditingController(text: '${existing?['ownerProviderId'] ?? ''}');
    var discountType = '${existing?['discountType'] ?? 'percent'}';
    var couponKind = '${existing?['kind'] ?? 'platform'}';
    var isActive = existing == null ? true : existing['active'] == true;

    final ok = await showOpsPanel(
      context,
      title: '${existing == null ? c['couponCreate'] : c['couponEdit']}',
      confirmLabel: '${c['save'] ?? 'Save'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      bodyBuilder: (ctx, setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OpsFormField(label: '${c['couponCode']}', child: TextField(controller: code, enabled: canWrite)),
          const SizedBox(height: 13),
          OpsFormField(
            label: '${c['couponKind']}',
            child: DropdownButtonFormField<String>(
              value: couponKind,
              items: [
                DropdownMenuItem(value: 'platform', child: Text('${c['couponKindPlatform']}')),
                DropdownMenuItem(value: 'provider', child: Text('${c['couponKindProvider']}')),
              ],
              onChanged: canWrite ? (v) => setLocal(() => couponKind = v ?? 'platform') : null,
            ),
          ),
          if (couponKind == 'provider') ...[
            const SizedBox(height: 13),
            OpsFormField(label: '${c['couponOwnerProvider']}', child: TextField(controller: owner, enabled: canWrite)),
          ],
          const SizedBox(height: 13),
          OpsFormField(
            label: '${c['couponDiscount']}',
            child: DropdownButtonFormField<String>(
              value: discountType,
              items: [
                DropdownMenuItem(value: 'percent', child: Text('${c['couponPercent']}')),
                DropdownMenuItem(value: 'fixed', child: Text('${c['couponFixed']}')),
              ],
              onChanged: canWrite ? (v) => setLocal(() => discountType = v ?? 'percent') : null,
            ),
          ),
          const SizedBox(height: 13),
          OpsFormField(label: '${c['couponAmount']}', child: TextField(controller: amount, keyboardType: TextInputType.number, enabled: canWrite)),
          if (discountType == 'percent') ...[
            const SizedBox(height: 13),
            OpsFormField(label: '${c['couponMaxDiscount']}', child: TextField(controller: maxDisc, keyboardType: TextInputType.number, enabled: canWrite)),
          ],
          const SizedBox(height: 13),
          OpsFormField(label: '${c['couponMinService']}', child: TextField(controller: minSvc, keyboardType: TextInputType.number, enabled: canWrite)),
          const SizedBox(height: 13),
          OpsFormField(label: '${c['couponMaxRedemptions']}', child: TextField(controller: maxRed, keyboardType: TextInputType.number, enabled: canWrite)),
          const SizedBox(height: 13),
          OpsFormField(label: '${c['couponMaxPerUser']}', child: TextField(controller: maxUser, keyboardType: TextInputType.number, enabled: canWrite)),
          const SizedBox(height: 13),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${c['couponActive']}'),
            value: isActive,
            onChanged: canWrite ? (v) => setLocal(() => isActive = v) : null,
          ),
        ],
      ),
    );
    if (!ok || !canWrite) {
      code.dispose();
      amount.dispose();
      maxDisc.dispose();
      minSvc.dispose();
      maxRed.dispose();
      maxUser.dispose();
      owner.dispose();
      return;
    }
    final amtRaw = int.tryParse(amount.text.trim()) ?? 0;
    final payload = <String, dynamic>{
      'code': code.text.trim(),
      'kind': couponKind,
      'discountType': discountType,
      'amount': discountType == 'percent' ? amtRaw : amtRaw * 100,
      'maxDiscount': (int.tryParse(maxDisc.text.trim()) ?? 0) * 100,
      'minService': (int.tryParse(minSvc.text.trim()) ?? 0) * 100,
      'maxRedemptions': int.tryParse(maxRed.text.trim()) ?? 0,
      'maxPerUser': int.tryParse(maxUser.text.trim()) ?? 0,
      'active': isActive,
      if (couponKind == 'provider') 'ownerProviderId': owner.text.trim(),
    };
    code.dispose();
    amount.dispose();
    maxDisc.dispose();
    minSvc.dispose();
    maxRed.dispose();
    maxUser.dispose();
    owner.dispose();
    setState(() => busy = true);
    try {
      if (existing == null) {
        await staffApi.post('/admin/coupons', data: payload);
      } else {
        await staffApi.patch('/admin/coupons/${existing['id']}', data: payload);
      }
      adminSnack(context, '${c['saved'] ?? 'Saved'}');
      await _load();
    } on ApiException catch (e) {
      adminSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteCoupon(Map existing) async {
    final c = _copy(ref);
    final ok = await showOpsConfirm(
      context,
      title: '${c['couponDelete'] ?? 'Deactivate coupon'}',
      body: '${existing['code']}\n\n${c['couponDeleteConfirm'] ?? 'Deactivate this coupon?'}',
      confirmLabel: '${c['delete'] ?? 'Deactivate'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      danger: true,
    );
    if (!ok) return;
    setState(() => busy = true);
    try {
      await staffApi.delete('/admin/coupons/${existing['id']}');
      opsToast(context, '${c['saved'] ?? 'Saved'}');
      await _load();
    } on ApiException catch (e) {
      opsToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showRedemptions(Map existing) async {
    final c = _copy(ref);
    setState(() => busy = true);
    List rows = [];
    try {
      final r = await staffApi.get('/admin/coupons/${existing['id']}/redemptions');
      rows = (r['redemptions'] as List?) ?? [];
    } on ApiException catch (e) {
      if (mounted) opsToast(context, e.message, error: true);
      if (mounted) setState(() => busy = false);
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    await showOpsPanel(
      context,
      title: '${c['couponRedemptions'] ?? 'Redemptions'} • ${existing['code']}',
      confirmLabel: '${c['close'] ?? 'Close'}',
      cancelLabel: langOf(ref) == 'ar' ? 'إلغاء' : 'Cancel',
      bodyBuilder: (ctx, setLocal) => SizedBox(
        width: 420,
        height: 320,
        child: rows.isEmpty
            ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final row = rows[i] as Map;
                  return ListTile(
                    dense: true,
                    title: Text('${row['userId'] ?? row['clientId'] ?? '—'}', style: const TextStyle(fontFamily: T.mono, fontSize: 12)),
                    subtitle: Text('${row['createdAt'] ?? row['at'] ?? ''}'),
                    trailing: Text(money(_n(row['discount'] ?? row['amount']), langOf(ref))),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final canWrite = staffCan(effectiveStaffRole(ref.watch(staffSessionProvider)), 'coupons.write');
    return AdminGate(
      perm: 'coupons.read',
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: q,
                    decoration: InputDecoration(labelText: '${c['couponCode']}', isDense: true),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                DropdownButton<String>(
                  value: kind.isEmpty ? null : kind,
                  hint: Text('${c['couponKind']}'),
                  items: [
                    DropdownMenuItem(value: '', child: Text(langOf(ref) == 'ar' ? 'الكل' : 'All')),
                    DropdownMenuItem(value: 'platform', child: Text('${c['couponKindPlatform']}')),
                    DropdownMenuItem(value: 'provider', child: Text('${c['couponKindProvider']}')),
                  ],
                  onChanged: (v) {
                    setState(() => kind = v ?? '');
                    _load();
                  },
                ),
                DropdownButton<String>(
                  value: active.isEmpty ? null : active,
                  hint: Text('${c['couponActive']}'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All')),
                    DropdownMenuItem(value: 'true', child: Text('Active')),
                    DropdownMenuItem(value: 'false', child: Text('Off')),
                  ],
                  onChanged: (v) {
                    setState(() => active = v ?? '');
                    _load();
                  },
                ),
                TextButton(onPressed: _load, child: Text(langOf(ref) == 'ar' ? 'بحث' : 'Search')),
                if (canWrite) FilledButton(onPressed: () => _openEditor(), child: Text('${c['couponCreate']}')),
              ],
            ),
          ),
          if (err != null) Padding(padding: const EdgeInsets.all(16), child: AdminErrorBanner(message: err!, onRetry: _load)),
          Expanded(
            child: _Table(
              headers: [
                '${c['couponCode']}',
                '${c['couponKind']}',
                '${c['couponDiscount']}',
                '${c['couponRedeemed']}',
                '${c['couponActive']}',
                '${c['actions'] ?? 'Actions'}',
              ],
              rows: [
                for (final raw in rows)
                  () {
                    final r = raw as Map;
                    return [
                      '${r['code']}',
                      '${r['kind']}',
                      _discountLabel(r, c),
                      '${_n(r['redeemedCount'])}${_n(r['maxRedemptions']) > 0 ? '/${_n(r['maxRedemptions'])}' : ''}',
                      r['active'] == true ? '✓' : '—',
                      '⋯',
                    ];
                  }(),
              ],
              onTap: (i) async {
                final r = rows[i] as Map;
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(title: Text('${c['couponEdit'] ?? 'Edit'}'), onTap: () => Navigator.pop(ctx, 'edit')),
                        ListTile(title: Text('${c['couponRedemptions'] ?? 'Redemptions'}'), onTap: () => Navigator.pop(ctx, 'redemptions')),
                        if (canWrite)
                          ListTile(
                            title: Text('${c['couponDelete'] ?? 'Deactivate'}', style: const TextStyle(color: T.warm)),
                            onTap: () => Navigator.pop(ctx, 'delete'),
                          ),
                      ],
                    ),
                  ),
                );
                if (choice == 'edit') await _openEditor(existing: r);
                if (choice == 'redemptions') await _showRedemptions(r);
                if (choice == 'delete') await _deleteCoupon(r);
              },
            ),
          ),
        ],
      ),
    );
  }
}
