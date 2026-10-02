import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/features/subscriptions/subscribers_screen.dart';
import 'package:oons/admin_v2/theme/theme.dart';
import 'package:oons/data/api.dart';

import 'subscription_provider_fakes.dart';

class _Session extends StaffSession {
  _Session(String role) {
    state = StaffState(token: 't', staffRole: role, ready: true);
  }
}

class FakeSubsApi implements SubsApi {
  final calls = <Call>[];
  final routes = <String, FakeRoute>{};
  Future<Map<String, dynamic>> _do(String m, String p, {Object? data, Map<String, dynamic>? query}) async {
    final c = Call(m, p, data, query);
    calls.add(c);
    final h = routes['$m $p'];
    if (h == null) throw ApiException(404, 'مش موجود');
    final r = h(c);
    if (r is Exception) throw r;
    return Map<String, dynamic>.from(r as Map);
  }

  List<Call> where(String m, String p) => calls.where((c) => c.method == m && c.path == p).toList();
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _do('GET', path, query: query);
  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => _do('POST', path, data: data);
  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) => _do('PATCH', path, data: data);
}

Map<String, dynamic> _list(String status) => {
      'summary': {'active': 7, 'visitsThisWeek': 12},
      'provisional': {'atRiskRule': '2 consecutive skipped visits'},
      'rows': [
        {'id': 's1', 'customerName': 'منى سعيد', 'providerName': 'هبة علي', 'planTitle': 'نضافة شاملة', 'used': 2, 'minimum': 4, 'status': 'active', 'nextRenewal': '2026-11-01', 'lastPayment': '2026-10-01'},
        if (status == 'all' || status == 'at_risk') {'id': 's2', 'customerName': 'سلمى', 'providerName': 'نورا', 'planTitle': 'الأساسيات', 'used': 0, 'minimum': 4, 'status': 'at_risk', 'nextRenewal': '', 'lastPayment': ''},
      ],
    };

FakeSubsApi _api() {
  final a = FakeSubsApi();
  a.routes['GET /admin/subscriptions'] = (c) => _list('${c.query?['status']}');
  a.routes['GET /admin/subscriptions/settings'] = (_) => {'enabled': true, 'customerIds': ['c1'], 'providerIds': ['p1'], 'deepChecklist': <String>[], 'maintenanceChecklist': <String>[], 'providerCancelCreditEGP': 100};
  return a;
}

Future<void> pumpAdmin(WidgetTester t, FakeSubsApi api, {String role = roleOps}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [staffSessionProvider.overrideWith((ref) => _Session(role))],
    child: MaterialApp(
      theme: opsV2Theme(arabic: true),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SubscribersScreen(api: api)),
    ),
  ));
  await t.pumpAndSettle();
}

Future<void> tapK(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: key);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  test('the sidebar item is visible to ops (and not to finance); path registered', () {
    expect(canSeeScreen(roleOps, 'subscribers'), isTrue);
    expect(canSeeScreen(roleSuper, 'subscribers'), isTrue);
    expect(canSeeScreen(roleFinance, 'subscribers'), isFalse);
    expect(canSeeScreen(roleVendor, 'subscribers'), isFalse);
    final item = v2Nav.expand((g) => g.items).firstWhere((i) => i.id == 'subscribers');
    expect(item.path, V2Paths.subscribers);
    expect(item.labelAr, 'المشتركات');
  });

  testWidgets('rows, summary, provisional note and Arabic statuses', (t) async {
    final api = _api();
    await pumpAdmin(t, api);
    expect(find.text('٧ مشتركة نشطة · ١٢ زيارة الأسبوع ده'), findsOneWidget);
    expect(find.byKey(const Key('subs-provisional')), findsOneWidget);
    expect(find.text('منى سعيد'), findsOneWidget);
    expect(find.text('هبة علي'), findsOneWidget);
    expect(find.text('نضافة شاملة'), findsOneWidget);
    expect(find.text('٢ / ٤'), findsOneWidget);
    expect(find.text('نشطة'), findsWidgets);
    expect(find.text('٢٠٢٦-١١-٠١'), findsOneWidget);
    for (final english in ['Allowlist', 'Pause', 'Cancel', 'Move visit', 'Save allowlist', 'Credit', 'Refund']) {
      expect(find.text(english), findsNothing);
    }
    // ops: no allowlist/settings control (payments.settings is finance/super only)
    expect(find.byKey(const Key('subs-settings')), findsNothing);
  });

  testWidgets('status filters call the API with the status', (t) async {
    final api = _api();
    await pumpAdmin(t, api);
    expect(api.where('GET', '/admin/subscriptions').first.query, {'status': 'all'});
    await tapK(t, 'subs-filter-at_risk');
    expect(api.where('GET', '/admin/subscriptions').last.query, {'status': 'at_risk'});
    await tapK(t, 'subs-filter-paused');
    expect(api.where('GET', '/admin/subscriptions').last.query, {'status': 'paused'});
  });

  testWidgets('cancel shows the exact refund from the preview and needs confirmation', (t) async {
    final api = _api();
    api.routes['GET /admin/subscriptions/s1/cancel-preview'] = (_) => {'refundableVisits': 2, 'servicePiastres': 120000, 'feePiastres': 12000, 'totalPiastres': 132000};
    api.routes['POST /admin/subscriptions/s1/cancel'] = (_) => {'ok': true};
    await pumpAdmin(t, api);
    await tapK(t, 'cancel-s1');
    expect(api.where('GET', '/admin/subscriptions/s1/cancel-preview'), hasLength(1));
    expect(find.textContaining('١٬٣٢٠'.replaceAll('٬', '')), findsWidgets);
    expect(find.textContaining('هيتردّ للعميلة'), findsOneWidget);
    expect(api.where('POST', '/admin/subscriptions/s1/cancel'), isEmpty, reason: 'nothing happens before confirmation');
    await t.tap(find.text('لأ'.isEmpty ? '' : 'إلغاء').first);
    await t.pumpAndSettle();
    expect(api.where('POST', '/admin/subscriptions/s1/cancel'), isEmpty);
    await tapK(t, 'cancel-s1');
    await t.tap(find.textContaining('إلغاء وردّ'));
    await t.pumpAndSettle();
    expect(api.where('POST', '/admin/subscriptions/s1/cancel'), hasLength(1));
  });

  testWidgets('credit asks for an amount (no hard-coded value) and validates it', (t) async {
    final api = _api();
    api.routes['POST /admin/subscriptions/s1/credit'] = (_) => {'creditPiastres': 25000};
    await pumpAdmin(t, api, role: roleSuper);
    await tapK(t, 'credit-s1');
    // super may read settings: the configured default is prefilled
    expect(t.widget<TextField>(find.byKey(const Key('credit-amount'))).controller!.text, '100');
    await t.enterText(find.byKey(const Key('credit-amount')), '0');
    await t.tap(find.text('تأكيد'));
    await t.pumpAndSettle();
    expect(find.text('اكتبي مبلغ أكبر من صفر.'), findsOneWidget);
    expect(api.where('POST', '/admin/subscriptions/s1/credit'), isEmpty);
    await t.enterText(find.byKey(const Key('credit-amount')), '٢٥٠');
    await t.tap(find.text('تأكيد'));
    await t.pumpAndSettle();
    expect(api.where('POST', '/admin/subscriptions/s1/credit').single.body['egp'], 250);
  });

  testWidgets('pause confirms first; move needs date and time', (t) async {
    final api = _api();
    api.routes['POST /admin/subscriptions/s1/pause'] = (_) => {'ok': true};
    api.routes['POST /admin/subscriptions/visits/v9/move'] = (_) => {'ok': true};
    await pumpAdmin(t, api);
    await tapK(t, 'pause-s1');
    expect(find.text('توقّفي الاشتراك ده؟'), findsOneWidget);
    expect(api.where('POST', '/admin/subscriptions/s1/pause'), isEmpty);
    await t.tap(find.text('إيقاف').last);
    await t.pumpAndSettle();
    expect(api.where('POST', '/admin/subscriptions/s1/pause'), hasLength(1));
    await tapK(t, 'move-s1');
    await t.enterText(find.byKey(const Key('move-visit-id')), 'v9');
    await t.tap(find.text('تأكيد'));
    await t.pumpAndSettle();
    expect(find.text('اختاري التاريخ والميعاد.'), findsOneWidget);
    expect(api.where('POST', '/admin/subscriptions/visits/v9/move'), isEmpty);
  });

  testWidgets('settings live in a separate dialog, only for roles that may edit them', (t) async {
    final api = _api();
    api.routes['PATCH /admin/subscriptions/settings'] = (c) => c.body;
    await pumpAdmin(t, api, role: roleSuper);
    await tapK(t, 'subs-settings');
    expect(find.text('التجربة شغّالة'), findsOneWidget);
    expect(find.text('Allowlist'), findsNothing);
    await t.tap(find.text('حفظ'));
    await t.pumpAndSettle();
    final body = api.where('PATCH', '/admin/subscriptions/settings').single.body;
    expect(body['enabled'], true);
    expect(body['customerIds'], ['c1']);
    expect(body.containsKey('paymentMethods'), isFalse, reason: 'existing values are not overwritten with a constant');
  });

  testWidgets('load error is shown with retry', (t) async {
    final api = FakeSubsApi();
    api.routes['GET /admin/subscriptions'] = (_) => ApiException(500, 'تعذّر التحميل');
    await pumpAdmin(t, api);
    expect(find.text('تعذّر التحميل'), findsOneWidget);
  });
}
