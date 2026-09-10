import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/data/api.dart';

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  List<String> roles = const [roleSuper, roleOps, roleFinance, roleVendor, roleAm];
  List<String> perms = List.of(allPermKeys);
  Map<String, Map<String, bool>>? grants;
  bool loading = true;
  bool fromServer = false;
  String? error;

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
      final data = await staffClient.get('/admin/rbac/matrix');
      final serverRoles = (data['roles'] is List)
          ? (data['roles'] as List).map((e) => '$e').toList()
          : roles;
      final serverPerms = (data['perms'] is List)
          ? (data['perms'] as List).map((e) => '$e').toList()
          : perms;
      final rawGrants = asMap(data['grants']);
      final parsed = <String, Map<String, bool>>{};
      if (rawGrants != null) {
        for (final entry in rawGrants.entries) {
          final row = asMap(entry.value);
          if (row == null) continue;
          parsed[entry.key] = {
            for (final e in row.entries) e.key: e.value == true,
          };
        }
      }
      if (!mounted) return;
      setState(() {
        roles = serverRoles;
        perms = serverPerms;
        grants = parsed.isEmpty ? null : parsed;
        fromServer = grants != null;
        loading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        fromServer = false;
        grants = null;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        fromServer = false;
        grants = null;
        loading = false;
      });
    }
  }

  bool _allowed(String role, String perm) {
    final g = grants;
    if (g != null) {
      final row = g[role];
      if (row != null && row.containsKey(perm)) return row[perm] == true;
    }
    return staffCan(role, perm);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);

    if (!canSeeScreen(staffState.effectiveRole, 'matrix')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: Ops.page,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'ar' ? 'مصفوفة الصلاحيات' : 'Permission matrix',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Ops.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fromServer
                            ? (lang == 'ar' ? 'من الخادم' : 'From server')
                            : (lang == 'ar' ? 'جدول محلي' : 'Local staffCan fallback'),
                        style: const TextStyle(fontSize: 12, color: Ops.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          if (loading)
            const Expanded(child: V2Loading())
          else if (error != null)
            Expanded(child: Center(child: V2ErrorBanner(message: error!, onRetry: _load)))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: V2Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Ops.cardAlt),
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 48,
                      headingTextStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Ops.muted,
                      ),
                      columns: [
                        const DataColumn(label: Text('Permission')),
                        for (final role in roles)
                          DataColumn(
                            label: Text(
                              roleLabel(role),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      rows: perms.map((perm) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                perm,
                                style: const TextStyle(fontSize: 12, fontFamily: Ops.mono),
                              ),
                            ),
                            for (final role in roles)
                              DataCell(
                                Center(
                                  child: Icon(
                                    _allowed(role, perm) ? Icons.check : Icons.close,
                                    size: 16,
                                    color: _allowed(role, perm) ? Ops.green : Ops.muted,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
