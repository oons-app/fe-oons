import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/system/progress.dart';

Widget _app(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('OnsBusyPage names what is loading instead of a bare spinner', (t) async {
    await t.pumpWidget(const MaterialApp(home: OnsBusyPage(caption: 'نحمل ملخص حجزكِ…')));
    expect(find.text('نحمل ملخص حجزكِ…'), findsOneWidget);
    expect(find.byType(InlineSpinner), findsOneWidget);
  });

  test('duration policy picks the documented treatment', () {
    expect(progressTreatmentFor(const Duration(milliseconds: 400)), ProgressTreatment.none);
    expect(progressTreatmentFor(const Duration(seconds: 2)), ProgressTreatment.inlineSpinner);
    expect(progressTreatmentFor(const Duration(seconds: 8)), ProgressTreatment.skeletonOrBar);
    expect(progressTreatmentFor(const Duration(hours: 5)), ProgressTreatment.journey);
  });

  testWidgets('skeleton keeps the real heading, matches row count, and says what is loading', (t) async {
    await t.pumpWidget(_app(const ServiceListSkeleton(heading: 'تنظيف البيت', caption: 'نحمّل الخدمات المتاحة في المعادي…', rows: 4)));
    expect(find.text('تنظيف البيت'), findsOneWidget);
    expect(find.text('نحمّل الخدمات المتاحة في المعادي…'), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsNWidgets(4 * 4));
  });

  testWidgets('BusyButton states what is happening and locks siblings; double tap runs once', (t) async {
    var runs = 0;
    var sibling = 0;
    final gate = Completer<void>();
    await t.pumpWidget(_app(BusyGroup(
      child: Column(children: [
        BusyButton(
          label: 'كمّلي للميعاد',
          busyLabel: 'نؤكّد الميعاد…',
          onPressed: () async {
            runs++;
            await gate.future;
          },
        ),
        BusyLock(child: TextButton(onPressed: () => sibling++, child: const Text('ارجعي'))),
      ]),
    )));
    expect(find.text('كمّلي للميعاد'), findsOneWidget);
    await t.tap(find.text('كمّلي للميعاد'));
    await t.pump();
    expect(find.text('نؤكّد الميعاد…'), findsOneWidget);
    expect(find.text('كمّلي للميعاد'), findsNothing);
    await t.tap(find.text('نؤكّد الميعاد…'), warnIfMissed: false);
    await t.tap(find.text('ارجعي'), warnIfMissed: false);
    await t.pump();
    expect(runs, 1, reason: 'double submit must be impossible');
    expect(sibling, 0, reason: 'siblings lock while busy');
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('كمّلي للميعاد'), findsOneWidget);
    await t.tap(find.text('ارجعي'));
    expect(sibling, 1);
  });

  testWidgets('HoldCountdown reads the injected server deadline and fires onExpired once', (t) async {
    var clock = DateTime.utc(2026, 9, 18, 12, 0, 0);
    final deadline = clock.add(const Duration(minutes: 14, seconds: 22));
    var expired = 0;
    await t.pumpWidget(_app(HoldCountdown(deadline: deadline, label: 'الحجز محفوظ', now: () => clock, onExpired: () => expired++)));
    expect(find.text('١٤:٢٢'), findsOneWidget);
    clock = deadline.subtract(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('٠٠:٠١'), findsOneWidget);
    expect(expired, 0);
    clock = deadline.add(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('٠٠:٠٠'), findsOneWidget);
    expect(expired, 1);
  });

  testWidgets('determinate bar shows a number; indeterminate bar never does', (t) async {
    await t.pumpWidget(_app(const DeterminateBar(value: 0.5, numberLabel: '٣ / ٦')));
    expect(find.text('٣ / ٦'), findsOneWidget);
    await t.pumpWidget(_app(const IndeterminateBar()));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('journey: past olive, current plum, future hairline', (t) async {
    await t.pumpWidget(_app(const JourneyStages(stages: ['اتحجز', 'اتدفع', 'في الطريق', 'وصلت', 'خلصت'], current: 2)));
    final bars = t.widgetList<Container>(find.byType(Container)).where((c) => c.constraints?.maxHeight == 4).toList();
    final colors = bars.map((c) => c.color).toList();
    expect(colors, const [Color(0xFF6B7355), Color(0xFF6B7355), Color(0xFF3E2136), Color(0xFFDCD4CC), Color(0xFFDCD4CC)]);
  });

  test('optimistic add rolls back WITH a reason when the server rejects', () async {
    var list = <String>[];
    Object? reason;
    final ok = await runOptimistic(
      apply: () => list = [...list, 'تنظيف عميق'],
      rollback: () => list = [],
      request: () async => throw StateError('الموعد لم يعد متاحًا'),
      onRejected: (r) => reason = r,
    );
    expect(ok, isFalse);
    expect(list, isEmpty);
    expect(reason.toString(), contains('الموعد لم يعد متاحًا'));

    final ok2 = await runOptimistic(apply: () => list = ['x'], rollback: () => list = [], request: () async {}, onRejected: (_) => fail('no'));
    expect(ok2, isTrue);
    expect(list, ['x']);
  });
}
