import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/features/subscribe/ar_eg.dart';
import 'package:oons/features/subscribe/prov_api.dart';
import 'package:oons/features/subscribe/wiz_widgets.dart';

// ===========================================================================
// Models
// ===========================================================================

/// Position seam so check-in can be tested without a device.
typedef LocationFetcher = Future<({double lat, double lng})> Function();

Future<({double lat, double lng})> deviceLocation() async {
  final p = await currentPosition();
  return (lat: p.latitude, lng: p.longitude);
}

Future<void> openLocationSettingsFor(String problem) async {
  if (problem == 'location_off') {
    await Geolocator.openLocationSettings();
  } else {
    await Geolocator.openAppSettings();
  }
}

enum CheckPhase { locked, locating, revealed, completing }

class VisitCheckInScreen extends StatefulWidget {
  const VisitCheckInScreen({
    super.key,
    required this.visitId,
    required this.area,
    required this.visitType,
    this.date = '',
    this.time = '',
    this.firstName = '',
    this.api = const LiveProApi(),
    this.now,
    this.locate = deviceLocation,
    this.openSettings = openLocationSettingsFor,
  });
  final String visitId;
  final String area;
  final String visitType;

  /// `YYYY-MM-DD` of the visit. Only today's visits can be started.
  final String date;
  final String time;
  final String firstName;
  final ProApi api;
  final DateTime Function()? now;
  final LocationFetcher locate;
  final Future<void> Function(String problem) openSettings;

  @override
  State<VisitCheckInScreen> createState() => _VisitCheckInScreenState();
}

class _VisitCheckInScreenState extends State<VisitCheckInScreen> {
  CheckPhase phase = CheckPhase.locked;
  String? full;
  List<Map<String, dynamic>> items = [];
  final checked = <String>{};
  String? error;
  String? geoProblem;

  DateTime get _now => (widget.now ?? DateTime.now)();
  bool get isToday => widget.date.isEmpty || widget.date == isoDate(dateOnly(_now));
  bool get revealed => full != null && phase != CheckPhase.locked && phase != CheckPhase.locating;
  bool get allChecked => items.isNotEmpty && items.every((it) => checked.contains('${it['id']}'));

  @override
  void dispose() {
    // The address never outlives this screen.
    full = null;
    items = [];
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (!isToday || phase == CheckPhase.locating) return;
    setState(() {
      error = null;
      geoProblem = null;
      phase = CheckPhase.locating;
    });
    ({double lat, double lng}) pos;
    try {
      pos = await widget.locate();
    } on GeoException catch (e) {
      if (!mounted) return;
      setState(() {
        phase = CheckPhase.locked;
        geoProblem = e.message;
        error = e.message == 'location_off'
            ? 'شغّلي خدمات الموقع من إعدادات الجهاز عشان نتأكد إنك عند البيت.'
            : 'محتاجين إذن الموقع عشان نتأكد إنك عند البيت.';
      });
      return;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        phase = CheckPhase.locked;
        error = 'موقعك اتأخر في الظهور. اتأكدي إن الـGPS شغّال وجرّبي تاني.';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        phase = CheckPhase.locked;
        error = 'ما قدرناش نحدد موقعك. جرّبي تاني.';
      });
      return;
    }
    try {
      final r = await widget.api.post('/pro/visits/${widget.visitId}/check-in', data: {'lat': pos.lat, 'lng': pos.lng});
      if (!mounted) return;
      setState(() {
        full = '${r['fullAddress'] ?? ''}';
        items = mapList(r['checklist']);
        checked.clear();
        error = null;
        phase = CheckPhase.revealed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = CheckPhase.locked;
        error = arError(e, fallback: 'ما قدرناش نبدأ الزيارة. جرّبي تاني.');
      });
    }
  }

  Future<void> _complete() async {
    if (!allChecked || phase == CheckPhase.completing) return;
    setState(() {
      error = null;
      phase = CheckPhase.completing;
    });
    try {
      await widget.api.post('/pro/visits/${widget.visitId}/complete', data: {'checkedItems': checked.toList()});
      if (!mounted) return;
      // Purge the address from memory; nothing is persisted.
      setState(() {
        full = null;
        items = [];
        checked.clear();
        phase = CheckPhase.locked;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتسجّلت الزيارة. العنوان اتمسح من جهازك.', style: ws(14, c: Colors.white))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = CheckPhase.revealed;
        error = arError(e, fallback: 'ما قدرناش نسجّل الزيارة. جرّبي تاني.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locating = phase == CheckPhase.locating;
    final deep = widget.visitType == 'deep';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Wiz.cream,
        appBar: AppBar(
          backgroundColor: Wiz.cream,
          foregroundColor: Wiz.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('زيارة النهارده', style: ws(18, w: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (widget.time.isNotEmpty || widget.firstName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(child: Text('${toArabicDigits(widget.time)} · ${widget.firstName}', style: ws(15, w: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: deep ? Wiz.plumTint : Wiz.chip,
                    child: Text(visitTypeLabel(widget.visitType), style: ws(12, w: FontWeight.w600, c: deep ? Wiz.plum : Wiz.body)),
                  ),
                ]),
              ),
            AddressRevealCard(revealed: revealed, area: widget.area, full: full),
            if (!isToday)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${(parseIso(widget.date) ?? DateTime.now()).isBefore(dateOnly(_now)) ? 'الزيارة دي كانت' : 'الزيارة دي'} ${niceDate(widget.date)}. بتقدري تبدئيها في يوم الزيارة بس.',
                  key: const Key('not-today'),
                  style: ws(13, c: Wiz.goldNote, h: 1.6),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: WizCard(
                  color: Wiz.dangerBg,
                  borderColor: Wiz.danger,
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(error!, key: const Key('checkin-error'), style: ws(13, c: Wiz.danger, h: 1.6)),
                    if (geoProblem != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: WizTextAction(key: const Key('open-settings'), label: 'افتحي الإعدادات', onTap: () => widget.openSettings(geoProblem!)),
                      ),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            if (!revealed)
              WizPrimaryButton(
                key: const Key('start-visit'),
                label: locating ? 'بنحدد موقعك…' : 'ابدئي الزيارة',
                background: Wiz.gold,
                enabled: isToday,
                busy: false,
                onTap: locating ? null : _checkIn,
              ),
            const SizedBox(height: 14),
            _checklist(),
            const SizedBox(height: 14),
            WizPrimaryButton(
              key: const Key('finish-visit'),
              label: 'خلّصت الزيارة',
              enabled: revealed && allChecked,
              busy: phase == CheckPhase.completing,
              onTap: _complete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklist() {
    if (!revealed) {
      return WizDashed(
        key: const Key('checklist-locked'),
        color: Wiz.disabled,
        background: Wiz.tile,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const OnsIcon('list', size: 20, color: Wiz.faint),
          const SizedBox(width: 10),
          Expanded(child: Text('قايمة مهام ${visitTypeLabel(widget.visitType)} هتفتح بعد ما تبدئي الزيارة.', style: ws(13, c: Wiz.muted, h: 1.6))),
        ]),
      );
    }
    // Group by room, keeping the server's order.
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final room = '${it['room'] ?? ''}'.trim();
      groups.putIfAbsent(room, () => []).add(it);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('قايمة المهام', style: ws(14, w: FontWeight.w700))),
        Text('${arNum(items.where((it) => checked.contains('${it['id']}')).length)} / ${arNum(items.length)}', key: const Key('checklist-progress'), style: ws(12, c: Wiz.soft, mono: true)),
      ]),
      const SizedBox(height: 8),
      for (final e in groups.entries) ...[
        if (e.key.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(e.key, style: ws(12, w: FontWeight.w700, c: Wiz.goldNote)),
          ),
        Container(
          decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
          child: Column(children: [
            for (final it in e.value) _taskRow(it),
          ]),
        ),
      ],
    ]);
  }

  Widget _taskRow(Map<String, dynamic> it) {
    final id = '${it['id']}';
    final on = checked.contains(id);
    final enabled = phase == CheckPhase.revealed;
    return InkWell(
      key: Key('task-$id'),
      onTap: enabled
          ? () => setState(() {
                on ? checked.remove(id) : checked.add(id);
              })
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Wiz.hair))),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? Wiz.plum : Wiz.surface, border: Border.all(color: on ? Wiz.plum : Wiz.faint, width: 1.5)),
            child: on ? const OnsIcon('check', size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${it['label'] ?? ''}', style: ws(14, c: on ? Wiz.muted : Wiz.ink, h: 1.4, deco: on ? TextDecoration.lineThrough : null))),
        ]),
      ),
    );
  }
}

/// Address card: only the area while locked; the full address slides in once
/// the provider has checked in.
class AddressRevealCard extends StatelessWidget {
  const AddressRevealCard({super.key, required this.revealed, required this.area, this.full});
  final bool revealed;
  final String area;
  final String? full;
  @override
  Widget build(BuildContext context) {
    final hasFull = revealed && (full ?? '').isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(color: revealed ? Wiz.goldTint : Wiz.surface, border: Border.all(color: revealed ? Wiz.gold : Wiz.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OnsIcon(revealed ? 'pin' : 'shield', size: 18, color: revealed ? Wiz.goldNote : Wiz.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(area.isEmpty ? 'المنطقة' : area, style: ws(15, w: FontWeight.w700))),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(position: Tween(begin: const Offset(0, -0.25), end: Offset.zero).animate(anim), child: child),
            ),
            child: hasFull
                ? Padding(
                    key: const Key('address-revealed'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(full!, style: ws(14, h: 1.6)),
                  )
                : Padding(
                    key: const Key('address-locked'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('العنوان بيظهر عند الوصول', style: ws(13, c: Wiz.goldNote)),
                  ),
          ),
        ),
      ]),
    );
  }
}

// ===========================================================================
// Subscribers roster (provider, read-only)
// ===========================================================================

class SubscriberRow {
  const SubscriberRow({required this.id, required this.firstName, required this.planTitle, required this.used, required this.minimum, required this.status});
  final String id;
  final String firstName;
  final String planTitle;
  final int used;
  final int minimum;
  final String status;

  static SubscriberRow from(Map<String, dynamic> r) {
    var first = '${r['firstName'] ?? ''}'.trim();
    if (first.isEmpty) first = '${r['name'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
    var title = '${r['planTitle'] ?? ''}'.trim();
    if (title.isEmpty && r['plan'] is List) {
      final parts = <String>[];
      for (final l in mapList(r['plan'])) {
        final nm = l['name'];
        final q = intOf(l['quantity']);
        final n = nm is Map ? '${nm['ar'] ?? ''}' : '${nm ?? ''}';
        if (q > 0 && n.isNotEmpty) parts.add('${arNum(q)} $n');
      }
      title = parts.join(' + ');
    }
    var status = '${r['status'] ?? ''}';
    if (r['atRisk'] == true && status == 'active') status = 'at_risk';
    return SubscriberRow(id: '${r['id'] ?? ''}', firstName: first, planTitle: title, used: intOf(r['used']), minimum: intOf(r['minimum']), status: status);
  }
}

class ProSubscribersScreen extends StatefulWidget {
  const ProSubscribersScreen({super.key, this.api = const LiveProApi()});
  final ProApi api;
  @override
  State<ProSubscribersScreen> createState() => _ProSubscribersScreenState();
}

class _ProSubscribersScreenState extends State<ProSubscribersScreen> {
  String status = 'all';
  bool loading = true;
  String? error;
  int active = 0;
  int weekVisits = 0;
  List<SubscriberRow> rows = [];

  static const _filters = [('all', 'الكل'), ('active', 'نشطة'), ('paused', 'متوقّفة'), ('at_risk', 'معرّضة للإلغاء')];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final wanted = status;
    try {
      final r = await widget.api.get('/pro/subscribers', query: <String, dynamic>{'status': wanted});
      if (!mounted || wanted != status) return;
      final summary = r['summary'] is Map ? Map<String, dynamic>.from(r['summary'] as Map) : const <String, dynamic>{};
      setState(() {
        rows = [for (final m in mapList(r['rows'] ?? r['subscribers'])) SubscriberRow.from(m)];
        active = intOf(summary['active'] ?? r['activeCount']);
        weekVisits = intOf(summary['visitsThisWeek'] ?? r['weekVisits']);
        loading = false;
      });
    } catch (e) {
      if (mounted && wanted == status) {
        setState(() {
          loading = false;
          error = arError(e, fallback: 'ما قدرناش نجيب المشتركات. جرّبي تاني.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Wiz.cream,
        appBar: AppBar(
          backgroundColor: Wiz.cream,
          foregroundColor: Wiz.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('المشتركات', style: ws(18, w: FontWeight.w700)),
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('${subscribersPhrase(active)} · ${arGrouped(weekVisits)} زيارة الأسبوع ده', key: const Key('roster-summary'), style: ws(13, w: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 6, runSpacing: 6, children: [for (final f in _filters) _filterChip(f.$1, f.$2)]),
          ),
          const SizedBox(height: 8),
          Expanded(child: _list()),
        ]),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final on = status == value;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: InkWell(
        key: Key('filter-$value'),
        onTap: () {
          if (status == value) return;
          status = value;
          _load();
        },
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            color: on ? Wiz.plum : Wiz.chip,
            child: ExcludeSemantics(child: Text(label, style: ws(13, w: on ? FontWeight.w700 : FontWeight.w400, c: on ? Colors.white : Wiz.body))),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    if (loading) return const Center(child: CircularProgressIndicator(color: Wiz.plum));
    if (error != null) return WizErrorState(message: error!, onRetry: _load);
    if (rows.isEmpty) {
      return RefreshIndicator(
        color: Wiz.plum,
        onRefresh: _load,
        child: ListView(children: [
          SizedBox(
            height: 360,
            child: WizEmptyState(
              icon: const OnsIcon('user', size: 22, color: Wiz.muted),
              title: status == 'all' ? 'لسه مفيش مشتركات' : 'مفيش مشتركات في الفلتر ده',
              body: status == 'all' ? 'أول ما عميلة تشترك في باقة من باقاتك هتظهر هنا.' : 'جرّبي فلتر تاني.',
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      color: Wiz.plum,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 10), child: _row(r))],
      ),
    );
  }

  Widget _row(SubscriberRow r) {
    final risk = r.status == 'at_risk';
    final live = r.status == 'active';
    final paused = r.status == 'paused';
    return Container(
      key: Key('sub-${r.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.firstName, style: ws(15, w: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: live ? Wiz.successBg : paused ? Wiz.pendingBg : risk ? Wiz.dangerBg : Wiz.chip,
            child: Text(subscriberStatusLabel(r.status), style: ws(11, w: FontWeight.w600, c: live ? Wiz.successFg : paused ? Wiz.pendingFg : risk ? Wiz.danger : Wiz.muted)),
          ),
        ]),
        if (r.planTitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.planTitle, style: ws(13, c: Wiz.body))),
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: ws(12, c: Wiz.soft), children: [
          TextSpan(text: usedOfMinimum(r.used, r.minimum), style: ws(12, w: FontWeight.w600, mono: true)),
          const TextSpan(text: ' زيارة في الدورة دي'),
        ])),
      ]),
    );
  }
}
