import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
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
    final email = sess.staff is Map ? '${sess.staff!['email'] ?? 'staff'}' : 'staff';

    return Container(
      width: Ops.sidebarW,
      color: Ops.plum,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Ops.creamTile,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('أُنس', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Ops.plum)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(V2Copy.backOffice, lang), style: const TextStyle(color: Ops.plumText, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(roleLabel(role), style: const TextStyle(color: Ops.plumMuted, fontSize: 11, fontFamily: Ops.mono)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 12),
              children: [
                for (final g in v2Nav) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 14, 10, 6),
                    child: Text(
                      lang == 'ar' ? g.labelAr : g.labelEn,
                      style: const TextStyle(fontSize: 10.5, letterSpacing: 0.4, color: Ops.plumMuted, fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final item in g.items)
                    if (canSeeScreen(role, item.id))
                      _NavTile(
                        label: lang == 'ar' ? item.labelAr : item.labelEn,
                        selected: loc == item.path || loc.startsWith('${item.path}/'),
                        onTap: () => context.go(item.path),
                      ),
                ],
              ],
            ),
          ),
          if (sess.staffRole == roleSuper)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(V2Copy.viewAs, lang), style: const TextStyle(fontSize: 10.5, color: Ops.plumMuted)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: sess.viewAsRole ?? roleSuper,
                    dropdownColor: Ops.plumActive,
                    style: const TextStyle(color: Ops.plumText, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Ops.plumActive,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: roleSuper, child: Text('super_admin')),
                      DropdownMenuItem(value: roleOps, child: Text('ops')),
                      DropdownMenuItem(value: roleFinance, child: Text('finance')),
                      DropdownMenuItem(value: roleVendor, child: Text('vendor_acq')),
                    ],
                    onChanged: (v) => ref.read(staffSessionProvider.notifier).setViewAsRole(v),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: const TextStyle(fontSize: 11, color: Ops.plumMuted, fontFamily: Ops.mono)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setLocaleCode(ref, lang == 'ar' ? 'en' : 'ar'),
                      style: TextButton.styleFrom(foregroundColor: Ops.plumText, padding: EdgeInsets.zero),
                      child: Text(lang == 'ar' ? 'EN' : 'ع'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await ref.read(staffSessionProvider.notifier).signOut();
                        if (context.mounted) context.go(V2Paths.login);
                      },
                      style: TextButton.styleFrom(foregroundColor: Ops.plumMuted, padding: EdgeInsets.zero),
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

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Ops.plumActive : Colors.transparent,
        borderRadius: BorderRadius.circular(Ops.radiusNav),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ops.radiusNav),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Ops.plumText : const Color(0xFFD5C4D0),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
