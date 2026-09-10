import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/admin/extra_screens.dart';
import 'package:oons/admin/paths.dart';
import 'package:oons/admin/screens.dart';
import 'package:oons/admin/session.dart';
import 'package:oons/admin/shell.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/l10n/app_localizations.dart';

Page<void> _page(GoRouterState s, Widget child) => NoTransitionPage<void>(key: s.pageKey, child: child);

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(staffSessionProvider, (_, __) => refresh.value++);
  late final GoRouter router;
  router = GoRouter(
    initialLocation: AdminPaths.home,
    refreshListenable: refresh,
    redirect: (ctx, st) {
      final sess = ref.read(staffSessionProvider);
      if (!sess.ready) return null;
      var loc = st.uri.path;
      // Repair doubled base-href paths from older builds.
      const doubled = '/oons/admin/oons/admin';
      if (loc.startsWith(doubled)) {
        final rest = loc.substring(doubled.length);
        return rest.isEmpty ? AdminPaths.home : (rest.startsWith('/') ? rest : '/$rest');
      }
      if (loc.startsWith('/oons/admin/')) {
        final rest = loc.substring('/oons/admin'.length);
        return rest.isEmpty || rest == '/' ? AdminPaths.home : rest;
      }
      final onLogin = loc == AdminPaths.login;
      if (!sess.authed && !onLogin) return AdminPaths.login;
      if (sess.authed && onLogin) return AdminPaths.home;
      return null;
    },
    routes: [
      GoRoute(path: AdminPaths.login, pageBuilder: (c, s) => _page(s, const AdminLoginScreen())),
      GoRoute(path: '/people', redirect: (_, __) => AdminPaths.customers),
      GoRoute(
        path: '/people/:id',
        redirect: (c, s) => AdminPaths.customer(s.pathParameters['id']!),
      ),
      GoRoute(path: AdminPaths.root, redirect: (_, __) => AdminPaths.home),
      ShellRoute(
        builder: (c, s, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: AdminPaths.home, pageBuilder: (c, s) => _page(s, const AdminHomeScreen())),
          GoRoute(path: AdminPaths.customers, pageBuilder: (c, s) => _page(s, const AdminCustomersScreen())),
          GoRoute(path: '${AdminPaths.customers}/:id', pageBuilder: (c, s) => _page(s, AdminPersonScreen(id: s.pathParameters['id']!))),
          GoRoute(path: AdminPaths.providers, pageBuilder: (c, s) => _page(s, const AdminProvidersScreen())),
          GoRoute(path: '${AdminPaths.providers}/:id', pageBuilder: (c, s) => _page(s, AdminProviderDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: AdminPaths.live, pageBuilder: (c, s) => _page(s, const AdminBookingsScreen(live: true))),
          GoRoute(path: AdminPaths.bookings, pageBuilder: (c, s) => _page(s, const AdminBookingsScreen())),
          GoRoute(path: '${AdminPaths.bookings}/:id', pageBuilder: (c, s) => _page(s, AdminBookingDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: AdminPaths.payouts, pageBuilder: (c, s) => _page(s, const AdminPayoutsScreen())),
          GoRoute(path: AdminPaths.ledger, pageBuilder: (c, s) => _page(s, const AdminLedgerScreen())),
          GoRoute(path: AdminPaths.staff, pageBuilder: (c, s) => _page(s, const AdminStaffScreen())),
          GoRoute(path: AdminPaths.payments, pageBuilder: (c, s) => _page(s, const AdminPaymentsScreen())),
          GoRoute(path: AdminPaths.audit, pageBuilder: (c, s) => _page(s, const AdminAuditScreen())),
          GoRoute(path: AdminPaths.categories, pageBuilder: (c, s) => _page(s, const AdminCategoriesScreen())),
          GoRoute(path: AdminPaths.areas, pageBuilder: (c, s) => _page(s, const AdminAreasScreen())),
          GoRoute(path: AdminPaths.categoryRequests, pageBuilder: (c, s) => _page(s, const AdminCategoryRequestsScreen())),
          GoRoute(path: AdminPaths.claims, pageBuilder: (c, s) => _page(s, const AdminClaimsScreen())),
          GoRoute(path: AdminPaths.coupons, pageBuilder: (c, s) => _page(s, const AdminCouponsScreen())),
          GoRoute(path: AdminPaths.batches, pageBuilder: (c, s) => _page(s, const AdminBatchesScreen())),
          GoRoute(path: AdminPaths.corporate, pageBuilder: (c, s) => _page(s, const AdminCorporateScreen())),
          GoRoute(path: AdminPaths.heatmap, pageBuilder: (c, s) => _page(s, const AdminHeatmapScreen())),
          GoRoute(path: AdminPaths.vetting, pageBuilder: (c, s) => _page(s, const AdminVettingSlaScreen())),
          GoRoute(path: AdminPaths.matrix, pageBuilder: (c, s) => _page(s, const AdminRoleMatrixScreen())),
          GoRoute(
            path: '${AdminPaths.impersonate}/:id',
            pageBuilder: (c, s) => _page(
              s,
              AdminImpersonateScreen(
                id: s.pathParameters['id']!,
                kind: s.uri.queryParameters['kind'] ?? 'provider',
              ),
            ),
          ),
        ],
      ),
    ],
  );
  router.routerDelegate.addListener(() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    unawaited(AppAnalytics.logPageView(path));
    unawaited(AppAnalytics.adminView(screen: path));
  });
  return router;
});

class _InstantTransitions extends PageTransitionsBuilder {
  const _InstantTransitions();
  @override
  Widget buildTransitions<S>(
    PageRoute<S> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

final _adminTheme = opsTheme().copyWith(
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _InstantTransitions(),
      TargetPlatform.iOS: _InstantTransitions(),
      TargetPlatform.macOS: _InstantTransitions(),
      TargetPlatform.linux: _InstantTransitions(),
      TargetPlatform.windows: _InstantTransitions(),
      TargetPlatform.fuchsia: _InstantTransitions(),
    },
  ),
);

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: locale.languageCode == 'ar' ? 'أنس — طاقم' : 'Oons staff',
      debugShowCheckedModeBanner: false,
      theme: _adminTheme,
      themeAnimationDuration: Duration.zero,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                fontFamily: locale.languageCode == 'ar' ? T.arabic : T.archivo,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
