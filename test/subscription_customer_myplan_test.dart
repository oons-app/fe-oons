import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/month_dates_copy.dart' show subApi;
import 'package:oons/features/subscribe/month_dates_screen.dart';
import 'package:oons/features/subscribe/my_plan_screens.dart';

import 'subscription_customer_fakes.dart';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump();
}

Map<String, dynamic> subResponse({String status = 'active', bool makeup = true}) => {
      'subscription': {
        'id': 's1',
        'status': status,
        'title': '١ تنظيف مميز + ٣ عادي في الشهر',
        'providerName': 'ندى',
        'used': 1,
        'minimum': 4,
        'makeupDeadline': '2026-10-28',
        'paymentMethod': 'card',
        'planSnapshot': {
          'paygPiastres': 334500,
          'pricePiastres': 290000,
          'feePiastres': 29000,
          'totalPiastres': 319000,
          'lines': [
            {'visitType': 'deep', 'quantity': 1, 'catalogItemId': 'cd', 'name': {'ar': 'تنظيف مميز'}},
            {'visitType': 'regular', 'quantity': 3, 'catalogItemId': 'cr', 'name': {'ar': 'تنظيف عادي'}},
          ],
        },
      },
      'cycle': {'id': 'c1', 'startsOn': '2026-10-03', 'endsOn': '2026-11-01', 'status': 'paid', 'paidAt': '2026-10-02T10:00:00+03:00', 'pricePiastres': 290000, 'feePiastres': 29000, 'totalPiastres': 319000},
      'visits': [
        {'id': 'v1', 'status': 'done', 'type': 'deep', 'catalogItemId': 'cd', 'date': '2026-10-03', 'time': '11:00', 'timeLabel': '١١ ص'},
        {'id': 'v2', 'status': 'skipped', 'type': 'regular', 'catalogItemId': 'cr', 'date': '2026-10-10', 'time': '11:00', 'timeLabel': '١١ ص'},
        {'id': 'v3', 'status': 'booked', 'type': 'regular', 'catalogItemId': 'cr', 'date': '2026-10-17', 'time': '11:00', 'timeLabel': '١١ ص', 'canSkip': true, 'canReschedule': true},
        if (makeup) {'id': 'v4', 'status': 'needs_date', 'type': 'regular', 'catalogItemId': 'cr', 'date': '', 'isMakeup': true, 'makeupReason': 'skipped', 'canPlace': true},
      ],
    };

FakeSubApi _api({Map<String, Object?> more = const {}}) => FakeSubApi({
      'GET /subscriptions': {'subscriptions': [{'id': 's1'}]},
      'GET /subscriptions/s1': subResponse(),
      ...more,
    });

class _Offline extends ApiClient {
  _Offline() : super(baseUrl: 'http://fake.invalid');
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async => throw ApiException(0, 'offline');
  @override
  Future<Map<String, dynamic>> post(String path, {Object? data, String? idem}) async => throw ApiException(0, 'offline');
}

void main() {
  group('S5 my plan', () {
    testWidgets('summary card, Arabic tags, make-up row, no raw status strings', (t) async {
      _phone(t);
      await t.pumpWidget(host(const MyPlanScreen(), api: _api()));
      await _settle(t);
      expect(find.text('١ تنظيف مميز + ٣ عادي في الشهر'), findsOneWidget);
      expect(find.text('مع ندى'), findsOneWidget);
      expect(find.text('١ من ٤ زيارات اتعملت الدورة دي'), findsOneWidget);
      expect(find.textContaining('الدورة: ٣ أكتوبر لحد ١ نوفمبر · اتدفعت مقدّم'), findsOneWidget);
      expect(find.text('اتعملت'), findsOneWidget);
      expect(find.text('اتخطّتيها'), findsOneWidget);
      expect(find.text('جاية'), findsOneWidget);
      expect(find.text('تنظيف عادي · بدل اللي اتخطّت'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-visit')), findsOneWidget);
      expect(find.text('السبت ١٧ أكتوبر · ١١ ص'), findsWidgets);
      expect(find.textContaining('booked'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
      expect(find.text(CC.s5Cancel), findsOneWidget);
    });

    testWidgets('cancel is a plain text link, not a filled button', (t) async {
      _phone(t);
      await t.pumpWidget(host(const MyPlanScreen(), api: _api()));
      await _settle(t);
      final text = t.widget<Text>(find.text(CC.s5Cancel));
      expect(text.style!.color, isNot(equals(Colors.white)));
      final box = find.ancestor(of: find.text(CC.s5Cancel), matching: find.byType(Container)).first;
      expect((t.widget<Container>(box).decoration), isNull);
      expect(t.getSize(find.ancestor(of: find.text(CC.s5Cancel), matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(44));
    });

    testWidgets('skip: confirm dialog states the make-up deadline and posts skip', (t) async {
      _phone(t);
      final api = _api(more: {'POST /subscriptions/s1/visits/v3/skip': {'ok': true}});
      await t.pumpWidget(host(const MyPlanScreen(), api: api));
      await _settle(t);
      await t.tap(find.text(CC.s5Skip));
      await _settle(t);
      expect(find.text(CC.s5SkipTitle), findsOneWidget);
      expect(find.textContaining('الأربع ٢٨ أكتوبر'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('بتضيع')), findsOneWidget);
      await t.tap(find.text(CC.s5Confirm));
      await _settle(t);
      expect(api.calls, contains('POST /subscriptions/s1/visits/v3/skip'));
    });

    testWidgets('skip 409 message from the server is shown in Arabic', (t) async {
      _phone(t);
      final api = _api(more: {'POST /subscriptions/s1/visits/v3/skip': ApiException(409, 'تقدري تتخطّي زيارة واحدة في الدورة.')});
      await t.pumpWidget(host(const MyPlanScreen(), api: api));
      await _settle(t);
      await t.tap(find.text(CC.s5Skip));
      await _settle(t);
      await t.tap(find.text(CC.s5Confirm));
      await _settle(t);
      expect(find.text('تقدري تتخطّي زيارة واحدة في الدورة.'), findsOneWidget);
    });

    testWidgets('pause confirm, then resume shown for a scheduled pause; 404 resume is handled', (t) async {
      _phone(t);
      final api = _api(more: {'POST /subscriptions/s1/pause': {'ok': true}});
      await t.pumpWidget(host(const MyPlanScreen(), api: api));
      await _settle(t);
      await t.tap(find.text(CC.s5Pause));
      await _settle(t);
      expect(find.text(CC.s5PauseTitle), findsOneWidget);
      expect(find.textContaining('الدورة الجاية'), findsOneWidget);
      await t.tap(find.text(CC.s5Confirm));
      await _settle(t);
      expect(api.calls, contains('POST /subscriptions/s1/pause'));

      final paused = subResponse(status: 'paused');
      final api2 = _api(more: {'GET /subscriptions/s1': paused});
      await t.pumpWidget(host(const MyPlanScreen(id: 's1'), api: api2));
      await _settle(t);
      expect(find.text(CC.s5Resume), findsOneWidget);
      await t.tap(find.text(CC.s5Resume));
      await _settle(t);
      await t.tap(find.text(CC.s5Confirm));
      await _settle(t);
      expect(find.text('مش لاقيين ده. ممكن يكون اتغيّر.'), findsOneWidget);
    });

    testWidgets('back button when pushed (e.g. from Profile)', (t) async {
      _phone(t);
      await t.pumpWidget(host(Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => c.push('/me/plan'), child: const Text('go')))), api: _api()));
      await t.pump();
      await t.tap(find.text('go'));
      await _settle(t);
      expect(find.bySemanticsLabel('رجوع'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('رجوع'));
      await _settle(t);
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('error is shown with the server Arabic message, never raw', (t) async {
      _phone(t);
      final api = FakeSubApi({'GET /subscriptions/s1': ApiException(500, 'حصلت مشكلة عندنا')});
      await t.pumpWidget(host(const MyPlanScreen(id: 's1'), api: api));
      await _settle(t);
      expect(find.text('حصلت مشكلة عندنا'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('reschedule pushes RescheduleVisitScreen with the next visit id; make-up entry uses the make-up id', (t) async {
      _phone(t);
      subApi = _Offline();
      addTearDown(() => subApi = api);
      await t.pumpWidget(host(const MyPlanScreen(), api: _api()));
      await _settle(t);
      await t.tap(find.text(CC.s5Reschedule));
      await _settle(t);
      var screen = t.widget<RescheduleVisitScreen>(find.byType(RescheduleVisitScreen));
      expect(screen.subscriptionId, 's1');
      expect(screen.visitId, 'v3');
      Navigator.of(t.element(find.byType(RescheduleVisitScreen))).pop();
      await _settle(t);
      await t.scrollUntilVisible(find.text(CC.s5PlaceMakeup), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text(CC.s5PlaceMakeup));
      await _settle(t);
      screen = t.widget<RescheduleVisitScreen>(find.byType(RescheduleVisitScreen));
      expect(screen.visitId, 'v4');
    });
  });

  group('cancel flow', () {
    FakeSubApi api0({Object? cancel}) => FakeSubApi({
          'GET /subscriptions/s1/cancel-preview': {
            'refundableVisits': 3,
            'plannedVisits': 4,
            'servicePiastres': 217500,
            'feePiastres': 21800,
            'totalPiastres': 239300,
            'reasons': [
              {'key': 'price', 'label': 'السعر'},
              {'key': 'other', 'label': 'سبب تاني'},
            ],
          },
          'POST /subscriptions/s1/cancel': cancel ?? {'ok': true, 'refundedPiastres': 239300},
        });

    testWidgets('shows the EXACT refund from the preview; reason required; posts reason+note', (t) async {
      _phone(t);
      final api = api0();
      await t.pumpWidget(host(const CancelPlanScreen(subscriptionId: 's1'), api: api));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('cancel-refund'))).data, '٢,٣٩٣ ج.م');
      await t.tap(find.text(CC.cancelConfirm));
      await _settle(t);
      expect(api.calls.where((c) => c.startsWith('POST')), isEmpty);
      await t.tap(find.text('السعر'));
      await t.pump();
      await t.enterText(find.byType(TextField), 'غالية شوية');
      await t.ensureVisible(find.text(CC.cancelConfirm));
      await t.tap(find.text(CC.cancelConfirm));
      await _settle(t);
      expect(api.bodies['POST /subscriptions/s1/cancel'], {'reason': 'price', 'note': 'غالية شوية'});
      expect(find.text(CC.cancelDone), findsOneWidget);
      expect(find.textContaining('٢,٣٩٣'), findsOneWidget);
    });

    testWidgets('server error on cancel is shown in Arabic', (t) async {
      _phone(t);
      await t.pumpWidget(host(const CancelPlanScreen(subscriptionId: 's1'), api: api0(cancel: ApiException(409, 'الباقة اتلغت قبل كده.'))));
      await _settle(t);
      await t.tap(find.text('سبب تاني'));
      await t.pump();
      await t.tap(find.text(CC.cancelConfirm));
      await _settle(t);
      expect(find.text('الباقة اتلغت قبل كده.'), findsOneWidget);
    });
  });

  group('S6 billing', () {
    FakeSubApi api0({Object? receipt}) => FakeSubApi({
          'GET /subscriptions/s1': subResponse(),
          'GET /subscriptions/s1/cycles/c1/receipt': receipt ?? {'price': 290000, 'fee': 29000, 'total': 319000, 'url': 'https://example.test/r.pdf'},
        });

    testWidgets('amounts, itemised visits, savings strip, draft box, no redundant line', (t) async {
      _phone(t);
      await t.pumpWidget(host(const PlanBillScreen(id: 's1'), api: api0()));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('bill-total-head'))).data, '٣,١٩٠ ج.م');
      expect(t.widget<Text>(find.byKey(const ValueKey('bill-total'))).data, '٣,١٩٠ ج.م');
      expect(find.text(CC.s6Saved('٤٤٥')), findsOneWidget);
      expect(find.text(CC.s6DraftLabel), findsOneWidget);
      expect(find.text(CC.s6Visits), findsOneWidget);
      expect(find.text('السبت ١٧ أكتوبر · ١١ ص'), findsOneWidget);
      expect(find.text(CC.s6Fee), findsOneWidget);
      expect(find.textContaining('الأسعار بالجنيه'), findsNothing);
      expect(find.text('٠ ج.م'), findsNothing);
    });

    testWidgets('fee explainer is inline on the fee row with its own state', (t) async {
      _phone(t);
      await t.pumpWidget(host(const PlanBillScreen(id: 's1'), api: api0()));
      await _settle(t);
      expect(find.text(CC.feeTipTitle), findsNothing);
      await t.ensureVisible(find.byType(FeeTipButton));
      await t.tap(find.byType(FeeTipButton));
      await t.pump();
      expect(find.text(CC.feeTipTitle), findsOneWidget);
      expect(find.text(CC.feeClosing), findsOneWidget);
    });

    testWidgets('receipt button fetches the receipt and opens its url', (t) async {
      _phone(t);
      final opened = <String>[];
      final api = api0();
      await t.pumpWidget(host(const PlanBillScreen(id: 's1'), api: api, extra: [externalOpenerProvider.overrideWithValue((u) async => opened.add(u))]));
      await _settle(t);
      await t.tap(find.text(CC.s6Receipt));
      await _settle(t);
      expect(opened, ['https://example.test/r.pdf']);
    });

    testWidgets('receipt failure shows an Arabic message', (t) async {
      _phone(t);
      await t.pumpWidget(host(const PlanBillScreen(id: 's1'), api: api0(receipt: {'price': 1})));
      await _settle(t);
      await t.tap(find.text(CC.s6Receipt));
      await _settle(t);
      expect(find.text(CC.s6ReceiptFailed), findsOneWidget);
    });

    testWidgets('skeleton while loading and error with retry (not ٠ ج.م)', (t) async {
      _phone(t);
      final api = FakeSubApi({'GET /subscriptions/s1': ApiException(500, 'مشكلة مؤقتة')});
      await t.pumpWidget(host(const PlanBillScreen(id: 's1'), api: api));
      expect(find.byKey(const ValueKey('bill-skeleton')), findsOneWidget);
      await _settle(t);
      expect(find.text('مشكلة مؤقتة'), findsOneWidget);
      expect(find.text('٠ ج.م'), findsNothing);
    });
  });
}
