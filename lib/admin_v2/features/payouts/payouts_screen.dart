import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/core/format.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  List<Map<String, dynamic>> payouts = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      
      final data = await staffClient.get('/admin/payouts');
      setState(() {
        payouts = asMapList(data['payouts']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _holdPayout(String payoutId) async {
    final lang = ref.read(localeCodeProvider);
    final confirmed = await v2Confirm(
      context,
      title: lang == 'ar' ? 'تجميد السحب' : 'Hold payout',
      body: lang == 'ar' ? 'هل تريد تجميد هذا السحب؟' : 'Hold this payout?',
      confirmLabel: lang == 'ar' ? 'تجميد' : 'Hold',
    );
    
    if (!confirmed) return;

    try {
      await staffClient.post('/admin/payouts/$payoutId/hold');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تجميد السحب' : 'Payout held');
        _loadPayouts();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _releasePayout(String payoutId) async {
    final lang = ref.read(localeCodeProvider);
    final confirmed = await v2Confirm(
      context,
      title: lang == 'ar' ? 'تحرير السحب' : 'Release payout',
      body: lang == 'ar' ? 'هل تريد تحرير هذا السحب؟' : 'Release this payout?',
      confirmLabel: lang == 'ar' ? 'تحرير' : 'Release',
    );
    
    if (!confirmed) return;

    try {
      await staffClient.post('/admin/payouts/$payoutId/release');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تحرير السحب' : 'Payout released');
        _loadPayouts();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);

    if (!staffCan(staffState.effectiveRole, 'payouts.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: Ops.page,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              lang == 'ar' ? 'السحوبات' : 'Payouts',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Ops.ink),
            ),
          ),
          Expanded(
            child: loading
                ? const V2Loading()
                : error != null
                    ? Center(child: V2ErrorBanner(message: error!, onRetry: _loadPayouts))
                    : payouts.isEmpty
                        ? const V2Empty()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              V2DataTable(
                                headers: [
                                  lang == 'ar' ? 'السحب' : 'Payout',
                                  lang == 'ar' ? 'المهنية' : 'Provider',
                                  lang == 'ar' ? 'المبلغ' : 'Amount',
                                  lang == 'ar' ? 'الحالة' : 'Status',
                                  lang == 'ar' ? 'التاريخ' : 'Date',
                                  if (staffCan(staffState.effectiveRole, 'payouts.write')) lang == 'ar' ? 'إجراءات' : 'Actions',
                                ],
                                rows: payouts.map((payout) {
                                  final date = parseTime(payout['createdAt']);
                                  final amount = asInt(payout['amount']);
                                  final status = payout['status'] as String? ?? 'pending';
                                  
                                  final row = <Widget>[
                                    Text(
                                      '#${payout['id']}',
                                      style: const TextStyle(fontFamily: Ops.mono, fontSize: 12, color: Ops.muted),
                                    ),
                                    Text(personName(payout['providerName'] ?? payout, lang, fallbackId: '${payout['providerId'] ?? ''}')),
                                    Text(money(amount, lang), style: const TextStyle(fontFamily: Ops.mono)),
                                    V2StatusPill(
                                      label: status,
                                      tone: status == 'held' ? V2Tone.bad : V2Tone.ok,
                                    ),
                                    Text(
                                      date != null ? formatDay(payout['createdAt'], lang) : '',
                                      style: const TextStyle(fontSize: 12, color: Ops.muted),
                                    ),
                                  ];
                                  
                                  if (staffCan(staffState.effectiveRole, 'payouts.write')) {
                                    row.add(
                                      SizedBox(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Hold only pending; never hold paid
                                            if (status == 'pending')
                                              ElevatedButton(
                                                onPressed: () => _holdPayout('${payout['id']}'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Ops.terracottaInk,
                                                  minimumSize: const Size(50, 32),
                                                ),
                                                child: Text(
                                                  lang == 'ar' ? 'تجميد' : 'Hold',
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                              ),
                                            // Release for pending/ready/held
                                            if (['pending', 'ready', 'held'].contains(status)) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _releasePayout('${payout['id']}'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Ops.green,
                                                  minimumSize: const Size(50, 32),
                                                ),
                                                child: Text(
                                                  lang == 'ar' ? 'تحرير' : 'Release',
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return row;
                                }).toList(),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}