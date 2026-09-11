import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/shell.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/features/analytics/analytics_screen.dart';
import 'package:oons/admin_v2/features/areas/areas_screen.dart';
import 'package:oons/admin_v2/features/audit/audit_screen.dart';
import 'package:oons/admin_v2/features/batches/batches_screen.dart';
import 'package:oons/admin_v2/features/bookings/booking_detail_screen.dart';
import 'package:oons/admin_v2/features/bookings/bookings_screen.dart';
import 'package:oons/admin_v2/features/categories/categories_screen.dart';
import 'package:oons/admin_v2/features/category_requests/category_requests_screen.dart';
import 'package:oons/admin_v2/features/service_requests/service_requests_screen.dart';
import 'package:oons/admin_v2/features/claims/claims_screen.dart';
import 'package:oons/admin_v2/features/corporate/corporate_screen.dart';
import 'package:oons/admin_v2/features/coupons/coupons_screen.dart';
import 'package:oons/admin_v2/features/customers/customer_detail_screen.dart';
import 'package:oons/admin_v2/features/customers/customers_screen.dart';
import 'package:oons/admin_v2/features/heatmap/heatmap_screen.dart';
import 'package:oons/admin_v2/features/home/home_screen.dart';
import 'package:oons/admin_v2/features/impersonate/impersonate_screen.dart';
import 'package:oons/admin_v2/features/ledger/ledger_screen.dart';
import 'package:oons/admin_v2/features/live/live_screen.dart';
import 'package:oons/admin_v2/features/live_map/live_map_screen.dart';
import 'package:oons/admin_v2/features/login/login_screen.dart';
import 'package:oons/admin_v2/features/payments/payments_screen.dart';
import 'package:oons/admin_v2/features/payouts/payouts_screen.dart';
import 'package:oons/admin_v2/features/providers/provider_detail_screen.dart';
import 'package:oons/admin_v2/features/providers/providers_screen.dart';
import 'package:oons/admin_v2/features/refunds/refunds_screen.dart';
import 'package:oons/admin_v2/features/staff/matrix_screen.dart';
import 'package:oons/admin_v2/features/staff/staff_screen.dart';
import 'package:oons/admin_v2/features/vetting/vetting_screen.dart';
import 'package:oons/admin_v2/features/vetting/worker_vetting_screen.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/theme.dart';

class OpsConsoleV2App extends ConsumerWidget {
  const OpsConsoleV2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeCodeProvider);
    final router = ref.watch(v2RouterProvider);
    return MaterialApp.router(
      title: 'Oons Ops',
      debugShowCheckedModeBanner: false,
      theme: opsV2Theme(arabic: lang == 'ar'),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

final v2RouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(staffSessionProvider, (_, __) => refresh.value++);
  return GoRouter(
    initialLocation: V2Paths.home,
    refreshListenable: refresh,
    redirect: (ctx, state) {
      final sess = ref.read(staffSessionProvider);
      if (!sess.ready) return null;
      final loggingIn = state.matchedLocation == V2Paths.login;
      if (!sess.authed && !loggingIn) return V2Paths.login;
      if (sess.authed && loggingIn) return V2Paths.home;
      return null;
    },
    routes: [
      GoRoute(path: V2Paths.login, builder: (_, __) => const V2LoginScreen()),
      ShellRoute(
        builder: (c, s, child) => V2Shell(child: child),
        routes: [
          GoRoute(path: V2Paths.home, builder: (_, __) => const HomeScreen()),
          GoRoute(path: V2Paths.live, builder: (_, __) => const LiveScreen()),
          GoRoute(
            path: V2Paths.bookings,
            builder: (_, s) => BookingsScreen(queryParams: s.uri.queryParameters),
          ),
          GoRoute(
            path: '${V2Paths.bookings}/:id',
            builder: (_, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!),
          ),
          GoRoute(path: V2Paths.customers, builder: (_, __) => const CustomersScreen()),
          GoRoute(
            path: '${V2Paths.customers}/:id',
            builder: (_, s) => CustomerDetailScreen(customerId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: V2Paths.providers,
            builder: (_, s) => ProvidersScreen(queryParams: s.uri.queryParameters),
          ),
          GoRoute(
            path: '${V2Paths.providers}/:id',
            builder: (_, s) => ProviderDetailScreen(providerId: s.pathParameters['id']!, initialTab: s.uri.queryParameters['tab']),
          ),
          GoRoute(path: V2Paths.claims, builder: (_, __) => const ClaimsScreen()),
          GoRoute(path: V2Paths.categoryRequests, builder: (_, __) => const CategoryRequestsScreen()),
          GoRoute(path: V2Paths.serviceRequests, builder: (_, __) => const ServiceRequestsScreen()),
          GoRoute(path: V2Paths.payouts, builder: (_, __) => const PayoutsScreen()),
          GoRoute(path: V2Paths.ledger, builder: (_, __) => const LedgerScreen()),
          GoRoute(path: V2Paths.coupons, builder: (_, __) => const CouponsScreen()),
          GoRoute(path: V2Paths.batches, builder: (_, __) => const BatchesScreen()),
          GoRoute(path: V2Paths.categories, builder: (_, __) => const CategoriesScreen()),
          GoRoute(path: V2Paths.areas, builder: (_, __) => const AreasScreen()),
          GoRoute(path: V2Paths.staff, builder: (_, __) => const StaffScreen()),
          GoRoute(path: V2Paths.matrix, builder: (_, __) => const MatrixScreen()),
          GoRoute(path: V2Paths.payments, builder: (_, __) => const PaymentsScreen()),
          GoRoute(path: V2Paths.corporate, builder: (_, __) => const CorporateScreen()),
          GoRoute(path: V2Paths.audit, builder: (_, __) => const AuditScreen()),
          GoRoute(path: V2Paths.heatmap, builder: (_, __) => const HeatmapScreen()),
          GoRoute(path: V2Paths.liveMap, builder: (_, __) => const LiveMapScreen()),
          GoRoute(path: V2Paths.vetting, builder: (_, __) => const VettingScreen()),
          GoRoute(path: V2Paths.workerVetting, builder: (_, __) => const WorkerVettingScreen()),
          GoRoute(path: V2Paths.refunds, builder: (_, __) => const RefundsScreen()),
          GoRoute(path: V2Paths.analytics, builder: (_, __) => const AnalyticsScreen()),
          GoRoute(
            path: '${V2Paths.impersonate}/:id',
            builder: (_, s) => ImpersonateScreen(
              id: s.pathParameters['id']!,
              kind: s.uri.queryParameters['kind'] ?? 'provider',
            ),
          ),
        ],
      ),
    ],
  );
});
