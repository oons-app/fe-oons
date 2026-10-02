import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/visit_ops.dart';

import 'subscription_provider_fakes.dart';

final _checklist = [
  {'id': 't1', 'room': 'المطبخ', 'label': 'تنضيف الرخامة'},
  {'id': 't2', 'room': 'المطبخ', 'label': 'تنضيف الحوض'},
  {'id': 't3', 'room': 'الحمامات', 'label': 'تعقيم الحمام'},
];

FakeApi visitApi() {
  final a = FakeApi();
  a.routes['POST /pro/visits/v1/check-in'] = (_) => {'fullAddress': '١٢ شارع الجزيرة، شقة ٤', 'area': 'الزمالك', 'checklist': _checklist};
  a.routes['POST /pro/visits/v1/complete'] = (_) => {'ok': true, 'addressPurged': true};
  return a;
}

final _now = DateTime(2026, 10, 2, 10, 0);

Future<void> pumpVisit(
  WidgetTester t,
  FakeApi api, {
  LocationFetcher? locate,
  String date = '2026-10-02',
  Future<void> Function(String)? openSettings,
  List<bool>? popped,
}) async {
  phoneViewport(t);
  t.view.physicalSize = const Size(390, 1600);
  await t.pumpWidget(Container());
  await t.pumpWidget(arabicHost(Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => VisitCheckInScreen(
                visitId: 'v1',
                area: 'الزمالك',
                visitType: 'deep',
                date: date,
                time: '10:00',
                firstName: 'منى',
                api: api,
                now: () => _now,
                locate: locate ?? () async => (lat: 30.0626, lng: 31.2197),
                openSettings: openSettings ?? (_) async {},
              ),
            ));
            popped?.add(r == true);
          },
          child: const Text('افتحي'),
        ),
      ),
    ),
  )));
  await t.tap(find.text('افتحي'));
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
  group('check-in', () {
    testWidgets('locked -> revealed -> complete, with the real position and an address purge', (t) async {
      final api = visitApi();
      final popped = <bool>[];
      await pumpVisit(t, api, popped: popped, locate: () async => (lat: 30.0626, lng: 31.2197));
      // locked: only the area
      expect(find.text('الزمالك'), findsOneWidget);
      expect(find.byKey(const Key('address-locked')), findsOneWidget);
      expect(find.byKey(const Key('address-revealed')), findsNothing);
      expect(find.text('ابدئي الزيارة'), findsOneWidget);
      expect(find.byKey(const Key('checklist-locked')), findsOneWidget);
      expect(find.text('تنضيف الرخامة'), findsNothing);
      expect(find.text('تنظيف مميز'), findsOneWidget);
      // reveal
      await tapK(t, 'start-visit');
      final call = api.where('POST', '/pro/visits/v1/check-in').single;
      expect(call.body['lat'], 30.0626);
      expect(call.body['lng'], 31.2197);
      expect(call.body['lat'], isNot(30.0444), reason: 'no hard-coded Cairo coordinates');
      expect(find.text('١٢ شارع الجزيرة، شقة ٤'), findsOneWidget);
      expect(find.byKey(const Key('address-locked')), findsNothing);
      expect(find.byKey(const Key('start-visit')), findsNothing);
      // grouped by room
      expect(find.text('المطبخ'), findsOneWidget);
      expect(find.text('الحمامات'), findsOneWidget);
      expect(find.text('٠ / ٣'), findsOneWidget);
      // finish is disabled until everything is ticked
      await tapK(t, 'finish-visit');
      expect(api.where('POST', '/pro/visits/v1/complete'), isEmpty);
      await tapK(t, 'task-t1');
      await tapK(t, 'task-t2');
      await tapK(t, 'finish-visit');
      expect(api.where('POST', '/pro/visits/v1/complete'), isEmpty);
      expect(find.text('٢ / ٣'), findsOneWidget);
      await tapK(t, 'task-t3');
      expect(find.text('٣ / ٣'), findsOneWidget);
      await tapK(t, 'finish-visit');
      final done = api.where('POST', '/pro/visits/v1/complete').single;
      expect((done.body['checkedItems'] as List).toSet(), {'t1', 't2', 't3'});
      // purge: screen closed, snackbar confirms, address is gone from the tree
      expect(popped, [true]);
      expect(find.byType(VisitCheckInScreen), findsNothing);
      expect(find.text('اتسجّلت الزيارة. العنوان اتمسح من جهازك.'), findsOneWidget);
      expect(find.text('١٢ شارع الجزيرة، شقة ٤'), findsNothing);
    });

    testWidgets('permission denied / services off: Arabic message, settings shortcut, retry clears it', (t) async {
      var mode = 'location_denied';
      String? opened;
      final api = visitApi();
      await pumpVisit(
        t,
        api,
        locate: () async {
          if (mode.isNotEmpty) throw GeoException(mode);
          return (lat: 30.0, lng: 31.0);
        },
        openSettings: (p) async => opened = p,
      );
      await tapK(t, 'start-visit');
      expect(find.text('محتاجين إذن الموقع عشان نتأكد إنك عند البيت.'), findsOneWidget);
      expect(api.where('POST', '/pro/visits/v1/check-in'), isEmpty);
      await tapK(t, 'open-settings');
      expect(opened, 'location_denied');
      mode = 'location_off';
      await tapK(t, 'start-visit');
      expect(find.text('شغّلي خدمات الموقع من إعدادات الجهاز عشان نتأكد إنك عند البيت.'), findsOneWidget);
      await tapK(t, 'open-settings');
      expect(opened, 'location_off');
      mode = '';
      await tapK(t, 'start-visit');
      expect(find.byKey(const Key('checkin-error')), findsNothing, reason: 'error cleared on retry');
      expect(find.text('١٢ شارع الجزيرة، شقة ٤'), findsOneWidget);
    });

    testWidgets('timeout and unknown location errors are readable', (t) async {
      var n = 0;
      await pumpVisit(t, visitApi(), locate: () async {
        n++;
        if (n == 1) throw TimeoutException('slow');
        throw StateError('x');
      });
      await tapK(t, 'start-visit');
      expect(find.textContaining('موقعك اتأخر في الظهور'), findsOneWidget);
      await tapK(t, 'start-visit');
      expect(find.text('ما قدرناش نحدد موقعك. جرّبي تاني.'), findsOneWidget);
      expect(find.byKey(const Key('open-settings')), findsNothing);
    });

    testWidgets('the server 409 (too far / outside the window) shows inline and the address stays locked', (t) async {
      final api = visitApi();
      api.routes['POST /pro/visits/v1/check-in'] = (_) => ApiException(409, 'العنوان بيظهر لما تكوني عند البيت في ميعاد الزيارة.');
      await pumpVisit(t, api);
      await tapK(t, 'start-visit');
      expect(find.text('العنوان بيظهر لما تكوني عند البيت في ميعاد الزيارة.'), findsOneWidget);
      expect(find.byKey(const Key('address-locked')), findsOneWidget);
      expect(find.byKey(const Key('start-visit')), findsOneWidget);
      // a later success replaces the error
      api.routes['POST /pro/visits/v1/check-in'] = (_) => {'fullAddress': 'عنوان', 'checklist': _checklist};
      await tapK(t, 'start-visit');
      expect(find.byKey(const Key('checkin-error')), findsNothing);
      expect(find.text('عنوان'), findsOneWidget);
    });

    testWidgets('complete failure keeps the checklist and shows the message', (t) async {
      final api = visitApi();
      api.routes['POST /pro/visits/v1/complete'] = (_) => ApiException(409, 'كمّلي كل خطوات الزيارة.');
      await pumpVisit(t, api);
      await tapK(t, 'start-visit');
      for (final id in ['t1', 't2', 't3']) {
        await tapK(t, 'task-$id');
      }
      await tapK(t, 'finish-visit');
      expect(find.text('كمّلي كل خطوات الزيارة.'), findsOneWidget);
      expect(find.text('١٢ شارع الجزيرة، شقة ٤'), findsOneWidget);
    });

    testWidgets('a future visit cannot be started: locked with its date, no location request', (t) async {
      var asked = 0;
      final api = visitApi();
      await pumpVisit(t, api, date: '2026-10-05', locate: () async {
        asked++;
        return (lat: 1.0, lng: 1.0);
      });
      expect(find.byKey(const Key('not-today')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('not-today'))).data, contains('الاثنين، ٥ أكتوبر ٢٠٢٦'));
      expect(find.byKey(const Key('address-locked')), findsOneWidget);
      await t.tap(find.byKey(const Key('start-visit')), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(asked, 0);
      expect(api.where('POST', '/pro/visits/v1/check-in'), isEmpty);
    });
  });

  group('this week', () {
    Map<String, dynamic> week() => {
          'from': '2026-10-02',
          'capacityPerDay': 3,
          'days': [
            for (var i = 0; i < 7; i++) {'date': '2026-10-${(2 + i).toString().padLeft(2, '0')}', 'weekday': (6 + i) % 7, 'count': i == 0 ? 2 : i == 1 ? 1 : 0}
          ],
          'visits': [
            {'id': 'v1', 'date': '2026-10-02', 'time': '10:00', 'firstName': 'منى', 'area': 'الزمالك', 'type': 'deep', 'status': 'confirmed'},
            {'id': 'v2', 'date': '2026-10-02', 'time': '13:00', 'firstName': 'سلمى', 'area': 'المعادي', 'type': 'regular', 'status': 'pending'},
            {'id': 'v3', 'date': '2026-10-03', 'time': '09:00', 'firstName': 'ريم', 'area': 'مدينة نصر', 'type': 'regular', 'status': 'confirmed'},
          ],
        };

    Future<FakeApi> pumpWeek(WidgetTester t) async {
      final api = FakeApi();
      api.routes['GET /pro/schedule/week'] = (_) => week();
      phoneViewport(t);
      t.view.physicalSize = const Size(390, 1600);
      await t.pumpWidget(Container());
      await t.pumpWidget(arabicHost(VisitWeekScreen(api: api, now: () => _now)));
      await t.pumpAndSettle();
      return api;
    }

    testWidgets('capacity line uses the selected day, strip shows dates and counts, cards per type/status', (t) async {
      await pumpWeek(t);
      // today (Friday 2 Oct) is selected: 2 of 3, not the week total
      expect(t.widget<Text>(find.byKey(const Key('capacity-line'))).data, '٢ من ٣ مواعيد محجوزة يوم الجمعة');
      expect(find.text('جمعة'), findsOneWidget);
      expect(find.text('سبت'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('count-2026-10-02'))).data, '٢');
      expect(t.widget<Text>(find.byKey(const Key('count-2026-10-03'))).data, '١');
      expect(find.text('١٠:٠٠ · منى'), findsOneWidget);
      expect(find.text('تنظيف مميز'), findsOneWidget);
      expect(find.text('صيانة · تنظيف عادي'), findsOneWidget);
      expect(find.text('متأكدة'), findsOneWidget);
      expect(find.text('مستنية تأكيد'), findsOneWidget);
      expect(find.textContaining('الزمالك · العنوان بيظهر عند الوصول'), findsOneWidget);
      expect(find.textContaining('ريم'), findsNothing, reason: 'other day not listed');
      await tapK(t, 'day-2026-10-03');
      expect(t.widget<Text>(find.byKey(const Key('capacity-line'))).data, '١ من ٣ مواعيد محجوزة يوم السبت');
      expect(find.textContaining('ريم'), findsOneWidget);
      await tapK(t, 'day-2026-10-05');
      expect(find.byKey(const Key('no-visits')), findsOneWidget);
    });

    testWidgets("today's visit card is reachable from the week screen", (t) async {
      final api = await pumpWeek(t);
      expect(find.text('زيارة النهارده'), findsOneWidget);
      expect(find.text('وبعدها زيارة واحدة كمان.'), findsOneWidget);
      api.routes['POST /pro/visits/v1/check-in'] = (_) => {'fullAddress': 'عنوان', 'checklist': <Map<String, dynamic>>[]};
      await tapK(t, 'open-today');
      expect(find.byType(VisitCheckInScreen), findsOneWidget);
      expect(find.byKey(const Key('start-visit')), findsOneWidget);
    });

    testWidgets('error state is Arabic and retry works', (t) async {
      final api = FakeApi();
      api.routes['GET /pro/schedule/week'] = (_) => ApiException(500, 'boom');
      phoneViewport(t);
      await t.pumpWidget(Container());
      await t.pumpWidget(arabicHost(VisitWeekScreen(api: api, now: () => _now)));
      await t.pumpAndSettle();
      expect(find.text('ما قدرناش نجيب جدول الأسبوع. جرّبي تاني.'), findsOneWidget);
      api.routes['GET /pro/schedule/week'] = (_) => week();
      await t.tap(find.text('جرّبي تاني'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('capacity-line')), findsOneWidget);
    });
  });

  group('subscribers roster', () {
    Map<String, dynamic> roster(String status) => {
          'summary': {'active': 5, 'visitsThisWeek': 9},
          'rows': [
            if (status != 'paused') {'id': 's1', 'firstName': 'منى', 'planTitle': 'نضافة شاملة', 'used': 1, 'minimum': 4, 'status': 'active', 'provisional': true},
            if (status == '' || status == 'at_risk') {'id': 's2', 'firstName': 'سلمى', 'planTitle': 'الأساسيات', 'used': 0, 'minimum': 4, 'status': 'at_risk', 'provisional': true},
            if (status == '' || status == 'paused') {'id': 's3', 'firstName': 'ريم', 'planTitle': 'الأساسيات', 'used': 2, 'minimum': 4, 'status': 'paused'},
          ],
        };

    testWidgets('summary, rows, chips, filters call the API', (t) async {
      final api = FakeApi();
      api.routes['GET /pro/subscribers'] = (c) => roster('${c.query?['status'] ?? ''}'.replaceAll('all', ''));
      phoneViewport(t);
      await t.pumpWidget(Container());
      await t.pumpWidget(arabicHost(ProSubscribersScreen(api: api)));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(const Key('roster-summary'))).data, '٥ مشتركة نشطة · ٩ زيارة الأسبوع ده');
      expect(find.text('منى'), findsOneWidget);
      expect(find.text('نضافة شاملة'), findsOneWidget);
      expect(find.textContaining('١ / ٤'), findsOneWidget);
      expect(find.text('نشطة'), findsWidgets);
      expect(find.text('معرّضة للإلغاء'), findsWidgets);
      expect(find.textContaining('قاعدة مؤقتة'), findsNothing);
      for (final k in ['filter-all', 'filter-active', 'filter-paused', 'filter-at_risk']) {
        expect(find.byKey(Key(k)), findsOneWidget);
        expect(t.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(44));
      }
      await tapK(t, 'filter-paused');
      expect(api.calls.last.query, {'status': 'paused'});
      expect(find.text('ريم'), findsOneWidget);
      expect(find.text('منى'), findsNothing);
      await tapK(t, 'filter-at_risk');
      expect(api.calls.last.query, {'status': 'at_risk'});
      expect(find.text('سلمى'), findsOneWidget);
      await tapK(t, 'filter-all');
      expect(api.calls.last.query, {'status': 'all'});
    });

    testWidgets('empty and error states', (t) async {
      final api = FakeApi();
      api.routes['GET /pro/subscribers'] = (_) => {'summary': {'active': 0, 'visitsThisWeek': 0}, 'rows': []};
      phoneViewport(t);
      await t.pumpWidget(Container());
      await t.pumpWidget(arabicHost(ProSubscribersScreen(api: api)));
      await t.pumpAndSettle();
      expect(find.text('لسه مفيش مشتركات'), findsOneWidget);
      await tapK(t, 'filter-paused');
      expect(find.text('مفيش مشتركات في الفلتر ده'), findsOneWidget);
      api.routes['GET /pro/subscribers'] = (_) => ApiException(500, 'x');
      await tapK(t, 'filter-all');
      expect(find.text('ما قدرناش نجيب المشتركات. جرّبي تاني.'), findsOneWidget);
    });
  });
}
