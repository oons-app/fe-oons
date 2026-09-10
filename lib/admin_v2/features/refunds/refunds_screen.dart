import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class RefundsScreen extends ConsumerStatefulWidget {
  const RefundsScreen({super.key});

  @override
  ConsumerState<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends ConsumerState<RefundsScreen> {
  List<Map<String, dynamic>> refunds = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/refunds');
      setState(() {
        refunds = asMapList(data['refunds']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _resolve(Map<String, dynamic> row) async {
    final lang = ref.read(localeCodeProvider);
    String note = '';
    String status = 'closed';
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'حل المرتجع' : 'Resolve refund',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Resolve',
      bodyBuilder: (ctx, setLocal) => Column(
        children: [
          V2FormField(
            label: lang == 'ar' ? 'ملاحظة' : 'Note',
            child: TextField(
              onChanged: (v) => note = v,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'الحالة' : 'Status',
            child: DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'open', child: Text(lang == 'ar' ? 'مفتوح' : 'Open')),
                DropdownMenuItem(value: 'closed', child: Text(lang == 'ar' ? 'مغلق' : 'Closed')),
              ],
              onChanged: (v) => setLocal(() => status = v ?? status),
            ),
          ),
        ],
      ),
    );
    if (!confirmed) return;
    try {
      await staffClient.post('/admin/refunds/${idOf(row)}/resolve', data: {
        'note': note.trim(),
        'status': status,
      });
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحل' : 'Refund resolved');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    final role = staffState.effectiveRole;
    final allowed = staffCan(role, 'bookings.read') || canSeeScreen(role, 'refunds');
    if (!allowed) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canWrite = staffCan(role, 'bookings.write');

    return ColoredBox(
      color: Ops.page,
      child: Column(
        children: [
          V2PageHeader(
            title: lang == 'ar' ? 'المرتجعات' : 'Refunds',
            lang: lang,
            resultCount: loading ? null : refunds.length,
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          Expanded(
            child: loading
                ? const V2Loading()
                : error != null
                    ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
                    : refunds.isEmpty
                        ? const V2Empty()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              V2Card(
                                padding: EdgeInsets.zero,
                                child: V2DataTable(
                                  headers: [
                                    lang == 'ar' ? 'المرجع' : 'Ref',
                                    lang == 'ar' ? 'الحالة' : 'Status',
                                    lang == 'ar' ? 'الإجمالي' : 'Total',
                                    lang == 'ar' ? 'المرتجع' : 'Refund amount',
                                    lang == 'ar' ? 'التحديث' : 'Updated',
                                    if (canWrite) lang == 'ar' ? 'إجراءات' : 'Actions',
                                  ],
                                  rows: [
                                    for (final r in refunds)
                                      [
                                        Text('${r['ref'] ?? shortId(idOf(r))}',
                                            style: const TextStyle(fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                                        V2StatusPill(
                                          label: statusLabel('${r['status']}', lang),
                                          tone: statusTone('${r['status']}'),
                                        ),
                                        Text(money(asInt(r['total']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                                        Text(money(asInt(r['refundAmount']), lang),
                                            style: const TextStyle(fontFamily: Ops.mono)),
                                        Text(formatDay(r['updatedAt'], lang),
                                            style: const TextStyle(fontSize: 12, color: Ops.muted)),
                                        if (canWrite)
                                          TextButton(
                                            onPressed: () => _resolve(r),
                                            child: Text(lang == 'ar' ? 'حل' : 'Resolve'),
                                          ),
                                      ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
