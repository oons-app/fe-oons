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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class ClientPaymentsScreen extends ConsumerStatefulWidget {
  const ClientPaymentsScreen({super.key});

  @override
  ConsumerState<ClientPaymentsScreen> createState() => _ClientPaymentsScreenState();
}

class _ClientPaymentsScreenState extends ConsumerState<ClientPaymentsScreen> {
  List<Map<String, dynamic>> payments = [];
  bool loading = true;
  String? error;
  String kind = '';
  String q = '';
  Timer? _debounce;

  static const _kinds = <(String key, String en, String ar)>[
    ('', 'All', 'الكل'),
    ('receipt', 'Receipts to confirm', 'إيصالات بانتظار التأكيد'),
    ('manual', 'InstaPay', 'إنستاباي'),
    ('card', 'Card', 'بطاقة'),
    ('wallet', 'Mobile wallet', 'محفظة'),
    ('failed', 'Failed', 'فشلت'),
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
      final data = await staffClient.get('/admin/client-payments', query: {
        if (kind.isNotEmpty) 'kind': kind,
        if (q.isNotEmpty) 'q': q,
      });
      setState(() {
        payments = asMapList(data['payments']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  String _kindLabel(String k, String lang) {
    switch (k) {
      case 'started':
        return lang == 'ar' ? 'بدأت' : 'Started';
      case 'receipt_uploaded':
        return lang == 'ar' ? 'رُفع الإيصال' : 'Receipt uploaded';
      case 'captured':
        return lang == 'ar' ? 'قُبض' : 'Captured';
      case 'confirmed':
        return lang == 'ar' ? 'أُكّد' : 'Confirmed';
      case 'failed':
        return lang == 'ar' ? 'فشل' : 'Failed';
      case 'refunded':
        return lang == 'ar' ? 'مُسترد' : 'Refunded';
      case 'audit':
        return lang == 'ar' ? 'تدقيق' : 'Audit';
      default:
        return k;
    }
  }

  Future<void> _openLogs(Map p) async {
    final lang = ref.read(localeCodeProvider);
    final logs = asMapList(p['logs']);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == 'ar' ? 'سجل المعاملة ${p['ref'] ?? ''}' : 'Transaction log ${p['ref'] ?? ''}'),
        content: SizedBox(
          width: 520,
          child: logs.isEmpty
              ? Text(lang == 'ar' ? 'لا سجلات بعد' : 'No logs yet')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final e = logs[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_kindLabel('${e['kind']}', lang),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text('${e['detail'] ?? e['actor'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        const SizedBox(height: 3),
                        Text(
                          '${e['actor'] ?? ''} · ${formatDay(e['at'], lang)}',
                          style: const TextStyle(fontSize: 11.5, color: Ops.muted, fontFamily: Ops.mono),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang == 'ar' ? 'إغلاق' : 'Close')),
        ],
      ),
    );
  }

  Future<void> _openReceipt(Map p) async {
    final lang = ref.read(localeCodeProvider);
    final url = '${p['paymentReceiptUrl'] ?? ''}';
    if (url.isEmpty) return;
    final bytes = await staffClient.uploadBytes(url);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      v2Toast(context, lang == 'ar' ? 'تعذر عرض الإيصال' : 'Could not load the screenshot', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
          child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'bookings.read') && !canSeeScreen(role, 'clientPayments')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
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
      resultLabel: '${payments.length} ${lang == 'ar' ? 'معاملة' : 'transactions'}',
      emptyText: lang == 'ar' ? 'لا معاملات من جانب العميلة بعد' : 'No client-side payments yet',
      actionsWidth: 168,
      filters: [
        for (final f in _kinds)
          V2FilterChip(
            label: lang == 'ar' ? f.$3 : f.$2,
            selected: kind == f.$1,
            onTap: () {
              setState(() => kind = f.$1);
              _load();
            },
          ),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'المرجع' : 'Ref', fixed: 140),
        V2Col(lang == 'ar' ? 'العميلة' : 'Customer', flex: 1),
        V2Col(lang == 'ar' ? 'الطريقة' : 'Method', fixed: 120),
        V2Col(lang == 'ar' ? 'المبلغ' : 'Amount', fixed: 110),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 132),
        V2Col(lang == 'ar' ? 'آخر حدث' : 'Last log', flex: 1.1),
      ],
      rows: [
        for (final p in payments)
          V2GridRow(
            onTap: () => context.go(V2Paths.booking(idOf(p))),
            cells: [
              Text('${p['ref'] ?? '#${shortId(idOf(p))}'}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Text(personName(asMap(p['client']) ?? p, lang, fallbackId: '${p['clientId'] ?? ''}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              Text(paymentMethodLabel('${p['paymentMethod'] ?? ''}', lang),
                  style: const TextStyle(fontSize: 13)),
              Text(money(asInt(p['chargedAmount'] ?? p['total']), lang),
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    V2StatusPill(label: statusLabel('${p['status']}', lang), tone: statusTone('${p['status']}')),
                    if (p['hasReceipt'] == true || '${p['paymentReceiptUrl'] ?? ''}'.isNotEmpty)
                      V2StatusPill(label: lang == 'ar' ? 'إيصال' : 'Receipt', tone: V2Tone.info),
                  ],
                ),
              ),
              Text(
                () {
                  final logs = asMapList(p['logs']);
                  if (logs.isEmpty) return '—';
                  final last = logs.last;
                  return '${_kindLabel('${last['kind']}', lang)} · ${formatDay(last['at'], lang)}';
                }(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Ops.muted, height: 1.35),
              ),
            ],
            actions: [
              V2Btn(label: lang == 'ar' ? 'السجل' : 'Logs', onPressed: () => _openLogs(p), size: V2BtnSize.row),
              if ('${p['paymentReceiptUrl'] ?? ''}'.isNotEmpty)
                V2Btn(label: lang == 'ar' ? 'إيصال' : 'Receipt', onPressed: () => _openReceipt(p), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
