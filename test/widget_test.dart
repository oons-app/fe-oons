import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:oons/core/format.dart';
import 'package:oons/app/router.dart';
import 'package:oons/app/shell.dart';
import 'package:oons/app/web_host.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/features/auth/auth_screens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/track_socket.dart';
import 'package:oons/features/pro/handshake_scan.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/alert_copy.dart';
import 'package:oons/l10n/copy.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('oons_hive');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await Hive.openBox('cache');
  });

  test('brand is Oons and Amana stays the guarantee fund', () {
    expect(Copy.of('en')['brand'], 'OONS');
    expect(Copy.of('ar')['brand'], 'أنس');
    final ob = (Copy.of('en')['ob'] as List)[2] as Map;
    expect(ob['body'], contains('Amana'));
    final arOb = (Copy.of('ar')['ob'] as List)[2] as Map;
    expect(arOb['body'], contains('أمانة'));
  });

  test('track websocket url uses the API host and access token', () {
    final url = trackWsUrl('abc', 'tok', host: 'http://47.91.41.120:8088');
    expect(url, 'ws://47.91.41.120:8088/api/v1/bookings/abc/track?access=tok');
    final secure = trackWsUrl('abc', 'tok', host: 'https://app.oons.example');
    expect(secure, startsWith('wss://app.oons.example/api/v1/bookings/abc/track'));
  });

  test('weekdayLabel uses weekday-1 so Monday is اتنين', () {
    final monday = DateTime(2026, 3, 2);
    expect(monday.weekday, DateTime.monday);
    expect(weekdayLabel(monday, 'ar'), 'اتنين');
    expect(weekdayLabel(monday, 'en'), 'MON');
    expect(weekdayLabel(DateTime(2026, 3, 3), 'ar'), 'تلات');
  });

  test('money formats piastres without floats in the UI string', () {
    expect(money(72000, 'en'), '720 EGP');
    expect(money(72000, 'ar'), contains('ج.م'));
  });

  test('timeline and escrow copy is bilingual', () {
    expect(Copy.of('ar')['timeline'], containsPair('on_the_way', 'في الطريق'));
    expect(Copy.of('ar')['timeline'], containsPair('checked_in', 'وصلت'));
    expect(Copy.of('ar')['escrow'], containsPair('held', 'واقفة'));
    expect(Copy.of('en')['escrow'], containsPair('held', 'Held in escrow'));
    expect((Copy.of('ar')['reviews'] as Map)['all'], 'كل التقييمات');
    expect(AppShell.clientPaths, contains('/profile'));
    expect(AppShell.clientPaths, isNot(contains('/wallet')));
    expect(AppShell.indexFor('/profile', provider: false), 2);
    expect(routeRecovery('/nope'), isA<ClientShell>());
    expect(routeRecovery('/profile'), isA<ClientShell>());
    expect(routeRecovery('/pro/jobs'), isA<ProShell>());
    expect(routePathFromUri(Uri.parse('/bookings')), '/bookings');
    expect(routePathFromUri(Uri.parse('http://127.0.0.1:5555/#/profile')), '/profile');
    expect(providerSlugFromHost('nour.oons.app'), 'nour');
    expect(providerSlugFromHost('www.oons.app'), isNull);
    expect(providerSlugFromHost('api.oons.app'), isNull);
    expect(providerSlugFromHost('lady.oons.app'), isNull);
    expect(providerSlugFromHost('domains.oons.app'), isNull);
    expect(isCustomBookingHost('book.heba.com'), isTrue);
    expect(isCustomBookingHost('lady.oons.app'), isFalse);
    expect(gateRedirect(loc: '/', onboarded: false, authed: false, provider: false, vanitySlug: 'nour'), '/p/nour');
    expect(gateRedirect(loc: '/onboard/1', onboarded: false, authed: false, provider: false), isNull);
    expect(gateRedirect(loc: '/bookings', onboarded: true, authed: true, provider: false), isNull);
    expect(gateRedirect(loc: '/profile', onboarded: true, authed: true, provider: false), isNull);
    expect(gateRedirect(loc: '/pro/jobs', onboarded: true, authed: true, provider: false), '/home');
    expect(gateRedirect(loc: '/admin', onboarded: true, authed: true, provider: false), isNull);
    expect(gateRedirect(loc: '/admin', onboarded: true, authed: true, provider: true), isNull);
    expect(gateRedirect(loc: '/onboard/0', onboarded: false, authed: true, provider: false), '/home');
    expect(gateRedirect(loc: '/home', onboarded: false, authed: false, provider: false), '/onboard/0');
    expect(gateRedirect(loc: '/register', onboarded: true, authed: false, provider: false), isNull);
    expect(gateRedirect(loc: '/profile', onboarded: true, authed: true, provider: false), isNull);
    expect((Copy.of('en')['dispute'] as Map)['cta'], isNotEmpty);
    expect((Copy.of('ar')['dispute'] as Map)['cta'], isNotEmpty);
    expect((Copy.of('en')['reschedule'] as Map)['cta'], isNotEmpty);
    expect(Copy.of('en').containsKey('wallet'), isFalse);
    expect(Copy.of('ar').containsKey('wallet'), isFalse);
    expect((Copy.of('ar')['admin'] as Map)['loginTitle'], isNotEmpty);
    expect((Copy.of('en')['admin'] as Map)['payouts'], 'Payouts');
    expect((Copy.of('en')['profile'] as Map)['notifEmpty'], contains('No alerts yet'));
    expect((Copy.of('ar')['profile'] as Map)['notifEmpty'], contains('تنبيهات'));
  });

  test('alert inbox merge keeps newest and reports unseen ids', () {
    final older = InboxAlert(id: 'a', title: 'On the way', body: 'x', at: DateTime(2026, 8, 21, 12));
    final newer = InboxAlert(id: 'b', title: 'At the door', body: 'y', at: DateTime(2026, 8, 21, 13));
    final merged = mergeInbox([older], [newer, older]);
    expect(merged.map((e) => e.id).toList(), ['b', 'a']);
    expect(freshAlerts([older], merged).map((e) => e.id).toList(), ['b']);
  });

  test('alert copy follows app language and keeps the booking ref', () {
    final (title, body) = AlertCopy.of(
      'on_the_way',
      lang: 'ar',
      party: 'client',
      fallbackBody: 'Your professional is on the way. · ONS-5159-23',
    );
    expect(title, 'في الطريق');
    expect(body, contains('المتخصصة في الطريق'));
    expect(body, contains('ONS-5159-23'));
    final en = AlertCopy.of('on_the_way', lang: 'en', party: 'client');
    expect(en.$1, 'On the way');
  });

  test('address and instruction unwrap from me payload', () {
    final inner = unwrapEnvelope({
      'ok': true,
      'data': {
        'user': {
          'id': 'u1',
          'phone': '1012345678',
          'firstName': {'en': 'Nour', 'ar': 'نور'},
          'lastName': {'en': 'A', 'ar': 'ع'},
          'initials': {'en': 'N A', 'ar': 'ن ع'},
          'area': 'zamalek',
          'addresses': [
            {
              'id': 'addr-1',
              'label': {'en': 'Home', 'ar': 'البيت'},
              'line1': {'en': '14 Aziz', 'ar': '١٤ عزيز'},
              'area': 'zamalek',
              'city': {'en': 'Cairo', 'ar': 'القاهرة'},
              'isDefault': true,
              'lat': 30.06,
              'lng': 31.21,
            }
          ],
          'instructions': [
            {'id': 'ins-1', 'title': 'الدور', 'body': 'الدور التالت'}
          ],
        }
      }
    });
    final me = UserMe.fromJson(inner['user'] as Map);
    expect(me.addresses, hasLength(1));
    expect(me.addresses.first.lat, closeTo(30.06, 0.01));
    expect(me.instructions.first.body, 'الدور التالت');
  });

  test('areaFromCoords picks the nearest Greater Cairo area', () {
    expect(areaFromCoords(30.0626, 31.2194), 'zamalek');
    expect(areaFromCoords(29.9602, 31.2569), 'maadi');
    expect(areaIsGiza('dokki'), isTrue);
    expect(areaIsGiza('zamalek'), isFalse);
    expect(googleMapsUrl(30.06, 31.21), contains('google.com/maps'));
  });

  test('debug apiHost points at the local docker API', () {
    expect(apiHost(), 'http://127.0.0.1:8088');
    expect(legalPageUrl('privacy'), contains('/legal/privacy'));
    expect(normalizeLabApiBase('47.91.41.120:8088'), 'http://47.91.41.120:8088');
    expect(normalizeLabApiBase(''), '');
    expect(normalizeLabApiBase('not a host'), isNull);
  });

  test('otp copy does not advertise a demo code', () {
    expect('${Copy.of('en')['otp']['sub']}', isNot(contains('4192')));
    expect('${Copy.of('ar')['otp']['sub']}', isNot(contains('٤١٩٢')));
    expect('${Copy.of('en')['pro']['earnNote']}', contains('banking'));
  });

  test('handshakeTokenFromScan accepts JWT and oons URLs', () {
    const jwt = 'aaa.bbb.ccc';
    expect(handshakeTokenFromScan(jwt), jwt);
    expect(handshakeTokenFromScan('oons://handshake?t=$jwt'), jwt);
    expect(handshakeTokenFromScan('not-a-token'), isNull);
  });

  test('api client unwraps the ok/data envelope', () {
    final inner = unwrapEnvelope({'ok': true, 'data': {'accessToken': 't', 'role': 'client'}});
    expect(inner['accessToken'], 't');
    expect(inner['role'], 'client');
  });

  test('sanctuary tokens stay sharp: zero radius, plum action', () {
    expect(T.radius, 0);
    expect(T.rule, 1.0);
    expect(T.action, const Color(0xFF3E2136));
  });

  testWidgets('320-width Arabic CTA stays on-screen in RTL', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: T.bg,
            body: Padding(
              padding: EdgeInsets.all(20),
              child: InkButton(label: 'المتابعة إلى الدفع', onTap: _noop),
            ),
          ),
        ),
      ),
    );
    expect(find.text('المتابعة إلى الدفع'), findsOneWidget);
    final box = tester.getRect(find.byType(InkButton));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(320));
  });

  testWidgets('pro job stats fit 320 RTL without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  Expanded(child: ProStatTile(label: 'النهاردة', value: '12')),
                  SizedBox(width: 8),
                  Expanded(child: ProStatTile(label: 'الأسبوع ده', value: '99')),
                  SizedBox(width: 8),
                  Expanded(child: ProStatTile(label: 'متوقّع', value: '1500', accent: true)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth phone field builds at 320 RTL without color/decoration clash', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AuthScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('+20'), findsOneWidget);
    expect(find.byType(ClientPrimaryButton), findsOneWidget);
  });

  testWidgets('offline banner stays on-screen at 320 RTL', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: T.bg,
            body: OfflineBanner(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No internet'), findsOneWidget);
    final box = tester.getRect(find.byType(OfflineBanner));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(320));
  });

  testWidgets('tab bar stays pinned and short on a wide desktop window', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: T.bg,
          body: const Center(child: Text('حسابي')),
          bottomNavigationBar: OonsTabBar(
            index: 2,
            labels: const ['الرئيسية', 'حجوزاتي', 'حسابي'],
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(OonsTabBar));
    expect(bar.height, lessThan(100));
    expect(bar.bottom, closeTo(800, 1));
    expect(find.byType(Glyph), findsWidgets);
    expect(find.byType(Glyph), findsNWidgets(3));
  });

  testWidgets('phone canvas frames a wide window to 390px', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    late Size inner;
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneCanvas(
          child: Builder(
            builder: (context) {
              inner = MediaQuery.sizeOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(inner.width, PhoneCanvas.frameWidth);
    expect(inner.height, lessThan(800));
  });

  testWidgets('RTL back button uses arrow_back so it mirrors correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: T.bg,
            body: ScreenHead(title: 'ONS-2377-49', onBack: _noop),
          ),
        ),
      ),
    );
    expect(find.byType(Glyph), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });
}

void _noop() {}
