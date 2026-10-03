import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/account_tab.dart';
import 'package:oons/features/pro/v2/details_page.dart';
import 'package:oons/features/pro/v2/legal_page.dart';
import 'package:oons/features/pro/v2/link_page.dart';

import 'pro_v2_fakes.dart';
import 'subscription_provider_fakes.dart';

Map<String, dynamic> richProfile({bool paused = false, bool linkClosed = false, bool complete = true, String idStatus = '', List<Map<String, dynamic>> domains = const []}) => providerJson(
      paused: paused,
      linkClosed: linkClosed,
      domains: domains,
      extra: {
        'payoutHandle': complete ? '01130031581' : '',
        'nationalId': complete ? '29901011234567' : '',
        'idPhotoUrl': complete ? '/uploads/id.jpg' : '',
        'fishPhotoUrl': complete ? '/uploads/fish.jpg' : '',
        'fishValidatedAt': '2026-01-02T00:00:00Z',
        'idDocStatus': idStatus,
        'bio': {'ar': 'نبذة', 'en': 'bio'},
      },
    );

List<GoRoute> stubRoutes(List<String> paths) => [for (final p in paths) GoRoute(path: p, builder: (c, s) => Scaffold(body: Text('STUB $p')))];

FakeApi plansApi(int n) => FakeApi()..routes['GET /pro/plans'] = (_) => {'plans': [for (var i = 0; i < n; i++) {'id': 'p$i', 'status': 'published'}]};

void main() {
  setUpAll(initHive);

  group('حسابي', () {
    Future<(FakeProRepo, FakeProSession)> open(WidgetTester t, {FakeProRepo? repo, int plans = 2}) async {
      phone(t, height: 2400);
      final r = repo ?? FakeProRepo(profile: richProfile());
      late FakeProSession session;
      await t.pumpWidget(proHost(
        Scaffold(body: ProAccountTab(plansApi: plansApi(plans))),
        repo: r,
        routes: stubRoutes(['/pro/link', '/pro/team', '/pro/coupons', '/pro/profile', '/me/notif', '/pro/legal', '/pro/plans']),
        extra: [sessionProvider.overrideWith((ref) => session = FakeProSession(r.profile))],
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      return (r, session);
    }

    testWidgets('profile card: name, experience, rating, verified badge', (t) async {
      await open(t);
      expect(find.text('ندى أحمد'), findsOneWidget);
      expect(find.textContaining('٣ سنين خبرة'), findsOneWidget);
      expect(find.text('٤٫٩'), findsOneWidget);
      expect(find.text('موثّقة'), findsOneWidget);
    });

    testWidgets('three groups with their rows and live values', (t) async {
      await open(t);
      for (final g in ['شغلي', 'ملفي', 'الإعدادات']) {
        expect(find.text(g), findsOneWidget);
      }
      for (final row in ['الباقات الشهرية', 'رابط الحجز', 'فريق العمل', 'الكوبونات', 'بياناتي وأوراقي', 'التنبيهات', 'اللغة', 'أعيدي الجولة السريعة', 'الشروط والسياسات']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('باقتين'), findsOneWidget);
      expect(find.text('مفتوح'), findsOneWidget);
      expect(find.text('مكتملة'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('a closed link and an incomplete file say so', (t) async {
      await open(t, repo: FakeProRepo(profile: richProfile(linkClosed: true, complete: false)));
      expect(find.text('مغلق'), findsOneWidget);
      expect(find.text('ناقصة'), findsOneWidget);
    });

    testWidgets('rows open their pages', (t) async {
      await open(t);
      for (final (label, stub) in [('رابط الحجز', '/pro/link'), ('بياناتي وأوراقي', '/pro/profile'), ('الشروط والسياسات', '/pro/legal'), ('فريق العمل', '/pro/team')]) {
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        expect(find.text('STUB $stub'), findsOneWidget, reason: label);
        Navigator.of(t.element(find.text('STUB $stub'))).pop();
        await t.pumpAndSettle();
      }
    });

    testWidgets('availability: saves by itself, the row turns attention-coloured, the copy changes', (t) async {
      final (repo, _) = await open(t);
      expect(find.text('متاحة للحجز'), findsOneWidget);
      await t.tap(find.byWidgetPredicate((w) => w is DsSwitch && w.label == 'متاحة للحجز'));
      await t.pump();
      expect(find.text('غير متاحة الآن'), findsOneWidget, reason: 'instant');
      expect(find.text('لن تظهرين في البحث'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      expect(repo.calls, ['patch available']);
      expect((repo.bodies['patch'] as Map)['available'], false);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a refused availability change goes back', (t) async {
      final (repo, _) = await open(t);
      repo.failNext = apiError('مقدرناش نغيّر حالتك');
      await t.tap(find.byWidgetPredicate((w) => w is DsSwitch && w.label == 'متاحة للحجز'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('متاحة للحجز'), findsOneWidget);
      expect(find.text('مقدرناش نغيّر حالتك'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('plans row shows for every provider on the pilot', (t) async {
      phone(t, height: 2400);
      final r = FakeProRepo(profile: providerJson(items: [svcJson('1', 'قص', cat: 'b-hair')])..['service'] = 'beauty');
      await t.pumpWidget(proHost(Scaffold(body: ProAccountTab(plansApi: plansApi(1))), repo: r));
      await t.pump();
      expect(find.text('الباقات الشهرية'), findsOneWidget);
    });

    testWidgets('sign out and delete are footer buttons; delete asks first', (t) async {
      final (_, session) = await open(t);
      expect(find.text('تسجيل خروج'), findsOneWidget);
      await t.tap(find.text('احذفي حسابي'));
      await t.pumpAndSettle();
      expect(find.text('تحذفين حسابك؟'), findsOneWidget);
      await t.tap(find.text('لا').first);
      await t.pumpAndSettle();
      expect(session.deletes, 0);
      await t.tap(find.text('احذفي حسابي'));
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byType(DsButton), matching: find.text('احذفي حسابي')).last);
      await t.pumpAndSettle();
      expect(session.deletes, 1);
      await t.tap(find.text('تسجيل خروج'));
      expect(session.signOuts, 1);
    });
  });

  group('رابط الحجز', () {
    Future<FakeProRepo> open(WidgetTester t, {FakeProRepo? repo}) async {
      phone(t, height: 2400);
      final r = repo ?? FakeProRepo(profile: richProfile());
      await t.pumpWidget(proHost(const ProLinkScreen(originTab: 3), repo: r));
      await t.pump();
      return r;
    }

    testWidgets('open/closed switch saves linkOpen by itself', (t) async {
      final r = await open(t);
      expect(find.text('الرابط مفتوح'), findsOneWidget);
      await t.tap(find.byWidgetPredicate((w) => w is DsSwitch && w.label == 'الرابط مفتوح'));
      await t.pump();
      expect(find.text('الرابط مغلق'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      expect(r.calls, ['patch linkOpen']);
      expect((r.bodies['patch'] as Map)['linkOpen'], false);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('invite: mono URL, copy puts it on the clipboard, WhatsApp is there', (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(t);
      expect(find.text('ادعي عميلات'), findsOneWidget);
      expect(find.textContaining('nada'), findsWidgets);
      expect(find.text('أرسليه عبر واتساب'), findsOneWidget);
      await t.tap(find.text('انسخي الرابط'));
      await t.pump();
      expect(copied, contains('nada'));
      expect(find.text('نُسخ الرابط'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('no link yet → an empty state instead of a blank box', (t) async {
      await open(t, repo: FakeProRepo(profile: providerJson(extra: {'slug': ''})));
      expect(find.text('لا رابط بعد'), findsOneWidget);
      expect(find.text('انسخي الرابط'), findsNothing);
    });

    testWidgets('custom domain: optional, add sends the host and shows the DNS hint', (t) async {
      final r = await open(t);
      expect(find.text('دومين خاص'), findsOneWidget);
      expect(find.text('· اختياري'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'book.nada.com');
      await t.tap(find.text('أضيفي الدومين'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(r.calls, ['domain book.nada.com']);
      expect(find.text('book.nada.com'), findsOneWidget);
      debugPrint('TEXTS: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).where((d) => d != null && true).toList()}');
      expect(find.text('CNAME book → oons.app'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('breadcrumb names the place she came from', (t) async {
      await open(t);
      expect(find.text('حسابي'), findsOneWidget);
    });
  });

  group('بياناتي وأوراقي', () {
    Future<FakeProRepo> open(WidgetTester t, {FakeProRepo? repo}) async {
      phone(t, height: 3000);
      final r = repo ?? FakeProRepo(profile: richProfile());
      await t.pumpWidget(proHost(const ProDetailsScreen(), repo: r));
      await t.pump();
      return r;
    }

    test('doc state: no file, accepted, rejected, in review; vetted means confirmed when staff set nothing', () {
      expect(docState(hasFile: false, status: '', vetted: true), DocState.missing);
      expect(docState(hasFile: true, status: 'accepted', vetted: false), DocState.confirmed);
      expect(docState(hasFile: true, status: 'rejected', vetted: true), DocState.rejected);
      expect(docState(hasFile: true, status: 'pending', vetted: true), DocState.inReview);
      expect(docState(hasFile: true, status: '', vetted: true), DocState.confirmed);
      expect(docState(hasFile: true, status: '', vetted: false), DocState.inReview);
    });

    testWidgets('fields are filled from her profile and save as one patch', (t) async {
      final r = await open(t);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      expect(find.widgetWithText(TextField, '01130031581'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, '3'), '٥');
      await t.tap(find.text('احفظي'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      final body = r.bodies['patch'] as Map;
      expect(body['years'], 5, reason: 'Arabic digits are accepted');
      expect(body['payoutHandle'], '01130031581');
      expect(body.keys.toSet(), {'years', 'payoutHandle', 'bio'});
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('papers: confirmed ones carry the olive «اتأكد»; a rejected one says so', (t) async {
      await open(t, repo: FakeProRepo(profile: richProfile(idStatus: 'rejected')));
      expect(find.text('الأوراق'), findsOneWidget);
      expect(find.text('الرقم القومي'), findsOneWidget);
      expect(find.text('صورة البطاقة'), findsOneWidget);
      expect(find.text('الفيش والتشبيه'), findsOneWidget);
      expect(find.text('مرفوض. ارفعيه مرة أخرى'), findsWidgets);
      expect(find.text('مؤكد'), findsWidgets);
      expect(find.text('رُوجعت كلها'), findsNothing, reason: 'one paper is not confirmed');
    });

    testWidgets('all confirmed → «رُوجعت كلها»', (t) async {
      await open(t);
      expect(find.text('رُوجعت كلها'), findsOneWidget);
    });

    testWidgets('portfolio: an add tile with the camera', (t) async {
      await open(t);
      expect(find.text('صور من عملك'), findsOneWidget);
      expect(find.text('أضيفي صورا'), findsOneWidget);
    });
  });

  testWidgets('legal: one page with all five documents', (t) async {
    phone(t);
    await t.pumpWidget(proHost(const ProLegalScreen(), repo: FakeProRepo(profile: providerJson()), routes: stubRoutes(['/legal/:id'])));
    await t.pump();
    expect(find.text('الشروط والسياسات'), findsOneWidget);
    expect(find.byType(DsListRow), findsNWidgets(5));
  });
}
