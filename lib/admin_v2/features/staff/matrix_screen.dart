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

/// Screen → (readPerm, writePerm) pairs, matching the prototype's mKeys.
const _matrixRows = <(String label, String read, String write)>[
  ('Bookings', 'bookings.read', 'bookings.write'),
  ('Claims', 'claims.read', 'claims.write'),
  ('Customers', 'users.read', 'users.write'),
  ('Providers', 'providers.read', 'providers.vet'),
  ('Category requests', 'providers.read', 'provider_categories.write'),
  ('Payouts', 'payouts.read', 'payouts.write'),
  ('Coupons', 'coupons.read', 'coupons.write'),
  ('Payments', 'payments.settings', 'payments.settings'),
  ('Staff', 'staff.write', 'staff.write'),
  ('Audit', 'audit.read', 'audit.read'),
];

const _roles = [roleSuper, roleOps, roleFinance, roleVendor];

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  Map<String, Map<String, bool>>? serverGrants;
  bool fromServer = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await staffClient.get('/admin/rbac/matrix');
      final raw = asMap(data['grants']);
      final parsed = <String, Map<String, bool>>{};
      if (raw != null) {
        for (final e in raw.entries) {
          final row = asMap(e.value);
          if (row == null) continue;
          parsed[e.key] = {for (final r in row.entries) r.key: r.value == true};
        }
      }
      if (!mounted) return;
      setState(() {
        serverGrants = parsed.isEmpty ? null : parsed;
        fromServer = parsed.isNotEmpty;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 'Write' | 'Read' | '—'
  String _mark(String role, String read, String write) {
    final g = serverGrants?[role];
    bool has(String p) => g != null && g.containsKey(p) ? g[p] == true : staffCan(role, p);
    if (has(write)) return 'Write';
    if (has(read)) return 'Read';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!canSeeScreen(role, 'matrix')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          Row(
            children: [
              Text(fromServer ? (lang == 'ar' ? 'من الخادم' : 'From server RBAC') : (lang == 'ar' ? 'من staffCan' : 'From staffCan'),
                  style: const TextStyle(fontSize: 12, color: Ops.muted)),
              const Spacer(),
              V2Btn.ghost(lang == 'ar' ? '→ الفريق' : '← Staff', onPressed: () => context.go(V2Paths.staff), size: V2BtnSize.sm),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Ops.card,
              borderRadius: BorderRadius.circular(Ops.radiusCard),
              border: Border.all(color: Ops.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 560,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Ops.headBg,
                      child: Row(
                        children: [
                          const Expanded(flex: 3, child: Text('Screen', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Ops.greyInk))),
                          for (final r in _roles)
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(roleLabel(r),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Ops.greyInk)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final row in _matrixRows)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(row.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            for (final r in _roles)
                              Expanded(
                                flex: 2,
                                child: Center(child: _cell(_mark(r, row.$2, row.$3))),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String mark) {
    final tone = mark == 'Write' ? V2Tone.ok : (mark == 'Read' ? V2Tone.info : V2Tone.neutral);
    return V2StatusPill(label: mark, tone: tone);
  }
}
