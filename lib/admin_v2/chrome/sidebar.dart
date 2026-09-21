import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

class V2Sidebar extends ConsumerWidget {
  const V2Sidebar({super.key, required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sess = ref.watch(staffSessionProvider);
    final role = sess.effectiveRole;
    final loc = GoRouterState.of(context).uri.path;
    final badges = ref.watch(v2NavBadgesProvider);
    final email = sess.staff is Map ? '${sess.staff!['email'] ?? 'staff'}' : 'admin@oons.app';

    return Container(
      width: Ops.sidebarW,
      color: Ops.plum,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo tile + role -------------------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22EFE4EC))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Ops.creamTile,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Image.asset('assets/images/logo.png', height: 30, fit: BoxFit.contain),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      lang == 'ar' ? 'المكتب الخلفي' : 'BACK OFFICE',
                      style: const TextStyle(fontSize: 11, color: Ops.plumMuted, letterSpacing: 0.6, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    _RoleChip(role: role),
                  ],
                ),
              ],
            ),
          ),

          // Nav -----------------------------------------------------------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              children: [
                for (final g in v2Nav) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 5),
                    child: Text(
                      (lang == 'ar' ? g.labelAr : g.labelEn).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10.5, letterSpacing: 1.1, color: Ops.plumFaint, fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final item in g.items)
                    if (canSeeScreen(role, item.id))
                      _NavTile(
                        label: lang == 'ar' ? item.labelAr : item.labelEn,
                        selected: loc == item.path || loc.startsWith('${item.path}/'),
                        badge: badges[item.id] ?? 0,
                        onTap: () => context.go(item.path),
                      ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          // Footer: view-as + identity ---------------------------------------
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x22EFE4EC))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sess.staffRole == roleSuper) ...[
                  Text(
                    (lang == 'ar' ? 'عرض بدور' : 'VIEW AS ROLE'),
                    style: const TextStyle(fontSize: 10.5, color: Ops.plumFaint, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sess.viewAsRole ?? roleSuper,
                      isExpanded: true,
                      dropdownColor: Ops.plumActive,
                      style: const TextStyle(color: Ops.plumText, fontSize: 12.5, fontFamily: Ops.sans),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      borderRadius: BorderRadius.circular(9),
                      items: const [
                        DropdownMenuItem(value: roleSuper, child: Text('super_admin')),
                        DropdownMenuItem(value: roleOps, child: Text('ops')),
                        DropdownMenuItem(value: roleFinance, child: Text('finance')),
                        DropdownMenuItem(value: roleVendor, child: Text('vendor_acq')),
                      ],
                      onChanged: (v) => ref.read(staffSessionProvider.notifier).setViewAsRole(v),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Ops.plumMuted, fontFamily: Ops.mono),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setLocaleCode(ref, lang == 'ar' ? 'en' : 'ar'),
                      style: TextButton.styleFrom(
                          foregroundColor: Ops.plumText, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
                      child: Text(lang == 'ar' ? 'EN' : 'ع'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(staffSessionProvider.notifier).signOut();
                        if (context.mounted) context.go(V2Paths.login);
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: Ops.plumMuted, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 32)),
                      child: Text(lang == 'ar' ? 'خروج' : 'Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isSuper = role == roleSuper;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isSuper ? Ops.plumChip : Ops.greyTint,
        borderRadius: BorderRadius.circular(Ops.radiusPill),
      ),
      child: Text(
        roleLabel(role),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSuper ? Ops.plumChipInk : Ops.greyInk,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.selected, required this.badge, required this.onTap});
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? Ops.plumActive : Colors.transparent,
        borderRadius: BorderRadius.circular(Ops.radiusNav),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ops.radiusNav),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? Ops.green : const Color(0x3DEFE4EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Ops.plumText : Ops.navIdle,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: Ops.terracotta,
                      borderRadius: BorderRadius.circular(Ops.radiusPill),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, fontFamily: Ops.mono, color: Color(0xFFFFF6F2)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
