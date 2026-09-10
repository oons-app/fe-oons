import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/app/shell.dart';
import 'package:oons/app/web_host.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/auth/auth_screens.dart';
import 'package:oons/data/models.dart';
import 'package:oons/features/book/book_screens.dart';
import 'package:oons/features/pay/payment_frame_screen.dart';
import 'package:oons/features/me/me_screens.dart';
import 'package:oons/features/bookings/bookings_screens.dart';
import 'package:oons/features/browse/browse_screens.dart';
import 'package:oons/features/pro/handshake_scan.dart';
import 'package:oons/features/pro/pro_screens.dart';
import 'package:oons/features/profile/alerts_screen.dart';
import 'package:oons/features/profile/profile_screen.dart';
import 'package:oons/features/reviews/reviews_screens.dart';
import 'package:oons/features/system/system_screens.dart';
import 'package:oons/features/visit/visit_screens.dart';
import 'package:oons/features/public/public_book_screen.dart';
import 'package:oons/features/legal/legal_screen.dart';

@visibleForTesting
String routePathFromUri(Uri uri) {
  var path = uri.path;
  if (path.isEmpty || path == '/') {
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      path = frag.startsWith('/') ? frag : '/$frag';
    }
  }
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path.isEmpty ? '/' : path;
}

@visibleForTesting
String routePath(GoRouterState st) => routePathFromUri(st.uri);

@visibleForTesting
bool isAuthGate(String loc) =>
    loc == '/auth' || loc == '/login' || loc == '/otp' || loc == '/register' || loc == '/pro/register' || loc.startsWith('/onboard');

@visibleForTesting
bool prefsOnboarded() {
  final v = Hive.box('prefs').get('onboarded');
  return v == true || v == 'true';
}

/// Auth / onboarding gate only. Never bounce a real tab back to Home or onboard.
@visibleForTesting
String? gateRedirect({
  required String loc,
  required bool onboarded,
  required bool authed,
  required bool provider,
  String? vanitySlug,
}) {
  if (vanitySlug != null && vanitySlug.isNotEmpty) {
    if (loc == '/' || loc.isEmpty || loc == '/index.html' || loc == '/home') {
      return '/p/$vanitySlug';
    }
  }
  final seenOnboard = onboarded || authed;
  if (loc.startsWith('/p/') || loc.startsWith('/legal')) return null;
  if (authed && isAuthGate(loc)) {
    final pending = Hive.box('prefs').get('pending_path');
    if (pending is String && pending.isNotEmpty) {
      Hive.box('prefs').delete('pending_path');
      return pending;
    }
    return provider ? '/pro/jobs' : '/home';
  }
  if (!authed && loc.startsWith('/onboard')) return null;
  if (!seenOnboard && !isAuthGate(loc) && !loc.startsWith('/p/') && !loc.startsWith('/legal')) return '/onboard/0';
  if (seenOnboard && !authed && !isAuthGate(loc) && !loc.startsWith('/p/') && !loc.startsWith('/legal')) return '/auth';
  if (authed && provider && (loc == '/home' || loc == '/bookings' || loc == '/profile' || loc == '/wallet')) {
    return '/pro/jobs';
  }
  if (authed && !provider && (loc == '/pro' || loc.startsWith('/pro/'))) return '/home';
  if (loc == '/' || loc.isEmpty || loc == '/index.html' || loc == '/wallet') {
    if (!seenOnboard) return '/onboard/0';
    if (!authed) return '/auth';
    return provider ? '/pro/jobs' : '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (ctx, st) {
      final sess = ref.read(sessionProvider);
      return gateRedirect(
        loc: routePath(st),
        onboarded: prefsOnboarded(),
        authed: sess.authed,
        provider: sess.isProvider,
        vanitySlug: kIsWeb ? bookingSlugForWebHost() : null,
      );
    },
    routes: [
      GoRoute(path: '/home', builder: (c, s) => const ClientShell(initialPath: '/home')),
      GoRoute(path: '/bookings', builder: (c, s) => const ClientShell(initialPath: '/bookings')),
      GoRoute(path: '/profile', builder: (c, s) => const ClientShell(initialPath: '/profile')),
      GoRoute(path: '/pro/jobs', builder: (c, s) => const ProShell(initialPath: '/pro/jobs')),
      GoRoute(path: '/pro/services', builder: (c, s) => const ProShell(initialPath: '/pro/services')),
      GoRoute(path: '/pro/earnings', builder: (c, s) => const ProShell(initialPath: '/pro/earnings')),
      GoRoute(path: '/pro/account', builder: (c, s) => const ProShell(initialPath: '/pro/account')),
      GoRoute(path: '/onboard/:i', builder: (c, s) => OnboardScreen(index: int.tryParse(s.pathParameters['i'] ?? '0') ?? 0)),
      GoRoute(path: '/legal/:id', builder: (c, s) => LegalScreen(docId: s.pathParameters['id']!)),
      GoRoute(path: '/auth', builder: (c, s) => const AuthScreen()),
      GoRoute(path: '/login', builder: (c, s) => const AuthScreen()),
      GoRoute(
        path: '/otp',
        builder: (c, s) {
          final role = isCustomerOnlyAuthHost() ? 'client' : (s.uri.queryParameters['role'] ?? 'client');
          return OtpScreen(
            phone: s.uri.queryParameters['phone'] ?? '',
            role: role,
            demo: s.uri.queryParameters['demo'] == '1',
          );
        },
      ),
      GoRoute(path: '/register', builder: (c, s) => ClientRegisterScreen(phone: s.uri.queryParameters['phone'] ?? '', code: s.uri.queryParameters['code'] ?? '')),
      GoRoute(path: '/pro/register', builder: (c, s) => ProRegisterScreen(phone: s.uri.queryParameters['phone'] ?? '', code: s.uri.queryParameters['code'] ?? '')),
      GoRoute(path: '/pro/job/:id', builder: (c, s) => ProJobScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/pro/handshake/:id', builder: (c, s) => HandshakeScanScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/pro/rate/:id', builder: (c, s) => ProRateScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/offline', builder: (c, s) => const SystemScreen(kind: 'offline')),
      GoRoute(path: '/error', builder: (c, s) => const SystemScreen(kind: 'error')),
      GoRoute(path: '/empty', builder: (c, s) => const SystemScreen(kind: 'empty')),
      GoRoute(path: '/payfail', builder: (c, s) => const SystemScreen(kind: 'payfail')),
      GoRoute(path: '/p/:slug', builder: (c, s) => PublicBookScreen(slug: s.pathParameters['slug']!)),
      GoRoute(
        path: '/browse/:service',
        builder: (c, s) => BrowseScreen(
          service: s.pathParameters['service']!,
          initialQuery: s.uri.queryParameters['q'],
        ),
      ),
      GoRoute(path: '/provider/:id', builder: (c, s) => ProviderScreen(id: s.pathParameters['id']!)),
      GoRoute(
        path: '/book/:id',
        builder: (c, s) => BookScreen(providerId: s.pathParameters['id']!, itemId: s.uri.queryParameters['item']),
      ),
      GoRoute(path: '/checkout/:id', builder: (c, s) => CheckoutScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(
        path: '/pay/:id/:method',
        builder: (c, s) => PaymentFrameScreen(
          bookingId: s.pathParameters['id']!,
          method: s.pathParameters['method'] ?? 'card',
        ),
      ),
      GoRoute(path: '/fawry/:id', builder: (c, s) => FawryScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/confirmed/:id', builder: (c, s) => ConfirmedScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/visit/:id', builder: (c, s) => VisitScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/booking/:id', builder: (c, s) => StatusScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/cancel/:id', builder: (c, s) => CancelScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/pcancel/:id', builder: (c, s) => ProviderCancelScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/share/:id', builder: (c, s) => ShareScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/rate/:id', builder: (c, s) => RateScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/dispute/:id', builder: (c, s) => DisputeScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/reschedule/:id', builder: (c, s) => RescheduleScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/me/addresses', builder: (c, s) => const AddressesScreen()),
      GoRoute(path: '/me/addresses/new', builder: (c, s) => const AddressFormScreen()),
      GoRoute(path: '/me/addresses/edit', builder: (c, s) => AddressFormScreen(existing: s.extra is Address ? s.extra as Address : null)),
      GoRoute(path: '/me/identity', builder: (c, s) => const ClientIdentityScreen()),
      GoRoute(path: '/me/instructions', builder: (c, s) => const InstructionsScreen()),
      GoRoute(path: '/me/instructions/new', builder: (c, s) => const InstructionFormScreen()),
      GoRoute(
        path: '/me/instructions/:id',
        builder: (c, s) => InstructionFormScreen(
          existing: s.extra is Instruction ? s.extra as Instruction : null,
          id: s.pathParameters['id'],
        ),
      ),
      GoRoute(path: '/me/saved', builder: (c, s) => const SavedScreen()),
      GoRoute(path: '/me/help', builder: (c, s) => const ProfileCopyScreen(titleKey: 'help', bodyKey: 'helpBody')),
      GoRoute(path: '/me/notif', builder: (c, s) => const AlertsScreen()),
      GoRoute(path: '/me/pay', builder: (c, s) => const ProfileCopyScreen(titleKey: 'pay', bodyKey: 'payBody')),
      GoRoute(path: '/reviews', builder: (c, s) => const ReviewsScreen()),
      GoRoute(path: '/reviews/:id', builder: (c, s) => ReviewsScreen(providerId: s.pathParameters['id'])),
    ],
  );
  router.routerDelegate.addListener(() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    // ignore: unawaited_futures
    AppAnalytics.logPageView(path);
  });
  return router;
});

@visibleForTesting
Widget routeRecovery(String path) {
  if (path == '/bookings' || path == '/profile') {
    return ClientShell(initialPath: path);
  }
  if (path.startsWith('/pro/')) {
    return ProShell(initialPath: path);
  }
  return const ClientShell(initialPath: '/home');
}
