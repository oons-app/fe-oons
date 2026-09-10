import 'dart:async';
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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

const _statusOrder = [
  ('Confirmed', 'confirmed', Ops.barConfirmed),
  ('In progress', 'in_progress', Ops.barProgress),
  ('Completed', 'completed', Ops.barCompleted),
  ('Pending payment', 'pending', Ops.barPending),
  ('Cancelled by client', 'cancelled', Ops.barCancelled),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic> home = {};
  List<Map<String, dynamic>> live = [];
  List<Map<String, dynamic>> heat = [];
  int openRequests = 0;
  bool loading = true;
  String? error;
  int rangeDays = 14;
  Timer? _live;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _live = Timer.periodic(Ops.refreshEvery, (_) {
      if (!_hidden) _loadLive();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _hidden = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (!_hidden) _loadLive();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final now = DateTime.now();
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        staffClient.get('/admin/home', query: {
          'from': ymd(DateTime(now.year, now.month, now.day).subtract(Duration(days: rangeDays))),
          'to': ymd(DateTime(now.year, now.month, now.day)),
        }),
        staffClient.get('/admin/bookings', query: {'live': '1', 'limit': 20}).catchError((_) => <String, dynamic>{}),
        staffClient.get('/admin/heatmap').catchError((_) => <String, dynamic>{}),
        staffClient.get('/admin/provider-categories').catchError((_) => <String, dynamic>{}),
      ]);
      final h = results[0];
      final reqs = asMapList(results[3]['requests'] ?? results[3]['providerCategories'])
          .where((r) => '${r['status']}'.toLowerCase().contains('request'))
          .length;
      if (!mounted) return;
      setState(() {
        home = h;
        live = asMapList(results[1]['bookings']);
        heat = asMapList(results[2]['cells'] ?? results[2]['areas']);
        openRequests = reqs;
        loading = false;
      });
      _publishBadges();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _loadLive() async {
    try {
      final data = await staffClient.get('/admin/bookings', query: {'live': '1', 'limit': 20});
      if (mounted) setState(() => live = asMapList(data['bookings']));
    } catch (_) {}
  }

  void _publishBadges() {
    ref.read(v2NavBadgesProvider.notifier).state = {
      'providers': asInt(home['pendingProviders']),
      'payouts': asInt(home['pendingPayouts']),
      'claims': asInt(home['openDisputes']),
      'bookings': _followUp,
      'categoryRequests': openRequests,
    };
  }

  int get _followUp {
    var n = asInt(home['bookingsToday']);
    for (final s in asMapList(home['bookingsByStatus'])) {
      final k = '${s['status'] ?? ''}'.toLowerCase();
      if (k.contains('pending') || k.contains('cancel')) n += asInt(s['count']);
    }
    return n;
  }

  Future<void> _setRange(int d) async {
    setState(() => rangeDays = d);
    _load();
  }

  int _statusCount(String key) {
    for (final s in asMapList(home['bookingsByStatus'])) {
      final k = '${s['status'] ?? ''}'.toLowerCase();
      if (key == 'confirmed' && (k.contains('confirm') || k == 'paid')) return asInt(s['count']);
      if (key == 'pending' && k.contains('pending')) return asInt(s['count']);
      if (key == 'cancelled' && k.contains('cancel')) return asInt(s['count']);
      if (k == key || k.contains(key.replaceAll('_', ''))) return asInt(s['count']);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'home.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading && home.isEmpty) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null && home.isEmpty) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }

    final attention = <(String key, String label, int count, String unit, String hint, String route)>[
      ('providers', lang == 'ar' ? 'مهنيات بانتظار المراجعة' : 'Providers awaiting review', asInt(home['pendingProviders']),
          lang == 'ar' ? 'ملف' : 'profiles', lang == 'ar' ? 'افتح طابور المراجعة' : 'Open the review queue', '${V2Paths.providers}?status=pending'),
      ('payouts', lang == 'ar' ? 'سحوبات بانتظار الموافقة' : 'Withdrawals awaiting approval', asInt(home['pendingPayouts']),
          lang == 'ar' ? 'طلب' : 'requests', lang == 'ar' ? 'راجع السحوبات' : 'Review withdrawals', V2Paths.payouts),
      ('bookings', lang == 'ar' ? 'حجوزات تحتاج متابعة' : 'Bookings needing follow-up', _followUp,
          lang == 'ar' ? 'حجز' : 'bookings', lang == 'ar' ? 'راجع الحجوزات' : 'Check bookings', '${V2Paths.bookings}?status=pending'),
      ('claims', lang == 'ar' ? 'نزاعات مفتوحة' : 'Open disputes', asInt(home['openDisputes']),
          lang == 'ar' ? 'نزاع' : 'claims', lang == 'ar' ? 'افتح المطالبات' : 'Open claims', V2Paths.claims),
      ('categoryRequests', lang == 'ar' ? 'طلبات التخصص' : 'Category requests', openRequests,
          lang == 'ar' ? 'طلب' : 'requests', lang == 'ar' ? 'وافق أو ارفض' : 'Approve or reject', V2Paths.categoryRequests),
    ];

    final kpis = <(String, String, String)>[
      (lang == 'ar' ? 'حجوزات اليوم' : 'Bookings today', '${asInt(home['bookingsToday'])}', lang == 'ar' ? 'محجوزة لليوم' : 'booked for today'),
      (lang == 'ar' ? 'مباشر الآن' : 'Live now', '${live.isNotEmpty ? live.length : asInt(home['liveVisits'])}', lang == 'ar' ? 'زيارات نشطة' : 'active visits'),
      (lang == 'ar' ? 'العميلات' : 'Clients', '${asInt(home['totalUsers'])}', lang == 'ar' ? 'مسجّلة' : 'registered'),
      (lang == 'ar' ? 'مهنيات موثّقات' : 'Vetted pros', '${asInt(home['vettedProviders'])}', '${lang == 'ar' ? 'من' : 'of'} ${asInt(home['totalProviders'])}'),
      (lang == 'ar' ? 'سحوبات معلقة' : 'Pending payouts', '${asInt(home['pendingPayouts'])}', lang == 'ar' ? 'بانتظار الموافقة' : 'awaiting approval'),
      (lang == 'ar' ? 'كل الحجوزات' : 'All bookings', '${asInt(home['totalBookings'])}', lang == 'ar' ? 'مدى الحياة' : 'lifetime'),
    ];

    final smax = _statusOrder.map((s) => _statusCount(s.$2)).fold(1, (a, b) => b > a ? b : a);
    final days = asMapList(home['bookingsByDay']);
    final dmax = days.map((d) => asInt(d['count'])).fold(1, (a, b) => b > a ? b : a);
    final chartTotal = days.fold(0, (a, b) => a + asInt(b['count']));

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          // ---- Needs your attention -------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(lang == 'ar' ? 'يحتاج انتباهك' : 'Needs your attention',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(lang == 'ar' ? 'إذا كانت كلها صفراً، فاليوم صافٍ' : 'If these are all zero, the day is clear',
                    style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final cols = (box.maxWidth / 220).floor().clamp(1, 5);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final a in attention)
                  SizedBox(
                    width: (box.maxWidth - (cols - 1) * 12) / cols,
                    child: V2AttentionCard(
                      label: a.$2,
                      count: a.$3,
                      unit: a.$4,
                      hint: a.$5,
                      onTap: () => context.go(a.$6),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 18),

          // ---- Live visits | Overview + status bars --------------------
          _twoCol(
            left: _liveCard(lang),
            right: Column(
              children: [
                _overviewCard(lang, kpis),
                const SizedBox(height: Ops.gap),
                V2SectionCard(
                  title: lang == 'ar' ? 'الحجوزات حسب الحالة' : 'Bookings by status',
                  child: Column(
                    children: [
                      for (final s in _statusOrder)
                        V2MiniBar(
                          label: s.$1,
                          fraction: _statusCount(s.$2) / smax,
                          value: '${_statusCount(s.$2)}',
                          color: s.$3,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ---- Bookings by day | Supply vs demand ---------------------
          _twoCol(
            left: V2SectionCard(
              title: lang == 'ar' ? 'الحجوزات باليوم' : 'Bookings by day',
              subtitle: '$chartTotal ${lang == 'ar' ? 'في' : 'in'} $rangeDays ${lang == 'ar' ? 'يوم' : 'days'}',
              child: days.isEmpty
                  ? Text(lang == 'ar' ? 'لا بيانات' : 'No data', style: const TextStyle(color: Ops.muted, fontSize: 13))
                  : SizedBox(
                      height: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (var i = 0; i < days.length; i++)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.bottomCenter,
                                        heightFactor: (asInt(days[i]['count']) / dmax).clamp(0.02, 1),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: asInt(days[i]['count']) == dmax ? Ops.green : Ops.barConfirmed,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Expanded(
                                  child: Center(
                                    child: (i % (days.length > 14 ? 5 : 2) == 0)
                                        ? Text(_dayLabel('${days[i]['date']}'),
                                            style: const TextStyle(fontSize: 10, fontFamily: Ops.mono, color: Ops.faint))
                                        : const SizedBox(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            right: V2SectionCard(
              title: lang == 'ar' ? 'العرض مقابل الطلب' : 'Supply vs demand',
              subtitle: lang == 'ar' ? 'المهنيات النشطات مقابل الطلب المفتوح، حسب المنطقة' : 'Live pros against open demand, by area',
              trailing: [
                V2Btn.ghost(lang == 'ar' ? 'الخريطة الكاملة' : 'Full heatmap',
                    onPressed: () => context.go(V2Paths.heatmap), size: V2BtnSize.sm),
              ],
              child: heat.isEmpty
                  ? Text(lang == 'ar' ? 'لا بيانات' : 'No data', style: const TextStyle(color: Ops.muted, fontSize: 13))
                  : Column(
                      children: [
                        for (final cell in heat.take(4))
                          Builder(builder: (_) {
                            final demand = asInt(cell['demand']);
                            final supply = asInt(cell['supply']);
                            final fill = demand == 0 ? (supply > 0 ? 1.0 : 0.0) : supply / demand;
                            final under = cell['undersupplied'] == true || supply < demand;
                            final label = under || fill < 0.6 ? 'Undersupplied' : (fill < 1 ? 'Tight' : 'Healthy');
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(areaName('${cell['area'] ?? ''}', lang),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  SizedBox(
                                    width: 92,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(Ops.radiusPill),
                                      child: Container(
                                        height: 9,
                                        color: Ops.track,
                                        child: FractionallySizedBox(
                                          alignment: AlignmentDirectional.centerStart,
                                          widthFactor: fill.clamp(0, 1),
                                          child: Container(
                                            color: label == 'Healthy'
                                                ? Ops.barCompleted
                                                : (label == 'Tight' ? Ops.barPending : Ops.barCancelled),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  V2StatusPill.forLabel(label),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 940) {
        return Column(children: [left, const SizedBox(height: Ops.gap), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 14, child: left),
          const SizedBox(width: Ops.gap),
          Expanded(flex: 10, child: right),
        ],
      );
    });
  }

  Widget _overviewCard(String lang, List<(String, String, String)> kpis) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(lang == 'ar' ? 'نظرة عامة' : 'Overview',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              for (final d in const [7, 14, 30]) ...[
                V2Pill(label: '$d ${lang == 'ar' ? 'يوم' : 'days'}', on: rangeDays == d, onTap: () => _setRange(d)),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Ops.borderSoft, borderRadius: BorderRadius.circular(11)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < kpis.length; i += 2)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: V2KpiCell(label: kpis[i].$1, value: kpis[i].$2, note: kpis[i].$3)),
                      Container(width: 1, color: Ops.borderSoft),
                      Expanded(
                        child: i + 1 < kpis.length
                            ? V2KpiCell(label: kpis[i + 1].$1, value: kpis[i + 1].$2, note: kpis[i + 1].$3)
                            : const SizedBox(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveCard(String lang) {
    return Container(
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.borderSoft))),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Ops.green, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                Text(lang == 'ar' ? 'زيارات مباشرة' : 'Live visits',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(lang == 'ar' ? 'تحديث كل ٣٠ ث' : 'auto-refresh 30s',
                    style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono, color: Ops.mutedSoft)),
              ],
            ),
          ),
          if (live.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
              child: Column(
                children: [
                  Text(lang == 'ar' ? 'لا زيارات جارية' : 'No visits in progress',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(lang == 'ar' ? 'تُحدَّث هذه اللوحة كل ٣٠ ثانية' : 'This panel refreshes every 30 seconds',
                      style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
                ],
              ),
            )
          else
            for (var i = 0; i < live.length; i++)
              _liveRow(live[i], i, lang),
        ],
      ),
    );
  }

  Widget _liveRow(Map b, int i, String lang) {
    final pct = ((28 + i * 34) % 100) / 100.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V2StatusPill(label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
              Text(clientNameOf(b, lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(serviceLabel(b, lang), style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${providerNameOf(b, lang)}  ·  ${areaLabel(b['areaName'] ?? b['area'], lang)}  ·  ${bookingRef(b)}',
              style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Ops.radiusPill),
            child: Container(
              height: 6,
              color: Ops.track,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: pct.clamp(0.05, 1),
                child: Container(color: i.isEven ? Ops.green : Ops.barPending),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              V2Btn.primary(lang == 'ar' ? 'افتح الحجز' : 'Open booking',
                  onPressed: () => context.go(V2Paths.booking(idOf(b))), size: V2BtnSize.sm),
              const SizedBox(width: 7),
              if (staffCan(ref.read(staffSessionProvider).effectiveRole, 'claims.write'))
                V2Btn.danger(lang == 'ar' ? 'فتح مطالبة' : 'Raise claim', onPressed: () => _raiseClaim(b), size: V2BtnSize.sm),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _raiseClaim(Map b) async {
    final lang = ref.read(localeCodeProvider);
    var kind = 'damage';
    var note = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'فتح مطالبة' : 'Raise a claim',
      confirmLabel: lang == 'ar' ? 'فتح المطالبة' : 'Raise claim',
      bodyBuilder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang == 'ar'
                ? 'مطالبة على الحجز ${bookingRef(b)} للعميلة ${clientNameOf(b, lang)}.'
                : 'Opens a claim against booking ${bookingRef(b)} for ${clientNameOf(b, lang)}.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'النوع' : 'Type',
            child: DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'damage', child: Text('Damage')),
                DropdownMenuItem(value: 'theft', child: Text('Theft')),
                DropdownMenuItem(value: 'payout', child: Text('Payout dispute')),
              ],
              onChanged: (v) => kind = v ?? 'damage',
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'ملاحظة (مطلوبة)' : 'Note (required)', child: TextField(onChanged: (v) => note = v, maxLines: 3)),
        ],
      ),
      onValidate: () {
        if (note.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'اكتبي ملاحظة' : 'Add a note', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${idOf(b)}/claims', data: {'kind': kind, 'body': note.trim()});
      if (mounted) v2Toast(context, lang == 'ar' ? 'تم فتح المطالبة' : 'Claim opened');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }
}
