import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
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
import 'package:oons/core/pro_format.dart';
import 'package:oons/data/api.dart';

/// HTTP seam so the screen can be driven by a fake in widget tests.
abstract class SubsApi {
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query});
  Future<Map<String, dynamic>> post(String path, {Object? data});
  Future<Map<String, dynamic>> patch(String path, {Object? data});
}

class StaffSubsApi implements SubsApi {
  const StaffSubsApi();
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => staffClient.get(path, query: query);
  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => staffClient.post(path, data: data);
  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) => staffClient.patch(path, data: data);
}

/// One row of `GET /admin/subscriptions`, tolerant of the older nested shape.
class SubRow {
  const SubRow({
    required this.id,
    required this.customer,
    required this.provider,
    required this.plan,
    required this.used,
    required this.minimum,
    required this.status,
    required this.nextRenewal,
    required this.nextVisitId,
    this.hasReceipt = false,
  });
  final String id;
  final String customer;
  final String provider;
  final String plan;
  final int used;
  final int minimum;
  final String status;
  final String nextRenewal;
  final String nextVisitId;
  final bool hasReceipt;

  static SubRow from(Map<String, dynamic> r) {
    final sub = asMap(r['subscription']) ?? r;
    var status = '${r['status'] ?? sub['status'] ?? ''}';
    if (r['atRisk'] == true && status == 'active') status = 'at_risk';
    final nv = asMap(r['nextVisit']);
    return SubRow(
      id: idOf(sub),
      customer: '${r['customerName'] ?? ''}'.trim(),
      provider: '${r['providerName'] ?? ''}'.trim(),
      plan: '${r['planTitle'] ?? ''}'.trim(),
      used: asInt(r['used']),
      minimum: asInt(r['minimum']),
      status: status,
      nextRenewal: '${r['nextRenewal'] ?? ''}',
      nextVisitId: nv != null ? idOf(nv) : '${r['nextVisitId'] ?? ''}',
      hasReceipt: r['hasReceipt'] == true,
    );
  }
}

/// Whole pounds, or pounds and piastres when the amount is not round.
String exactEgp(int piastres, String lang) {
  final ar = lang == 'ar';
  final whole = piastres ~/ 100, rest = piastres % 100;
  final n = rest == 0 ? '$whole' : '$whole.${rest.toString().padLeft(2, '0')}';
  return ar ? '${digits(n, ar: true)} ج.م' : '$n EGP';
}

class SubscribersScreen extends ConsumerStatefulWidget {
  const SubscribersScreen({super.key, this.api = const StaffSubsApi()});
  final SubsApi api;
  @override
  ConsumerState<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends ConsumerState<SubscribersScreen> {
  String status = 'all';
  String q = '';
  List<SubRow> rows = [];
  int active = 0;
  int weekVisits = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic>? settings;

  static const _filters = [
    ('all', V2SubsCopy.filterAll),
    ('active', V2SubsCopy.filterActive),
    ('paused', V2SubsCopy.filterPaused),
    ('at_risk', V2SubsCopy.filterAtRisk),
  ];

  SubsApi get client => widget.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _lang => ref.read(localeCodeProvider);

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final wanted = status, wantedQ = q;
    if (settings == null && staffCan(ref.read(staffSessionProvider).effectiveRole, 'payments.settings')) {
      try {
        settings = await client.get('/admin/subscriptions/settings');
      } catch (_) {}
    }
    try {
      final r = await client.get('/admin/subscriptions', query: {'status': wanted, if (wantedQ.isNotEmpty) 'q': wantedQ});
      if (!mounted || wanted != status || wantedQ != q) return;
      final summary = asMap(r['summary']) ?? const <String, dynamic>{};
      setState(() {
        rows = [for (final m in asMapList(r['rows'] ?? r['subscriptions'])) SubRow.from(m)];
        active = asInt(summary['active'] ?? r['activeCount']);
        weekVisits = asInt(summary['visitsThisWeek'] ?? r['weekVisits']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message.isEmpty ? t(V2SubsCopy.failed, _lang) : e.message;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = t(V2SubsCopy.failed, _lang);
          loading = false;
        });
      }
    }
  }

  List<SubRow> get _visible {
    if (q.isEmpty) return rows;
    final n = q.toLowerCase();
    return rows.where((r) => '${r.customer} ${r.provider} ${r.plan} ${r.id}'.toLowerCase().contains(n)).toList();
  }

  int _count(String f) => f == 'all' ? rows.length : rows.where((r) => r.status == f).length;

  void _toast(String msg, {bool error = false}) {
    if (mounted) v2Toast(context, msg, error: error);
  }

  String _err(Object e) => e is ApiException && e.message.isNotEmpty ? e.message : t(V2SubsCopy.failed, _lang);

  // --- actions ---------------------------------------------------------------

  Future<void> _confirmPay(SubRow r) async {
    final lang = _lang;
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'تأكيد تحويل إنستاباي؟' : 'Confirm this InstaPay transfer?',
      body: lang == 'ar'
          ? 'هتتفعّل الباقة بعد ما تتأكدي إن التحويل وصل.'
          : 'The plan starts once you confirm the transfer arrived.',
      confirmLabel: lang == 'ar' ? 'تأكيد' : 'Confirm',
    );
    if (!ok || !mounted) return;
    try {
      await client.post('/admin/subscriptions/${r.id}/confirm-payment');
      _toast(lang == 'ar' ? 'اتأكد الدفع واتفعّلت الباقة.' : 'Payment confirmed. The plan is active.');
      _load();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _pause(SubRow r) async {
    final lang = _lang;
    final ok = await v2Confirm(
      context,
      title: t(V2SubsCopy.pauseTitle, lang),
      body: t(V2SubsCopy.pauseBody, lang),
      confirmLabel: t(V2SubsCopy.pause, lang),
    );
    if (!ok) return;
    try {
      await client.post('/admin/subscriptions/${r.id}/pause');
      _toast(t(V2SubsCopy.pauseDone, lang));
      _load();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  /// Cancel always goes through the server's refund preview first: she sees the
  /// exact amount that will go back before confirming.
  Future<void> _cancel(SubRow r) async {
    final lang = _lang;
    Map<String, dynamic> p;
    try {
      p = await client.get('/admin/subscriptions/${r.id}/cancel-preview');
    } catch (e) {
      _toast(_err(e), error: true);
      return;
    }
    if (!mounted) return;
    final total = asInt(p['totalPiastres']);
    final amount = exactEgp(total, lang);
    final ok = await v2Confirm(
      context,
      title: t(V2SubsCopy.cancelTitle, lang),
      body: V2SubsCopy.cancelPreview(
        amount: amount,
        visits: asInt(p['refundableVisits']),
        service: exactEgp(asInt(p['servicePiastres']), lang),
        fee: exactEgp(asInt(p['feePiastres']), lang),
        lang: lang,
      ),
      confirmLabel: lang == 'ar' ? 'إلغاء وردّ $amount' : 'Cancel and refund $amount',
      danger: true,
    );
    if (!ok) return;
    try {
      await client.post('/admin/subscriptions/${r.id}/cancel');
      _toast(t(V2SubsCopy.cancelDone, lang));
      _load();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _credit(SubRow r) async {
    final lang = _lang;
    final preset = asInt(settings?['providerCancelCreditEGP']);
    final amount = TextEditingController(text: preset > 0 ? '$preset' : '');
    final ok = await v2Form(
      context,
      title: t(V2SubsCopy.creditTitle, lang),
      confirmLabel: t(V2SubsCopy.confirm, lang),
      bodyBuilder: (ctx, setLocal) => V2FormField(
        label: t(V2SubsCopy.creditAmount, lang),
        child: TextField(key: const Key('credit-amount'), controller: amount, keyboardType: TextInputType.number),
      ),
      onValidate: () {
        if ((int.tryParse(toWesternDigits(amount.text).trim()) ?? 0) <= 0) {
          _toast(t(V2SubsCopy.creditInvalid, lang), error: true);
          return false;
        }
        return true;
      },
    );
    // Dialog-scoped controllers are not disposed here: the dialog is still
    // animating out and would rebuild against a disposed controller.
    final egp = int.tryParse(toWesternDigits(amount.text).trim()) ?? 0;
    if (!ok || egp <= 0) return;
    try {
      await client.post('/admin/subscriptions/${r.id}/credit', data: {'egp': egp});
      _toast(t(V2SubsCopy.creditDone, lang));
      _load();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _move(SubRow r) async {
    final lang = _lang;
    final vid = TextEditingController(text: r.nextVisitId);
    DateTime? date;
    TimeOfDay? time;
    String two(int n) => n.toString().padLeft(2, '0');
    final ok = await v2Form(
      context,
      title: t(V2SubsCopy.moveTitle, lang),
      confirmLabel: t(V2SubsCopy.confirm, lang),
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.nextVisitId.isEmpty) ...[
            V2FormField(label: t(V2SubsCopy.moveVisitId, lang), child: TextField(key: const Key('move-visit-id'), controller: vid)),
            const SizedBox(height: 12),
          ],
          V2FormField(
            label: t(V2SubsCopy.moveDate, lang),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: V2Btn(
                key: const Key('move-date'),
                label: date == null ? t(V2SubsCopy.movePick, lang) : '${date!.year}-${two(date!.month)}-${two(date!.day)}',
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: ctx, initialDate: date ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 120)));
                  if (d != null) setLocal(() => date = d);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: t(V2SubsCopy.moveTime, lang),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: V2Btn(
                key: const Key('move-time'),
                label: time == null ? t(V2SubsCopy.movePick, lang) : '${two(time!.hour)}:${two(time!.minute)}',
                onPressed: () async {
                  final tm = await showTimePicker(context: ctx, initialTime: time ?? const TimeOfDay(hour: 10, minute: 0));
                  if (tm != null) setLocal(() => time = tm);
                },
              ),
            ),
          ),
        ],
      ),
      onValidate: () {
        if (date == null || time == null || vid.text.trim().isEmpty) {
          _toast(t(V2SubsCopy.moveInvalid, lang), error: true);
          return false;
        }
        return true;
      },
    );
    final visit = vid.text.trim();
    if (!ok || date == null || time == null || visit.isEmpty) return;
    try {
      await client.post('/admin/subscriptions/visits/$visit/move', data: {
        'date': '${date!.year}-${two(date!.month)}-${two(date!.day)}',
        'slot': '${two(time!.hour)}:${two(time!.minute)}',
      });
      _toast(t(V2SubsCopy.moveDone, lang));
      _load();
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  Future<void> _openSettings() async {
    final lang = _lang;
    Map<String, dynamic> cfg;
    try {
      cfg = settings ?? await client.get('/admin/subscriptions/settings');
    } catch (e) {
      _toast(_err(e), error: true);
      return;
    }
    settings = cfg;
    if (!mounted) return;
    String lines(Object? v) => ((v as List?) ?? const []).join('\n');
    final customers = TextEditingController(text: lines(cfg['customerIds']));
    final providers = TextEditingController(text: lines(cfg['providerIds']));
    final deep = TextEditingController(text: lines(cfg['deepChecklist']));
    final maint = TextEditingController(text: lines(cfg['maintenanceChecklist']));
    var enabled = cfg['enabled'] == true;
    List<String> split(String s) => s.split(RegExp(r'[\s,]+')).where((e) => e.isNotEmpty).toList();
    List<String> perLine(String s) => s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final ok = await v2Form(
      context,
      title: t(V2SubsCopy.settingsTitle, lang),
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(t(V2SubsCopy.settingsEnabled, lang), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            Switch(key: const Key('settings-enabled'), activeThumbColor: Ops.plum, value: enabled, onChanged: (v) => setLocal(() => enabled = v)),
          ]),
          const SizedBox(height: 8),
          V2FormField(label: t(V2SubsCopy.settingsCustomers, lang), child: TextField(controller: customers, maxLines: 4)),
          const SizedBox(height: 12),
          V2FormField(label: t(V2SubsCopy.settingsProviders, lang), child: TextField(controller: providers, maxLines: 4)),
          const SizedBox(height: 12),
          Text(t(V2SubsCopy.settingsChecklists, lang), style: const TextStyle(fontSize: 12, color: Ops.muted, height: 1.5)),
          const SizedBox(height: 8),
          V2FormField(label: t(V2SubsCopy.settingsDeep, lang), child: TextField(controller: deep, maxLines: 4)),
          const SizedBox(height: 12),
          V2FormField(label: t(V2SubsCopy.settingsMaint, lang), child: TextField(controller: maint, maxLines: 4)),
        ],
      ),
    );
    final body = Map<String, dynamic>.from(cfg)
      ..['enabled'] = enabled
      ..['customerIds'] = split(customers.text)
      ..['providerIds'] = split(providers.text)
      ..['deepChecklist'] = perLine(deep.text)
      ..['maintenanceChecklist'] = perLine(maint.text);
    if (!ok) return;
    try {
      settings = await client.patch('/admin/subscriptions/settings', data: body);
      _toast(t(V2SubsCopy.settingsSaved, lang));
    } catch (e) {
      _toast(_err(e), error: true);
    }
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!(staffCan(role, 'bookings.read') || canSeeScreen(role, 'subscribers'))) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canWrite = staffCan(role, 'bookings.write');
    final canSettings = staffCan(role, 'payments.settings');
    ref.listen(v2QueryProvider, (_, n) {
      final next = n.trim();
      if (next == q) return;
      q = next;
      _load();
    });
    final visible = _visible;
    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: V2SubsCopy.results(visible.length, lang),
      emptyText: t(V2SubsCopy.empty, lang),
      actionsWidth: canWrite ? 360 : 8,
      strip: V2Card(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(V2SubsCopy.summary(active, weekVisits, lang), key: const Key('subs-summary'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Ops.ink)),
          const SizedBox(height: 6),
          Text(t(V2SubsCopy.provisional, lang), key: const Key('subs-provisional'), style: const TextStyle(fontSize: 12, color: Ops.goldInk, height: 1.5)),
        ]),
      ),
      filters: [
        for (final f in _filters)
          V2FilterChip(
            key: Key('subs-filter-${f.$1}'),
            label: t(f.$2, lang),
            count: _count(f.$1),
            selected: status == f.$1,
            onTap: () {
              if (status == f.$1) return;
              setState(() => status = f.$1);
              _load();
            },
          ),
      ],
      trailingActions: [
        if (canSettings) V2Btn(key: const Key('subs-settings'), label: t(V2SubsCopy.settings, lang), onPressed: _openSettings),
      ],
      columns: [
        V2Col(t(V2SubsCopy.colCustomer, lang), flex: 1.1),
        V2Col(t(V2SubsCopy.colProvider, lang), flex: 1.1),
        V2Col(t(V2SubsCopy.colPlan, lang), flex: 1.2),
        V2Col(t(V2SubsCopy.colVisits, lang), fixed: 150),
        V2Col(t(V2SubsCopy.colStatus, lang), fixed: 130),
        V2Col(t(V2SubsCopy.colRenewal, lang), fixed: 120),
      ],
      rows: [
        for (final r in visible)
          V2GridRow(
            cells: [
              Text(r.customer.isEmpty ? '—' : r.customer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(r.provider.isEmpty ? '—' : r.provider, style: const TextStyle(fontSize: 13)),
              Text(r.plan.isEmpty ? '—' : r.plan, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
              Text(V2SubsCopy.visits(r.used, r.minimum, lang), style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: V2StatusPill(label: V2SubsCopy.status(r.status, lang), tone: _tone(r.status)),
              ),
              Text(r.nextRenewal.length >= 10 ? digits(r.nextRenewal.substring(0, 10), ar: lang == 'ar') : '—', style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono)),
            ],
            actions: [
              if (canWrite && r.status == 'pending_payment' && r.hasReceipt)
                V2Btn(key: Key('confirm-${r.id}'), label: lang == 'ar' ? 'تأكيد إنستاباي' : 'Confirm InstaPay', onPressed: () => _confirmPay(r), size: V2BtnSize.row),
              if (canWrite && r.status == 'active')
                V2Btn(key: Key('pause-${r.id}'), label: t(V2SubsCopy.pause, lang), onPressed: () => _pause(r), size: V2BtnSize.row),
              if (canWrite && (r.status == 'active' || r.status == 'paused' || r.status == 'at_risk'))
                V2Btn(key: Key('cancel-${r.id}'), label: t(V2SubsCopy.cancel, lang), onPressed: () => _cancel(r), kind: V2BtnKind.danger, size: V2BtnSize.row),
              if (canWrite) V2Btn(key: Key('credit-${r.id}'), label: t(V2SubsCopy.credit, lang), onPressed: () => _credit(r), size: V2BtnSize.row),
              if (canWrite) V2Btn(key: Key('move-${r.id}'), label: t(V2SubsCopy.moveVisit, lang), onPressed: () => _move(r), size: V2BtnSize.row),
            
            ],
          ),
      ],
    );
  }

  V2Tone _tone(String s) => switch (s) {
        'active' => V2Tone.ok,
        'paused' || 'pending_payment' => V2Tone.warn,
        'at_risk' || 'payment_failed' || 'past_due' => V2Tone.bad,
        _ => V2Tone.neutral,
      };
}
