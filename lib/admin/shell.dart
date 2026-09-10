import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin/overlays.dart';
import 'package:oons/admin/paths.dart';
import 'package:oons/admin/session.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/l10n/copy.dart';

/// Phone / small-tablet: hide the pinned sidebar and use a drawer.
bool adminCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 880;

EdgeInsets adminPagePad(BuildContext context) {
  final inset = adminCompact(context) ? 16.0 : 28.0;
  return EdgeInsets.fromLTRB(inset, 24, inset, inset + MediaQuery.paddingOf(context).bottom);
}

class _Nav {
  const _Nav(this.path, this.labelKey, this.perm, {this.dot = T.trust});
  final String path;
  final String labelKey;
  final String? perm;
  final Color dot;
}

class _NavGroup {
  const _NavGroup(this.labelKey, this.items);
  final String labelKey;
  final List<_Nav> items;
}

const _navGroups = [
  _NavGroup('navOps', [
    _Nav(AdminPaths.home, 'home', null),
    _Nav(AdminPaths.live, 'liveNav', 'bookings.read', dot: T.trustBright),
    _Nav(AdminPaths.bookings, 'bookings', 'bookings.read', dot: T.plum),
    _Nav(AdminPaths.claims, 'claims', 'claims.read', dot: T.warm),
  ]),
  _NavGroup('navPeople', [
    _Nav(AdminPaths.customers, 'customers', 'users.read', dot: T.warm),
    _Nav(AdminPaths.providers, 'providers', 'providers.read', dot: T.pending),
    _Nav(AdminPaths.categoryRequests, 'categoryRequests', 'provider_categories.write', dot: T.pending),
  ]),
  _NavGroup('navMoney', [
    _Nav(AdminPaths.payouts, 'payouts', 'payouts.read', dot: T.trust),
    _Nav(AdminPaths.ledger, 'ledger', 'ledger.read', dot: T.blueInk),
    _Nav(AdminPaths.coupons, 'coupons', 'coupons.read', dot: T.warm),
    _Nav(AdminPaths.batches, 'batches', 'payouts.read', dot: T.trust),
  ]),
  _NavGroup('navAdmin', [
    _Nav(AdminPaths.categories, 'categories', 'categories.write', dot: T.plum),
    _Nav(AdminPaths.areas, 'areas', 'areas.write', dot: T.warm),
    _Nav(AdminPaths.staff, 'staff', 'staff.write', dot: T.plum),
    _Nav(AdminPaths.payments, 'payments', 'payments.settings', dot: T.pending),
    _Nav(AdminPaths.corporate, 'corporate', 'staff.write', dot: T.plum),
    _Nav(AdminPaths.audit, 'audit', 'audit.read', dot: T.warm),
  ]),
  _NavGroup('navInsights', [
    _Nav(AdminPaths.heatmap, 'heatmap', 'bookings.read', dot: T.trustBright),
    _Nav(AdminPaths.vetting, 'vetting', 'providers.read', dot: T.pending),
  ]),
];

String adminPageTitle(Map copy, String loc) {
  for (final g in _navGroups) {
    for (final n in g.items) {
      if (loc == n.path || (n.path != AdminPaths.home && loc.startsWith('${n.path}/'))) {
        return '${copy[n.labelKey]}';
      }
    }
  }
  if (loc == AdminPaths.matrix) return '${copy['matrix'] ?? 'Role matrix'}';
  if (loc.startsWith(AdminPaths.impersonate)) return '${copy['impersonateView'] ?? 'Impersonating'}';
  return '${copy['brand']}';
}

String adminPageSub(Map copy, String loc) {
  if (loc == AdminPaths.home) return '${copy['homeSub'] ?? ''}';
  if (loc == AdminPaths.live) return '${copy['liveSub'] ?? ''}';
  if (loc.startsWith(AdminPaths.bookings)) return '${copy['bookingsSub'] ?? ''}';
  if (loc.startsWith(AdminPaths.customers)) return '${copy['customersSub'] ?? ''}';
  if (loc.startsWith(AdminPaths.providers)) return '${copy['providersSub'] ?? ''}';
  if (loc == AdminPaths.payouts) return '${copy['payoutsSub'] ?? ''}';
  if (loc == AdminPaths.ledger) return '${copy['ledgerSub'] ?? ''}';
  if (loc == AdminPaths.staff) return '${copy['staffSub'] ?? ''}';
  if (loc == AdminPaths.payments) return '${copy['paymentsSub'] ?? ''}';
  if (loc == AdminPaths.audit) return '${copy['auditSub'] ?? ''}';
  if (loc == AdminPaths.categories) return '${copy['categoriesSub'] ?? ''}';
  if (loc == AdminPaths.areas) return '${copy['areasSub'] ?? ''}';
  if (loc == AdminPaths.categoryRequests) return '${copy['categoryRequestsSub'] ?? ''}';
  if (loc == AdminPaths.claims) return '${copy['claimsSub'] ?? ''}';
  if (loc == AdminPaths.coupons) return '${copy['couponsSub'] ?? ''}';
  if (loc == AdminPaths.batches) return '${copy['batchesSub'] ?? ''}';
  if (loc == AdminPaths.corporate) return '${copy['corporateSub'] ?? ''}';
  if (loc == AdminPaths.heatmap) return '${copy['heatmapSub'] ?? ''}';
  if (loc == AdminPaths.vetting) return '${copy['vettingSub'] ?? ''}';
  if (loc == AdminPaths.matrix) return '${copy['matrixSub'] ?? ''}';
  if (loc.startsWith(AdminPaths.impersonate)) return '${copy['impersonateViewSub'] ?? ''}';
  return '';
}

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    final looksBooking = q.toUpperCase().startsWith('ONS') || RegExp(r'^\d{4,}').hasMatch(q);
    if (looksBooking) {
      context.go('${AdminPaths.bookings}?q=${Uri.encodeQueryComponent(q)}');
    } else {
      context.go('${AdminPaths.customers}?q=${Uri.encodeQueryComponent(q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final copy = (Copy.of(lang)['admin'] as Map).cast<String, dynamic>();
    final root = Copy.of(lang);
    final sess = ref.watch(staffSessionProvider);
    final effRole = effectiveStaffRole(sess);
    final loc = GoRouterState.of(context).uri.path;
    final compact = adminCompact(context);
    final email = '${sess.staff?['email'] ?? ''}';
    final roleLabel = _role(copy, effRole);
    final isSuper = sess.staffRole == roleSuper;

    List<_NavGroup> groups() {
      return [
        for (final g in _navGroups)
          _NavGroup(
            g.labelKey,
            g.items.where((n) => n.perm == null || staffCan(effRole, n.perm!)).toList(),
          ),
      ].where((g) => g.items.isNotEmpty).toList();
    }

    void goTo(String path) {
      if (loc != path) context.go(path);
    }

    final pane = _NavPane(
      copy: copy,
      loc: loc,
      groups: groups(),
      email: email,
      role: roleLabel,
      isSuper: isSuper,
      viewAsRole: sess.viewAsRole,
      langLabel: '${root['langSwap']}',
      onLang: () => ref.read(localeProvider.notifier).toggle(),
      onNav: goTo,
      onSignOut: () => ref.read(staffSessionProvider.notifier).signOut(),
      onViewAs: (r) => ref.read(staffSessionProvider.notifier).setViewAsRole(r),
    );

    final header = _TopBar(
      title: adminPageTitle(copy, loc),
      subtitle: adminPageSub(copy, loc),
      search: _search,
      searchHint: '${copy['globalSearch']}',
      liveLabel: '${copy['liveNow']}',
      onSearch: _runSearch,
      onLive: () => goTo(AdminPaths.live),
      compact: compact,
    );

    if (compact) {
      return Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.bg,
          foregroundColor: T.ink,
          elevation: 0,
          toolbarHeight: 56,
          leading: Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Glyph(GlyphKind.menu, size: 22, color: T.ink),
            ),
          ),
          title: Row(
            children: [
              const BrandMark(size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${copy['brand']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: T.ink),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: T.line),
          ),
        ),
        drawer: Drawer(
          backgroundColor: T.sidebar,
          width: 280,
          child: SafeArea(
            child: Builder(
              builder: (drawerCtx) => _NavPane(
                copy: copy,
                loc: loc,
                groups: groups(),
                email: email,
                role: roleLabel,
                isSuper: isSuper,
                viewAsRole: sess.viewAsRole,
                langLabel: '${root['langSwap']}',
                onLang: () {
                  Navigator.pop(drawerCtx);
                  ref.read(localeProvider.notifier).toggle();
                },
                onNav: (path) {
                  Navigator.pop(drawerCtx);
                  goTo(path);
                },
                onSignOut: () {
                  Navigator.pop(drawerCtx);
                  ref.read(staffSessionProvider.notifier).signOut();
                },
                onViewAs: (r) => ref.read(staffSessionProvider.notifier).setViewAsRole(r),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            if (sess.isImpersonating)
              OpsImpersonationBanner(
                label: '${copy['impersonatingAs'] ?? 'Viewing as'} ${sess.impersonatingKind == 'customer' ? (copy['customer'] ?? 'Customer') : (copy['provider'] ?? 'Provider')}: ${sess.impersonatingName ?? sess.impersonatingId}',
                onExit: () {
                  ref.read(staffSessionProvider.notifier).clearImpersonation();
                  if (loc.startsWith(AdminPaths.impersonate)) context.go(AdminPaths.providers);
                },
              ),
            header,
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: T.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: T.sidebarWidth, child: pane),
          Expanded(
            child: Column(
              children: [
                if (sess.isImpersonating)
                  OpsImpersonationBanner(
                    label: '${copy['impersonatingAs'] ?? 'Viewing as'} ${sess.impersonatingKind == 'customer' ? (copy['customer'] ?? 'Customer') : (copy['provider'] ?? 'Provider')}: ${sess.impersonatingName ?? sess.impersonatingId}',
                    onExit: () {
                      ref.read(staffSessionProvider.notifier).clearImpersonation();
                      if (loc.startsWith(AdminPaths.impersonate)) context.go(AdminPaths.providers);
                    },
                  ),
                header,
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.search,
    required this.searchHint,
    required this.liveLabel,
    required this.onSearch,
    required this.onLive,
    required this.compact,
  });

  final String title;
  final String subtitle;
  final TextEditingController search;
  final String searchHint;
  final String liveLabel;
  final VoidCallback onSearch;
  final VoidCallback onLive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 14, compact ? 16 : 24, 14),
      decoration: BoxDecoration(
        color: T.bg.withValues(alpha: 0.94),
        border: const Border(bottom: BorderSide(color: T.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: T.ink,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: T.muted)),
                ],
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, minWidth: 180),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: T.lineStrong),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: T.mutedSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: search,
                        onSubmitted: (_) => onSearch(),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: const TextStyle(color: T.mutedSoft, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13, color: T.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Material(
            color: T.surface,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onLive,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: T.lineStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: T.trust, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      liveLabel,
                      style: const TextStyle(color: T.body, fontWeight: FontWeight.w500, fontSize: 12.5),
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
}

class _NavPane extends StatelessWidget {
  const _NavPane({
    required this.copy,
    required this.loc,
    required this.groups,
    required this.email,
    required this.role,
    required this.isSuper,
    required this.viewAsRole,
    required this.langLabel,
    required this.onLang,
    required this.onNav,
    required this.onSignOut,
    required this.onViewAs,
  });

  final Map<String, dynamic> copy;
  final String loc;
  final List<_NavGroup> groups;
  final String email;
  final String role;
  final bool isSuper;
  final String? viewAsRole;
  final String langLabel;
  final VoidCallback onLang;
  final ValueChanged<String> onNav;
  final VoidCallback onSignOut;
  final ValueChanged<String?> onViewAs;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: T.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F0EA),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    children: [
                      BrandMark(size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Oons',
                          style: TextStyle(
                            color: T.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${copy['backOffice'] ?? 'Back office'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: T.sidebarMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: T.actionSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: T.sidebarText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: T.sidebarText.withValues(alpha: 0.13)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 5),
                    child: Text(
                      '${copy[g.labelKey] ?? g.labelKey}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: T.sidebarGroup,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final n in g.items)
                    _SideItem(
                      label: '${copy[n.labelKey] ?? n.labelKey}',
                      selected: loc == n.path || (n.path != AdminPaths.home && loc.startsWith('${n.path}/')),
                      accent: n.dot,
                      onTap: () => onNav(n.path),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Container(height: 1, color: T.sidebarText.withValues(alpha: 0.13)),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isSuper) ...[
                  Text(
                    '${copy['viewAsRole'] ?? 'View as role'}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: T.sidebarGroup,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2A43),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: T.sidebarText.withValues(alpha: 0.24)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: viewAsRole ?? roleSuper,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF4A2A43),
                        iconEnabledColor: T.sidebarText,
                        style: const TextStyle(color: T.sidebarText, fontSize: 12.5),
                        items: [
                          for (final r in staffRoleChoices)
                            DropdownMenuItem(
                              value: r,
                              child: Text('${copy['role_$r'] ?? r}'),
                            ),
                        ],
                        onChanged: (v) => onViewAs(v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (email.isNotEmpty)
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: T.sidebarMuted),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _GhostBtn(label: langLabel, onTap: onLang)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _GhostBtn(label: '${copy['signOut']}', onTap: onSignOut),
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

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: T.sidebarText.withValues(alpha: 0.3)),
          ),
          child: Text(label, style: const TextStyle(color: T.sidebarText, fontSize: 12.5)),
        ),
      ),
    );
  }
}

String _role(Map copy, String role) => '${copy['role_$role'] ?? role}';

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? T.actionSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? accent : T.sidebarText.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                      color: selected ? const Color(0xFFFBF6F9) : T.sidebarIdle,
                    ),
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

class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.perm, required this.child});
  final String perm;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final copy = (Copy.of(lang)['admin'] as Map).cast<String, dynamic>();
    final sess = ref.watch(staffSessionProvider);
    final role = effectiveStaffRole(sess);
    if (!staffCan(role, perm)) {
      return Center(child: Text('${copy['noAccess']}', style: const TextStyle(color: T.muted)));
    }
    return child;
  }
}
