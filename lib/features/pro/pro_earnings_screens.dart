import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

String locName(dynamic raw, String lang) {
  if (raw is Map) {
    return Loc.fromJson(raw).of(lang);
  }
  final s = '$raw'.trim();
  if (s.startsWith('{') && s.contains('en')) {
    return Loc.fromJson(raw).of(lang);
  }
  return s;
}

class ProEarningsScreen extends ConsumerStatefulWidget {
  const ProEarningsScreen({super.key});
  @override
  ConsumerState<ProEarningsScreen> createState() => _ProEarningsScreenState();
}

class _ProEarningsScreenState extends ConsumerState<ProEarningsScreen> {
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> settlements = [];
  bool busy = false;
  // Object?, not String — friendlyError() needs the real exception (e.g. an
  // ApiException) to pick a specific message; stringifying it here first
  // (as this used to do) meant every failure on this screen showed the same
  // generic fallback text regardless of what actually went wrong.
  Object? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    try {
      final s = await repo.earningsSummary();
      final hs = await repo.settlements();
      if (!mounted) return;
      setState(() {
        summary = s;
        settlements = hs;
        err = null;
      });
    } catch (e) {
      if (mounted) setState(() => err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    final cadence = '${summary?['cadence'] ?? 'weekly'}';
    final pendingCadence = summary?['pendingCadence'] == null ? null : '${summary?['pendingCadence']}';
    final hero = (summary?['heroAmount'] as num?)?.toInt() ?? 0;
    final held = (summary?['heldAmount'] as num?)?.toInt() ?? 0;
    final disputed = (summary?['disputeAmount'] as num?)?.toInt() ?? 0;
    final visitN = (summary?['cycleVisitCount'] as num?)?.toInt() ?? 0;
    final nextSettle = DateTime.tryParse('${summary?['nextSettlementAt'] ?? ''}')?.toLocal();
    final periodStart = DateTime.tryParse('${summary?['periodStart'] ?? ''}')?.toLocal();
    final periodEnd = DateTime.tryParse('${summary?['periodEnd'] ?? ''}')?.toLocal();
    final cycleLines = ((summary?['cycleLines'] as List?) ?? []).cast<Map>();
    final cats = ((summary?['categories'] as List?) ?? []).cast<Map>();
    final totalComputed = hero + held + disputed;
    final emptyCycle = cycleLines.isEmpty;

    return ColoredBox(
      color: Pro.bg,
      child: RefreshIndicator(
        color: Pro.plum,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(child: Text('${p['earnings']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink))),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProSettlementsScreen())),
                    child: Text('${p['settlementHistory']} ←', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Pro.plum)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (summary?['feeWaived'] == true) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0E9),
                  borderRadius: BorderRadius.circular(Pro.rCard),
                  border: Border.all(color: const Color(0xFFB7CDB9)),
                ),
                child: Text('${p['feeWaiverBanner']}', style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: Pro.ink)),
              ),
              const SizedBox(height: 14),
            ],
            ProCard(
              color: Pro.plum,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['available']}', style: const TextStyle(fontSize: 11, color: Pro.plumPale)),
                  const SizedBox(height: 4),
                  Text(money(hero, lang), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: T.mono)),
                  if (periodStart != null && periodEnd != null)
                    Text(
                      '${DateFormat(lang == 'ar' ? 'd MMM' : 'd MMM', lang == 'ar' ? 'ar' : 'en').format(periodStart)} – ${DateFormat(lang == 'ar' ? 'd MMM' : 'd MMM', lang == 'ar' ? 'ar' : 'en').format(periodEnd)}',
                      style: const TextStyle(fontSize: 12, color: Pro.plumPale),
                    ),
                  const SizedBox(height: 10),
                  Text(_cadenceLabel(cadence, lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                  if (nextSettle != null)
                    Text(
                      '${p['nextSettlementAt']} ${_fmtDay(nextSettle, lang)}',
                      style: const TextStyle(fontSize: 12, color: Pro.plumPale),
                    ),
                ],
              ),
            ),
            if (held > 0) ...[
              const SizedBox(height: 10),
              ProCard(
                color: Pro.pendingBg,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['held48Full']}', style: const TextStyle(fontSize: 12, color: Pro.pendingInk, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(money(held, lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: T.mono, color: Pro.ink)),
                        ],
                      ),
                    ),
                    Text('؟ ${p['heldAfterVisit']}', style: const TextStyle(fontSize: 11, color: Pro.muted)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            ProSectionWithHelp(
              '${p['aboutMoney']}',
              help: '${Copy.of(lang)['svcMgmt']['tipHold']}',
            ),
            const SizedBox(height: 10),
            ProCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['withdrawTo']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
                        const SizedBox(height: 4),
                        Text(
                          () {
                            final me = ref.watch(sessionProvider).provider;
                            final handle = '${me?.payoutHandle ?? ''}'.trim();
                            final label = '${p['instapayWallet']}';
                            return handle.isEmpty ? label : '$label · $handle';
                          }(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Pro.ink),
                        ),
                      ],
                    ),
                  ),
                  Text('${p['editInAccount']}', style: const TextStyle(fontSize: 11, color: Pro.plum)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ProSectionLabel('${p['settlementCadence']}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _cadenceChip('weekly', cadence, lang)),
                const SizedBox(width: 8),
                Expanded(child: _cadenceChip('biweekly', cadence, lang)),
                const SizedBox(width: 8),
                Expanded(child: _cadenceChip('monthly', cadence, lang)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${p['cadenceNote']}', style: const TextStyle(fontSize: 11, color: Pro.muted, height: 1.45)),
            if (pendingCadence != null) ...[
              const SizedBox(height: 6),
              Text(
                lang == 'ar'
                    ? 'تغيير محفوظ: ${_cadenceLabel(cadence, lang)} ← ${_cadenceLabel(pendingCadence, lang)}'
                    : 'Pending: ${_cadenceLabel(cadence, lang)} → ${_cadenceLabel(pendingCadence, lang)}',
                style: const TextStyle(fontSize: 11, color: Pro.plum, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 18),
            ProSectionLabel('${p['cycleMovement']}'),
            const SizedBox(height: 8),
            if (emptyCycle)
              ProCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['emptyCycleTitle']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pro.ink)),
                    const SizedBox(height: 6),
                    Text('${p['emptyCycleHero']}', style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.45)),
                  ],
                ),
              )
            else ...[
              Text(_periodLabel(periodStart, periodEnd, visitN, lang), style: const TextStyle(fontSize: 12, color: Pro.muted)),
              const SizedBox(height: 8),
              ...cycleLines.map((e) => _cycleLine(e, lang)),
            ],
            const SizedBox(height: 16),
            ProSectionLabel('${p['byCategory']}'),
            const SizedBox(height: 8),
            ...cats.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(locName(c['name'] ?? c['key'], lang), style: const TextStyle(fontSize: 13, color: Pro.ink))),
                      Text(money((c['amount'] as num?)?.toInt() ?? 0, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: T.mono)),
                    ],
                  ),
                )),
            if (disputed > 0) ...[
              const SizedBox(height: 8),
              Text('${p['computedTotal']} ${money(hero, lang)} ${p['ofTotal']} ${money(totalComputed, lang)}',
                  style: const TextStyle(fontSize: 12, color: Pro.muted)),
            ],
            if (err != null) ...[
              const SizedBox(height: 12),
              Text(friendlyError(err!, lang), style: const TextStyle(color: Pro.danger)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cycleLine(Map row, String lang) {
    final st = '${row['status'] ?? ''}';
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    final when = DateTime.tryParse('${row['checkedOutAt'] ?? ''}')?.toLocal();
    final note = _settleNote(st, row, lang);
    final statusLabel = _settleStatusLabel(st, lang);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${locName(row['serviceName'], lang)} · ${row['clientName'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pro.ink)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(statusLabel + (note.isEmpty ? '' : ' $note'), style: const TextStyle(fontSize: 11, color: Pro.muted))),
                Text(money(amount, lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: T.mono)),
              ],
            ),
            if (when != null) Text(DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(when), style: const TextStyle(fontSize: 10, color: Pro.soft)),
          ],
        ),
      ),
    );
  }

  String _settleStatusLabel(String st, String lang) {
    final p = Copy.of(lang)['pro'] as Map;
    switch (st) {
      case 'ready':
        return '${p['readyForSettle']}';
      case 'held':
        return '${p['paidToHold']}';
      case 'dispute':
        return '${p['onHoldDispute']}';
      case 'processing':
        return '${p['processing']}';
      case 'settled':
        return '${p['settled']}';
      default:
        return st;
    }
  }

  String _settleNote(String st, Map row, String lang) {
    final p = Copy.of(lang)['pro'] as Map;
    if (st == 'held') {
      final r = DateTime.tryParse('${row['releasesAt'] ?? ''}')?.toLocal();
      if (r == null) return '';
      return '${p['holdEnds']} ${DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(r)}';
    }
    if (st == 'dispute') return '${p['excludedNow']}';
    return '';
  }

  Widget _cadenceChip(String value, String current, String lang) {
    final on = value == current;
    return InkWell(
      onTap: busy ? null : () => _confirmCadence(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Pro.plum : Pro.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Pro.line),
        ),
        child: Text(_cadenceLabel(value, lang), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : Pro.ink)),
      ),
    );
  }

  String _fmtDay(DateTime d, String lang) =>
      DateFormat(lang == 'ar' ? 'EEEE d MMMM' : 'EEEE d MMMM', lang == 'ar' ? 'ar' : 'en').format(d);

  String _cadenceLabel(String v, String lang) {
    if (v == 'biweekly') return lang == 'ar' ? 'كل أسبوعين' : 'Biweekly';
    if (v == 'monthly') return lang == 'ar' ? 'شهري' : 'Monthly';
    return lang == 'ar' ? 'أسبوعي' : 'Weekly';
  }

  String _periodLabel(DateTime? from, DateTime? to, int n, String lang) {
    if (from == null || to == null) return '';
    final end = to.subtract(const Duration(days: 1));
    final fmt = DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en');
    return '${fmt.format(from)} – ${fmt.format(end)} · ${lang == 'ar' ? _arDigit(n) : '$n'} ${lang == 'ar' ? 'زيارات' : 'visits'}';
  }

  Future<void> _confirmCadence(String next) async {
    if (summary == null) return;
    final lang = langOf(ref);
    final cur = '${summary?['cadence'] ?? 'weekly'}';
    if (next == cur) return;
    final nextAt = DateTime.tryParse('${summary?['nextSettlementAt'] ?? ''}')?.toLocal();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Pro.bg,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'ar'
                  ? 'تغيير دورة التسوية إلى ${_cadenceLabel(next, lang)}؟'
                  : 'Change settlement cadence to ${_cadenceLabel(next, lang)}?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink),
            ),
            const SizedBox(height: 8),
            Text('${Copy.of(lang)['pro']['cadenceNote']}', style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.45)),
            if (nextAt != null) ...[
              const SizedBox(height: 8),
              Text(
                lang == 'ar'
                    ? 'تسوية ${DateFormat('d MMM', 'ar').format(nextAt)} · ${_cadenceLabel(cur, lang)}'
                    : 'Settlement ${DateFormat('d MMM').format(nextAt)} · ${_cadenceLabel(cur, lang)}',
                style: const TextStyle(fontSize: 12, color: Pro.soft),
              ),
            ],
            const SizedBox(height: 14),
            ProPrimaryButton(label: lang == 'ar' ? 'احفظي التغيير' : 'Save change', onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 8),
            ProSoftButton(label: lang == 'ar' ? 'إلغاء' : 'Cancel', onTap: () => Navigator.pop(ctx, false)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await ref.read(repoProvider).setSettlementCadence(next);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          lang == 'ar' ? 'اتغيرت دورة التسوية.' : 'Settlement cadence updated.',
        )));
      }
    } catch (e) {
      if (mounted) setState(() => err = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _arDigit(int n) {
    const map = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => map[int.parse(c)]).join();
  }
}

class ProSettlementsScreen extends ConsumerStatefulWidget {
  const ProSettlementsScreen({super.key});
  @override
  ConsumerState<ProSettlementsScreen> createState() => _ProSettlementsScreenState();
}

class _ProSettlementsScreenState extends ConsumerState<ProSettlementsScreen> {
  String status = '';
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    rows = await ref.read(repoProvider).settlements(status: status.isEmpty ? null : status);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    return Scaffold(
      backgroundColor: Pro.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: Pro.plum,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Text(lang == 'ar' ? '→ رجوع' : '← Back', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pro.plum)),
              ),
              const SizedBox(height: 8),
              Text(lang == 'ar' ? 'سجل التسويات' : 'Settlement history', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _filterChip(lang == 'ar' ? 'الكل' : 'All', '', lang)),
                  const SizedBox(width: 8),
                  Expanded(child: _filterChip(lang == 'ar' ? 'قيد التنفيذ' : 'Processing', 'processing', lang)),
                  const SizedBox(width: 8),
                  Expanded(child: _filterChip(lang == 'ar' ? 'تمت المعالجة' : 'Settled', 'settled', lang)),
                ],
              ),
              const SizedBox(height: 12),
              ...rows.map((r) => _settlementCard(context, r, lang)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String v, String lang) {
    final on = status == v;
    return InkWell(
      onTap: () {
        setState(() => status = v);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? Pro.plum : Pro.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: Pro.line)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : Pro.ink)),
      ),
    );
  }

  Widget _settlementCard(BuildContext context, Map r, String lang) {
    final ps = DateTime.tryParse('${r['periodStart'] ?? ''}')?.toLocal();
    final pe = DateTime.tryParse('${r['periodEnd'] ?? ''}')?.toLocal().subtract(const Duration(days: 1));
    final state = '${r['status'] ?? ''}';
    final processing = state == 'processing';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProSettlementInvoiceScreen(id: '${r['id']}'))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ps != null && pe != null)
              Text('${DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(ps)} – ${DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(pe)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pro.ink)),
            const SizedBox(height: 4),
            Text('${_cadenceText('${r['cadence']}', lang)} · ${(r['visitCount'] as num?)?.toInt() ?? 0} ${lang == 'ar' ? 'زيارات' : 'visits'}',
                style: const TextStyle(fontSize: 11, color: Pro.muted)),
            const SizedBox(height: 8),
            _sumRow(lang == 'ar' ? 'الإجمالي' : 'Gross', money((r['gross'] as num?)?.toInt() ?? 0, lang)),
            _sumRow(lang == 'ar' ? 'رسوم المعالجة' : 'Processing fee', '-${money((r['fee'] as num?)?.toInt() ?? 0, lang)}'),
            _sumRow(processing ? (lang == 'ar' ? 'الصافي المحوّل' : 'Net transferred') : (lang == 'ar' ? 'الصافي المدفوع' : 'Net paid'),
                money((r['net'] as num?)?.toInt() ?? 0, lang), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String l, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(child: Text(l, style: TextStyle(fontSize: 11, color: bold ? Pro.ink : Pro.muted, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Pro.ink, fontFamily: T.mono)),
        ],
      ),
    );
  }

  String _cadenceText(String v, String lang) {
    if (v == 'biweekly') return lang == 'ar' ? 'كل أسبوعين' : 'Biweekly';
    if (v == 'monthly') return lang == 'ar' ? 'شهري' : 'Monthly';
    return lang == 'ar' ? 'أسبوعي' : 'Weekly';
  }
}

class ProSettlementInvoiceScreen extends ConsumerWidget {
  const ProSettlementInvoiceScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(repoProvider).settlement(id),
      builder: (context, s) {
        if (!s.hasData) return const Scaffold(backgroundColor: Pro.bg, body: Center(child: CircularProgressIndicator(color: Pro.plum)));
        final r = s.data!;
        final visits = ((r['visits'] as List?) ?? []).cast<Map>();
        final excluded = ((r['excluded'] as List?) ?? []).cast<Map>();
        return Scaffold(
          backgroundColor: Pro.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                InkWell(onTap: () => Navigator.pop(context), child: Text(lang == 'ar' ? '→ رجوع' : '← Back', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pro.plum))),
                const SizedBox(height: 8),
                Text(lang == 'ar' ? 'فاتورة التسوية' : 'Settlement invoice', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink)),
                const SizedBox(height: 10),
                Text('${r['invoiceRef'] ?? ''}', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Pro.muted)),
                const SizedBox(height: 14),
                ...visits.map((v) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${locName(v['serviceName'], lang)} · ${v['ref']}', style: const TextStyle(fontSize: 12, color: Pro.ink))),
                          Text(money((v['amount'] as num?)?.toInt() ?? 0, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                const Divider(height: 20, color: Pro.lineSoft),
                Row(children: [Expanded(child: Text(lang == 'ar' ? 'الصافي المدفوع' : 'Net paid', style: const TextStyle(fontWeight: FontWeight.w700))), Text(money((r['net'] as num?)?.toInt() ?? 0, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 16, fontWeight: FontWeight.w700))]),
                if (excluded.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(lang == 'ar' ? 'زيارات غير مشمولة في هذه الفترة' : 'Excluded visits this cycle', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pro.ink)),
                  const SizedBox(height: 8),
                  ...excluded.map((v) => Text('• ${locName(v['serviceName'], lang)} · ${v['ref']} · ${money((v['amount'] as num?)?.toInt() ?? 0, lang)}',
                      style: const TextStyle(fontSize: 11, color: Pro.muted))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
