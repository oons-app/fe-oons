import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/plan_card.dart';
import 'package:oons/features/subscribe/plan_models.dart';
import 'package:oons/features/subscribe/subscription_screens.dart';

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

void main() {
  group('PlanCard', () {
    testWidgets('struck pay-per-visit, prominent sub price, save block, recommended line', (t) async {
      _phone(t);
      final plan = PlanData.fromRow(planRow('a', recommended: true));
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PlanCard(plan: plan, selected: true, onTap: () {})))));
      expect(find.text('١ تنظيف مميز + ٣ عادي في الشهر'), findsOneWidget);
      expect(find.text('١ × تنظيف مميز'), findsOneWidget);
      expect(find.text('٣ × تنظيف عادي'), findsOneWidget);
      final payg = t.widget<Text>(find.byKey(const ValueKey('plan-payg')));
      expect(payg.data, '٣,٣٤٥');
      expect(payg.style!.decoration, TextDecoration.lineThrough);
      expect(find.byKey(const ValueKey('plan-sub')), findsOneWidget);
      expect(find.text('وفّري ٤٤٥'), findsOneWidget);
      expect(find.text(CC.recommended), findsOneWidget);
      expect(find.text(CC.startPlan), findsOneWidget);
    });

    testWidgets('drops the cleaning-products line and keeps the rest', (t) async {
      _phone(t);
      final row = planRow('a');
      row['includedBenefits'] = ['شاملة المنظفات: ديتول، كلور', 'نفس المتخصصة'];
      final plan = PlanData.fromRow(row);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PlanCard(plan: plan, selected: false, onTap: () {})))));
      expect(find.textContaining('منظف'), findsNothing);
      expect(find.text('نفس المتخصصة'), findsOneWidget);
    });

    testWidgets('save block hidden when saving <= 0 and no recommended line', (t) async {
      _phone(t);
      final plan = PlanData.fromRow(planRow('b', payg: 50000, price: 55000, save: -5000));
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PlanCard(plan: plan, selected: false, onTap: () {})))));
      expect(find.byKey(const ValueKey('plan-save')), findsNothing);
      expect(find.text(CC.recommended), findsNothing);
    });
  });

  group('fee explainer', () {
    testWidgets('own open state, Semantics expanded, 44px target, keyboard focusable', (t) async {
      _phone(t);
      var open = false;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (c, set) => Column(children: [FeeTipButton(open: open, onTap: () => set(() => open = !open)), if (open) const FeeTipPanel(long: true)])),
        ),
      ));
      final sem = t.getSemantics(find.byType(FeeTipButton));
      expect(sem.label, CC.feeTipLabel);
      expect(sem.flagsCollection.isExpanded, ui.Tristate.isFalse);
      expect(t.getSize(find.byType(InkWell)).width, greaterThanOrEqualTo(44));
      expect(t.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(44));
      expect(find.text(CC.feeTipTitle), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(open, isTrue);
      expect(find.text(CC.feeTipTitle), findsOneWidget);
      expect(find.text(CC.feeClosing), findsOneWidget);
      expect(find.text(CC.feeReasons.first), findsOneWidget);
      expect(t.getSemantics(find.byType(FeeTipButton)).flagsCollection.isExpanded, ui.Tristate.isTrue);
    });

    testWidgets('short panel has the paragraph once', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: FeeTipPanel())));
      expect(find.text(CC.feeShort), findsOneWidget);
      expect(find.text(CC.feeClosing), findsNothing);
    });
  });

  group('S2 plans screen', () {
    FakeSubApi api0() => FakeSubApi({
          'GET /providers/p1/plans': {'enabled': true, 'plans': [planRow('a'), planRow('b', recommended: true, price: 320000, save: 14500)]},
          'GET /providers/p1': {'id': 'p1', 'name': {'en': 'Nada', 'ar': 'ندى'}},
        });

    testWidgets('cards, footer explainer and footnote; flag-on', (t) async {
      _phone(t);
      await t.pumpWidget(host(const CleaningPlansScreen(providerId: 'p1', providerName: 'ندى'), api: api0()));
      await _settle(t);
      expect(find.text(CC.s2Title), findsOneWidget);
      expect(find.text('من ندى'), findsOneWidget);
      expect(find.byType(PlanCard), findsNWidgets(2));
      expect(find.text(CC.recommended), findsOneWidget);
      expect(find.text(CC.s2Footnote), findsOneWidget);
      expect(find.text(CC.feeShort), findsNothing);
      await t.tap(find.byType(FeeTipButton));
      await t.pump();
      expect(find.text(CC.feeShort), findsOneWidget);
      expect(find.text(CC.feeClosing), findsNothing);
    });

    testWidgets('CTA opens S3 with ids in the URL (not extra-only)', (t) async {
      _phone(t);
      await t.pumpWidget(host(const CleaningPlansScreen(providerId: 'p1', providerName: 'ندى'), api: api0()));
      await _settle(t);
      await t.tap(find.text(CC.startPlan).first);
      await _settle(t);
      expect(find.textContaining('providerId=p1&planId=a'), findsOneWidget);
    });

    testWidgets('error state shows the Arabic message and retries', (t) async {
      _phone(t);
      final api = FakeSubApi({'GET /providers/p1/plans': ApiException(500, 'السيرفر مشغول')});
      await t.pumpWidget(host(const CleaningPlansScreen(providerId: 'p1'), api: api));
      await _settle(t);
      expect(find.text(CC.s2LoadFailedTitle), findsOneWidget);
      expect(find.text('السيرفر مشغول'), findsOneWidget);
      api.routes['GET /providers/p1/plans'] = {'enabled': true, 'plans': [planRow('a')]};
      await t.tap(find.text(CC.s2Retry));
      await _settle(t);
      expect(find.byType(PlanCard), findsOneWidget);
    });

    testWidgets('disabled flag / no plans shows the empty state', (t) async {
      _phone(t);
      await t.pumpWidget(host(const CleaningPlansScreen(providerId: 'p1'), api: api0(), pilot: false));
      await _settle(t);
      expect(find.byType(PlanCard), findsNothing);
      expect(find.text(CC.s2EmptyTitle), findsOneWidget);
    });

    testWidgets('skeleton while loading', (t) async {
      _phone(t);
      await t.pumpWidget(host(const CleaningPlansScreen(providerId: 'p1'), api: api0()));
      expect(find.byKey(const ValueKey('plans-skeleton')), findsOneWidget);
      await _settle(t);
    });
  });

  group('S3 included', () {
    Map<String, dynamic> provider() => {
          'id': 'p1',
          'name': {'en': 'Nada', 'ar': 'ندى'},
          'items': [
            {'id': 'cd', 'name': {'ar': 'تنظيف مميز'}, 'kind': 'cleaning', 'duration': 360, 'price': 120000, 'excludedTaskIds': <String>[], 'benefits': [{'ar': 'بنغسل الفرن من جوّه'}]},
            {'id': 'cr', 'name': {'ar': 'تنظيف عادي'}, 'kind': 'cleaning', 'duration': 300, 'price': 71500, 'excludedTaskIds': ['cleaning.kitchen.oven_microwave'], 'benefits': <Map>[]},
          ],
        };

    testWidgets('both types: deep open by default, regular closed, table shown', (t) async {
      _phone(t);
      final api = FakeSubApi({'GET /providers/p1/plans': {'enabled': true, 'plans': [planRow('a')]}, 'GET /providers/p1': provider()});
      await t.pumpWidget(host(const PlanIncludedScreen(providerId: 'p1', planId: 'a'), api: api));
      await _settle(t);
      expect(find.text(CC.s3DeepHeading), findsOneWidget);
      expect(find.text('بنغسل الفرن من جوّه'), findsOneWidget);
      expect(find.text(CC.s3RegularBody), findsNothing);
      expect(find.text(CC.s3Diff), findsOneWidget);
      expect(find.text('تلميع الفرن والميكروويف من بره'), findsOneWidget);
      expect(find.text(CC.s3Cta), findsOneWidget);
      final deepHead = t.getSemantics(find.byKey(const ValueKey('acc-deep')).first);
      expect(deepHead, isNotNull);
      await t.tap(find.text(CC.s3RegularHeading));
      await t.pump();
      expect(find.text(CC.s3RegularBody), findsOneWidget);
    });

    testWidgets('only the visit types present in the plan', (t) async {
      _phone(t);
      final regularOnly = planRow('r', lines: [
        {'visitType': 'regular', 'quantity': 4, 'catalogItemId': 'cr', 'name': {'ar': 'تنظيف عادي'}},
      ]);
      final api = FakeSubApi({'GET /providers/p1/plans': {'enabled': true, 'plans': [regularOnly]}, 'GET /providers/p1': provider()});
      await t.pumpWidget(host(const PlanIncludedScreen(providerId: 'p1', planId: 'r'), api: api));
      await _settle(t);
      expect(find.byKey(const ValueKey('acc-deep')), findsNothing);
      expect(find.byKey(const ValueKey('acc-regular')), findsOneWidget);
      expect(find.text(CC.s3Diff), findsNothing);
    });

    testWidgets('CTA goes to the schedule route by ids', (t) async {
      _phone(t);
      final api = FakeSubApi({'GET /providers/p1/plans': {'enabled': true, 'plans': [planRow('a')]}, 'GET /providers/p1': provider()});
      await t.pumpWidget(host(const PlanIncludedScreen(providerId: 'p1', planId: 'a'), api: api));
      await _settle(t);
      await t.tap(find.text(CC.s3Cta));
      await _settle(t);
      expect(find.textContaining('/plans/a/schedule?providerId=p1'), findsOneWidget);
    });
  });
}
