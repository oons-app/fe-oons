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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class ImpersonateScreen extends ConsumerStatefulWidget {
  const ImpersonateScreen({super.key, required this.id, this.kind = 'provider'});
  final String id;
  final String kind;

  @override
  ConsumerState<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends ConsumerState<ImpersonateScreen> {
  Map? subject;
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  bool get _isCustomer => widget.kind == 'customer' || widget.kind == 'user';

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
    try {
      final path = _isCustomer ? '/admin/users/${widget.id}' : '/admin/providers/${widget.id}';
      final r = await staffClient.get(path);
      final sub = unwrapEntity(r, _isCustomer ? const ['user'] : const ['provider']);
      final b = await staffClient.get('/admin/bookings', query: {
        if (_isCustomer) 'clientId': widget.id else 'providerId': widget.id,
        'limit': 50,
      });
      if (!mounted) return;
      setState(() {
        subject = sub;
        items = asMapList(b['bookings']);
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  void _exit() {
    ref.read(staffSessionProvider.notifier).clearImpersonation();
    context.go(_isCustomer ? V2Paths.customers : V2Paths.providers);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    final perm = _isCustomer ? 'users.impersonate' : 'providers.impersonate';
    if (!staffCan(role, perm)) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final s = subject ?? {};
    final name = personName(s, lang, fallbackId: widget.id);
    final roleWord = _isCustomer ? (lang == 'ar' ? 'عميلة' : 'Client') : (lang == 'ar' ? 'مهنية' : 'Professional');

    final stats = _isCustomer
        ? [
            (lang == 'ar' ? 'الحجوزات' : 'Bookings', '${items.length}'),
            (lang == 'ar' ? 'المنطقة' : 'Area', areaLabel(s['area'], lang)),
            (lang == 'ar' ? 'الحالة' : 'Status', '${s['status'] ?? '—'}'),
          ]
        : [
            (lang == 'ar' ? 'الوظائف' : 'Jobs', '${items.length}'),
            (lang == 'ar' ? 'التقييم' : 'Rating', asDouble(s['rating']).toStringAsFixed(1)),
            (lang == 'ar' ? 'المتاح' : 'Available',
                money(asInt(asMap(s['ledger'])?['available'] ?? asMap(s['earnings'])?['pending']), lang)),
          ];

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Ops.card,
                    borderRadius: BorderRadius.circular(Ops.radiusCard),
                    border: Border.all(color: Ops.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Ops.plumChip,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(name.isEmpty ? '?' : name.characters.first,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Ops.plumChipInk)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            Text('$roleWord ${lang == 'ar' ? 'عرض التطبيق' : 'app view'} · ${s['phone'] ?? ''}',
                                style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
                          ],
                        ),
                      ),
                      V2Btn.danger(lang == 'ar' ? 'إنهاء العرض' : 'Exit impersonation', onPressed: _exit),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final st in stats)
                      Container(
                        width: 170,
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(
                          color: Ops.card,
                          borderRadius: BorderRadius.circular(Ops.radiusCard),
                          border: Border.all(color: Ops.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(st.$1, style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
                            const SizedBox(height: 5),
                            Text(st.$2.isEmpty ? '—' : st.$2,
                                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
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
                        child: Text(
                          _isCustomer ? (lang == 'ar' ? 'حجوزاتها' : 'Their bookings') : (lang == 'ar' ? 'وظائفها' : 'Their jobs'),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 38),
                          child: Center(
                            child: Text(lang == 'ar' ? 'لا شيء في هذا الحساب بعد' : 'Nothing in this account yet',
                                style: const TextStyle(fontSize: 13, color: Ops.muted)),
                          ),
                        )
                      else
                        for (final b in items)
                          InkWell(
                            onTap: () => context.go(V2Paths.booking(idOf(b))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(serviceLabel(b, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        Text(
                                            '${formatDayOnly(b['slotStart'])} · ${areaLabel(b['areaName'] ?? b['area'], lang)} · ${money(asInt(b['total']), lang)}',
                                            style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft)),
                                      ],
                                    ),
                                  ),
                                  V2StatusPill(label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
                                ],
                              ),
                            ),
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
}
