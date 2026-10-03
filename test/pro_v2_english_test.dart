import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/features/pro/v2/account_tab.dart';
import 'package:oons/features/pro/v2/earnings_tab.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/services_tab.dart';
import 'package:oons/features/pro/v2/specialty_page.dart';
import 'package:oons/features/pro/v2/visits_tab.dart';

import 'pro_v2_fakes.dart';
import 'subscription_provider_fakes.dart';

/// The English locale keeps working: every tab renders in English with plain
/// digits, no exceptions, and no Arabic strings leaking through.
void main() {
  setUpAll(initHive);

  bool hasArabic(WidgetTester t) => t.widgetList<Text>(find.byType(Text)).any((w) => RegExp(r'[؀-ۿ]').hasMatch(w.data ?? ''));

  FakeProRepo repo() => FakeProRepo(
        profile: providerJson(items: [
          svcJson('1', 'Premium clean', priceEgp: 1200, benefits: ['Same cleaner']),
          svcJson('t1', 'Tier', kind: 'cleaning', from: 120, to: 150, priceEgp: 800),
        ]),
        categoryRows: [
          {...catRow('c-reg', 'x', 'cleaning', 'active'), 'name': {'en': 'Regular cleaning', 'ar': 'تنظيف عادي'}},
          {...catRow('b-nails', 'x', 'beauty', 'pending_addition_approval'), 'name': {'en': 'Nails', 'ar': 'أظافر'}},
        ],
      )
        ..earningsData = {
          'heroAmount': 80000,
          'cadence': 'weekly',
          'nextSettlementAt': '2026-10-06T10:00:00',
          'cycleLines': [],
          'categories': [],
        };

  testWidgets('services tab', (t) async {
    phone(t);
    ProNav.servicesSeg.value = 0;
    await t.pumpWidget(proHost(const Scaffold(body: ProServicesTab()), repo: repo(), lang: 'en'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Services'), findsWidgets);
    expect(find.text('Home cleaning'), findsOneWidget);
    expect(find.text('1 specialty · 2 services'), findsOneWidget);
    expect(find.text('Request a new specialty'), findsOneWidget);
    expect(find.text('In review'), findsOneWidget);
    expect(hasArabic(t), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('areas and hours segments', (t) async {
    phone(t);
    ProNav.servicesSeg.value = ProNav.segHours;
    await t.pumpWidget(proHost(const Scaffold(body: ProServicesTab()), repo: repo(), lang: 'en'));
    await t.pump();
    expect(find.text('Work days'), findsOneWidget);
    expect(find.text('Sat'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    ProNav.servicesSeg.value = ProNav.segAreas;
    await t.pump();
    expect(find.text('Only clients in these areas can book you.'), findsOneWidget);
    expect(hasArabic(t), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('specialty page', (t) async {
    phone(t, height: 2000);
    await t.pumpWidget(proHost(const ProSpecialtyScreen(categoryId: 'c-reg'), repo: repo(), lang: 'en'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Services · Home cleaning'), findsOneWidget);
    expect(find.text('Prices by area'), findsOneWidget);
    expect(find.text('120–150 m²'.replaceAll('m²', 'م²')), findsOneWidget, reason: 'unit stays m²');
    expect(find.text('1,200 EGP'), findsOneWidget);
    expect(find.text('Net 1,080'), findsOneWidget);
    expect(find.text('New service in Regular cleaning'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('visits tab', (t) async {
    phone(t, height: 2000);
    final r = repo()..upcomingJobs = [jobBundle('a', '2026-10-03T09:00:00', client: 'Mona', service: 'Premium clean', planTag: 'x')];
    await t.pumpWidget(proHost(Scaffold(body: ProVisitsTab(now: () => DateTime(2026, 10, 3, 8))), repo: r, lang: 'en', routes: [GoRoute(path: '/pro/job/:id', builder: (c, s) => const SizedBox())]));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Saturday 3 Oct'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('1 visit'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('earnings tab', (t) async {
    phone(t, height: 2000);
    await t.pumpWidget(proHost(const Scaffold(body: ProEarningsTab()), repo: repo(), lang: 'en'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Available to withdraw'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Settlement cycle'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('account tab', (t) async {
    phone(t, height: 2400);
    await t.pumpWidget(proHost(Scaffold(body: ProAccountTab(plansApi: FakeApi()..routes['GET /pro/plans'] = (_) => {'plans': []})), repo: repo(), lang: 'en'));
    await t.pump();
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('My work'), findsOneWidget);
    expect(find.text('Available for booking'), findsOneWidget);
    expect(find.text('Booking link'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
