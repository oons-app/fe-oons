import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/pro_chrome.dart';

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
        decoration: BoxDecoration(color: on ? Pro.plum : Pro.card, borderRadius: BorderRadius.zero, border: Border.all(color: Pro.line)),
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
