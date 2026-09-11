import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

/// Cross-provider queue of workers with at least one document on file who
/// aren't vetted yet — the worker-side counterpart of VettingScreen.
/// Deciding a document happens on the provider's own detail screen (Team
/// tab); this queue is purely a triage/navigation surface.
class WorkerVettingScreen extends ConsumerStatefulWidget {
  const WorkerVettingScreen({super.key});

  @override
  ConsumerState<WorkerVettingScreen> createState() => _WorkerVettingScreenState();
}

class _WorkerVettingScreenState extends ConsumerState<WorkerVettingScreen> {
  List<Map<String, dynamic>> pending = [];
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
      final data = await staffClient.get('/admin/workers/pending-vetting');
      final list = asMapList(data['pending']);
      setState(() {
        pending = list;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'workerVetting')) return const V2Gate(allowed: false, child: SizedBox.shrink());

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat(lang == 'ar' ? 'في الطابور' : 'In queue', '${pending.length}', lang == 'ar' ? 'بانتظار قرار' : 'awaiting a decision'),
            ],
          ),
          const SizedBox(height: 16),
          if (loading && pending.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: V2Loading())
          else if (error != null)
            V2ErrorBanner(message: error!, onRetry: _load)
          else
            Container(
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
                    child: Text(lang == 'ar' ? 'طابور توثيق الفريق' : 'Team vetting queue',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ),
                  if (pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 38),
                      child: Center(
                        child: Text(lang == 'ar' ? 'الطابور فارغ' : 'Queue is clear',
                            style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      ),
                    )
                  else
                    for (final w in pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim().isEmpty
                                        ? (lang == 'ar' ? 'بدون اسم' : 'Unnamed')
                                        : '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim(),
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    lang == 'ar'
                                        ? 'عند ${w['providerName'] ?? '—'}'
                                        : 'at ${w['providerName'] ?? '—'}',
                                    style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft),
                                  ),
                                ],
                              ),
                            ),
                            V2Btn.ghost(
                              lang == 'ar' ? 'مراجعة' : 'Review',
                              onPressed: () => context.go('${V2Paths.provider('${w['providerId']}')}?tab=Team'),
                              size: V2BtnSize.row,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String note) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 11.5, color: Ops.faint)),
        ],
      ),
    );
  }
}
