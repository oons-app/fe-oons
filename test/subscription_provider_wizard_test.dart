import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/plan_wizard.dart';

import 'subscription_provider_fakes.dart';

FakeApi baseApi({List<Map<String, dynamic>> workers = const [], List<Map<String, dynamic>> plans = const []}) {
  final api = FakeApi();
  api.routes['GET /pro/workers'] = (_) => {'workers': workers};
  api.routes['GET /pro/plans'] = (_) => {'plans': plans, 'enabled': true};
  api.routes['POST /pro/plans'] = (c) {
    final b = c.body;
    return {
      'plan': {...b, 'id': b['id'] ?? 'p1'},
      'quote': <String, dynamic>{},
    };
  };
  api.routes['POST /pro/plans/p1/publish'] = (_) => {'plan': {'id': 'p1', 'status': 'published'}};
  return api;
}

DateTime Function() fixedNow() => () => DateTime(2026, 10, 2, 9, 41);

Future<void> pumpFlow(WidgetTester t, FakeApi api, {Map? existing, WizDatePicker? pick, String providerId = 'prov1', VoidCallback? onProfile}) async {
  phoneViewport(t);
  await t.pumpWidget(Container()); // always start from a fresh State
  await t.pumpWidget(arabicHost(PlanWizardFlow(
    services: testServices(),
    api: api,
    existing: existing,
    providerId: providerId,
    now: fixedNow(),
    saveDelay: const Duration(milliseconds: 50),
    onViewProfile: onProfile,
    pickDate: pick ?? pickWizDate,
  )));
  await t.pumpAndSettle();
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: 'missing $key');
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> next(WidgetTester t) => tapKey(t, 'wizard-cta');

TextField fieldOf(WidgetTester t, String key) => t.widget<TextField>(find.byKey(Key(key)));

WizDatePicker pickerReturning(Map<String, DateTime> byHelp) =>
    (context, {required initial, required first, required last, help}) async => byHelp[help];

/// Steps 1-3 filled in: 4 regular visits on Tuesdays.
Future<void> fillToStep4(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await tapKey(t, 'qty-inc-item-r');
  }
  await next(t); // -> 2
  await next(t); // -> 3
  await tapKey(t, 'day-3');
  await next(t); // -> 4
}

void main() {
  group('step 1 · persistent controllers', () {
    testWidgets('name field keeps its controller, text and caret across rebuilds', (t) async {
      await pumpFlow(t, baseApi());
      final c0 = fieldOf(t, 'name-field').controller!;
      await t.enterText(find.byKey(const Key('name-field')), 'الأساسيات');
      await t.pump();
      expect(fieldOf(t, 'name-field').controller, same(c0));
      c0.selection = const TextSelection.collapsed(offset: 3);
      // force several rebuilds from other widgets
      await tapKey(t, 'qty-inc-item-r');
      await tapKey(t, 'qty-inc-item-r');
      final c1 = fieldOf(t, 'name-field').controller!;
      expect(c1, same(c0));
      expect(c1.text, 'الأساسيات');
      expect(c1.selection.baseOffset, 3, reason: 'the caret must not jump to the end');
      // typing in the middle inserts there
      t.testTextInput.updateEditingValue(const TextEditingValue(text: 'الأسXاسيات', selection: TextSelection.collapsed(offset: 4)));
      await t.pump();
      expect(fieldOf(t, 'name-field').controller!.text, 'الأسXاسيات');
      expect(fieldOf(t, 'name-field').controller!.selection.baseOffset, 4);
    });

    testWidgets('mix line, stepper limits and the max-visits note', (t) async {
      await pumpFlow(t, baseApi());
      expect(find.text('اختاري خدمة واحدة على الأقل'), findsOneWidget);
      await tapKey(t, 'qty-inc-item-r');
      await tapKey(t, 'qty-inc-item-r');
      await tapKey(t, 'qty-inc-item-d');
      expect(find.text('٢ تنظيف عادي + ١ تنظيف مميز = ٣ زيارات في الشهر'), findsOneWidget);
      // dec at zero does nothing
      await tapKey(t, 'qty-dec-item-x');
      expect(find.byKey(const Key('qty-item-x')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('qty-item-x'))).data, '٠');
      for (var i = 0; i < 12; i++) {
        await tapKey(t, 'qty-inc-item-r');
      }
      expect(t.widget<Text>(find.byKey(const Key('qty-item-r'))).data, '١١'); // capped at 12 visits in total (1 deep already)
      expect(find.byKey(const Key('max-visits')), findsOneWidget);
    });
  });

  group('step 2 · price table', () {
    testWidgets('typing keeps the caret; clearing and 0 read as empty (red note, CTA off)', (t) async {
      await pumpFlow(t, baseApi());
      await tapKey(t, 'qty-inc-item-r');
      await tapKey(t, 'qty-inc-item-r');
      await next(t);
      final ctl = fieldOf(t, 'sub-item-r').controller!;
      expect(ctl.text, '٤٥٠'); // 10% suggestion
      await t.enterText(find.byKey(const Key('sub-item-r')), '460');
      await t.pump();
      expect(fieldOf(t, 'sub-item-r').controller, same(ctl));
      expect(ctl.text, '٤٦٠');
      expect(find.text('٢ في الشهر · أقل ٨٪'), findsOneWidget);
      // caret survives an edit in the middle
      t.testTextInput.updateEditingValue(const TextEditingValue(text: '٤٧٦٠', selection: TextSelection.collapsed(offset: 2)));
      await t.pump();
      expect(ctl.text, '٤٧٦٠');
      expect(ctl.selection.baseOffset, 2);
      // Latin digits typed are shown as Arabic-Indic, extra characters dropped
      await t.enterText(find.byKey(const Key('sub-item-r')), '4x5');
      await t.pump();
      expect(ctl.text, '٤٥');
      // clear
      await t.enterText(find.byKey(const Key('sub-item-r')), '');
      await t.pump();
      expect(find.text('٢ في الشهر · اكتبي السعر'), findsOneWidget);
      expect(find.text('اكتبي سعر الاشتراك'), findsOneWidget);
      expect(t.widget<Semantics>(find.descendant(of: find.byKey(const Key('wizard-cta')), matching: find.byType(Semantics)).first).properties.enabled, isFalse);
      // typing 0 behaves like empty
      await t.enterText(find.byKey(const Key('sub-item-r')), '0');
      await t.pump();
      expect(ctl.text, '٠');
      expect(find.text('٢ في الشهر · اكتبي السعر'), findsOneWidget);
      expect(find.text('اكتبي سعر الاشتراك'), findsOneWidget);
      // length is capped at five digits
      await t.enterText(find.byKey(const Key('sub-item-r')), '1234567');
      await t.pump();
      expect(ctl.text, '١٢٣٤٥');
    });

    testWidgets('quick chips rewrite every row and show the selected state', (t) async {
      await pumpFlow(t, baseApi());
      await tapKey(t, 'qty-inc-item-r');
      await tapKey(t, 'qty-inc-item-d');
      await next(t);
      bool selected(String key) => t.getSemantics(find.byKey(Key(key))).getSemanticsData().flagsCollection.isSelected == Tristate.isTrue;
      // default = 10% suggestion
      expect(selected('chip-10'), isTrue);
      expect(selected('chip-5'), isFalse);
      expect(fieldOf(t, 'sub-item-r').controller!.text, '٤٥٠');
      await tapKey(t, 'chip-5');
      expect(selected('chip-5'), isTrue);
      expect(selected('chip-10'), isFalse);
      expect(fieldOf(t, 'sub-item-r').controller!.text, '٤٨٠');
      expect(fieldOf(t, 'sub-item-d').controller!.text, '١١٩٠'); // 1250 - 5% = 1187.5 -> 1190
      await tapKey(t, 'chip-15');
      expect(selected('chip-15'), isTrue);
      expect(fieldOf(t, 'sub-item-r').controller!.text, '٤٣٠');
      // a manual edit clears every selection
      await t.enterText(find.byKey(const Key('sub-item-r')), '431');
      await t.pump();
      expect(selected('chip-5'), isFalse);
      expect(selected('chip-10'), isFalse);
      expect(selected('chip-15'), isFalse);
    });

    testWidgets('copy per template: reference, saving, per visit, net, preview, footnote', (t) async {
      await pumpFlow(t, baseApi());
      for (var i = 0; i < 3; i++) {
        await tapKey(t, 'qty-inc-item-r');
      }
      await tapKey(t, 'qty-inc-item-d');
      await next(t);
      expect(find.text('إجمالي الحجز بالزيارة'), findsOneWidget);
      expect(find.text('مرجع ثابت'), findsOneWidget);
      expect(find.text('٣ تنظيف عادي + ١ تنظيف مميز بأسعارك العادية'), findsOneWidget);
      expect(find.text('الخدمة'), findsOneWidget);
      expect(find.text('بره الاشتراك'), findsOneWidget);
      expect(find.text('في الاشتراك'), findsOneWidget);
      // 3*450 + 1*1130 = 2480 vs 2750
      expect(find.byKey(const Key('wizard-monthly')), findsOneWidget);
      expect(find.textContaining('٢٬٤٨٠'), findsWidgets);
      expect(find.textContaining('بدل'), findsNothing, reason: 'step 2 has no «بدل X بالزيارة» line');
      expect(find.byKey(const Key('wizard-save')), findsOneWidget);
      expect(find.text('يعني للزيارة'), findsOneWidget);
      expect(find.text('بيوصلك بعد العمولة'), findsOneWidget);
      expect(find.text('العميلة هتشوفها كده'), findsOneWidget);
      expect(find.text('معاينة'), findsOneWidget);
      expect(find.textContaining('من غير اشتراك ٥٠٠'), findsOneWidget);
      expect(find.textContaining('مشتركة ٤٥٠'), findsOneWidget);
      expect(find.text('السعر هنا للباقة دي بس — أسعار خدماتك العادية مش هتتغيّر. خصم بسيط وثابت غالبًا بيشتغل أحسن من خصم كبير أوي.'), findsOneWidget);
      // same price as pay-per-visit -> neutral copy, no saving block
      await t.enterText(find.byKey(const Key('sub-item-r')), '500');
      await t.enterText(find.byKey(const Key('sub-item-d')), '1250');
      await t.pump();
      expect(find.byKey(const Key('wizard-save')), findsNothing);
      expect(find.text('السعر ده نفس الحجز بالزيارة — العميلة مش هتوفّر حاجة.'), findsOneWidget);
      // price rows are at least 44px tall
      expect(t.getSize(find.byKey(const Key('sub-item-r'))).height, greaterThanOrEqualTo(24));
      final box = find.ancestor(of: find.byKey(const Key('sub-item-r')), matching: find.byType(Container)).first;
      expect(t.getSize(box).height, greaterThanOrEqualTo(44));
    });
  });

  group('step 3 · schedule', () {
    testWidgets('date pickers set start and end; end before start shows the error', (t) async {
      await pumpFlow(
        t,
        baseApi(),
        pick: pickerReturning({'تاريخ البداية': DateTime(2026, 10, 20), 'تاريخ النهاية': DateTime(2026, 12, 1)}),
      );
      await tapKey(t, 'qty-inc-item-r');
      await next(t);
      await next(t);
      // computed default start: today + 7
      expect(find.byKey(const Key('start-nice')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('start-nice'))).data, 'الجمعة، ٩ أكتوبر ٢٠٢٦');
      expect(find.text('اختاري يوم الزيارة'), findsOneWidget); // disabled CTA label
      await tapKey(t, 'day-3');
      expect(find.text('التالي'), findsOneWidget);
      await tapKey(t, 'start-field');
      expect(t.widget<Text>(find.byKey(const Key('start-nice'))).data, 'الثلاثاء، ٢٠ أكتوبر ٢٠٢٦');
      // switch to an end date
      await tapKey(t, 'mode-end');
      expect(t.widget<Text>(find.byKey(const Key('end-nice'))).data, 'اختاري تاريخ النهاية');
      expect(find.text('حددي تاريخ النهاية'), findsOneWidget); // disabled CTA (the segment reads «حددي تاريخ نهاية»)
      await tapKey(t, 'end-field');
      expect(t.widget<Text>(find.byKey(const Key('end-nice'))).data, 'الثلاثاء، ١ ديسمبر ٢٠٢٦');
      expect(find.text('التالي'), findsOneWidget);
    });

    testWidgets('end must be after start (error + red border + CTA label)', (t) async {
      var startPick = DateTime(2026, 10, 20);
      await pumpFlow(
        t,
        baseApi(),
        pick: (context, {required initial, required first, required last, help}) async => help == 'تاريخ البداية' ? startPick : DateTime(2026, 11, 1),
      );
      await tapKey(t, 'qty-inc-item-r');
      await next(t);
      await next(t);
      await tapKey(t, 'day-3');
      await tapKey(t, 'mode-end');
      await tapKey(t, 'end-field'); // Nov 1
      expect(find.text('التالي'), findsOneWidget);
      startPick = DateTime(2026, 11, 15);
      await tapKey(t, 'start-field');
      expect(t.widget<Text>(find.byKey(const Key('end-nice'))).data, 'لازم يكون بعد تاريخ البداية');
      expect(find.text('حددي تاريخ النهاية'), findsOneWidget);
      final field = t.widget<InkWell>(find.byKey(const Key('end-field')));
      final decorated = find.descendant(of: find.byWidget(field), matching: find.byType(Container)).first;
      final deco = t.widget<Container>(decorated).decoration as BoxDecoration;
      expect((deco.border as Border).top.width, 1.5);
      // going back to ongoing clears the problem and no end date is sent
      await tapKey(t, 'mode-ongoing');
      expect(find.text('التالي'), findsOneWidget);
    });

    testWidgets('the real date picker opens in Arabic, honours min date and confirms', (t) async {
      await pumpFlow(t, baseApi());
      await tapKey(t, 'qty-inc-item-r');
      await next(t);
      await next(t);
      await tapKey(t, 'start-field');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('تمام'), findsOneWidget);
      expect(find.text('إلغاء'), findsWidgets);
      final dlg = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dlg.firstDate, DateTime(2026, 10, 2), reason: 'min date is today');
      expect(dlg.initialDate, DateTime(2026, 10, 9));
      await t.tap(find.text('تمام'));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(t.widget<Text>(find.byKey(const Key('start-nice'))).data, 'الجمعة، ٩ أكتوبر ٢٠٢٦');
    });

    testWidgets('fit text and day chips', (t) async {
      await pumpFlow(t, baseApi());
      for (var i = 0; i < 4; i++) {
        await tapKey(t, 'qty-inc-item-r');
      }
      await next(t);
      await next(t);
      expect(find.text('اختاري يوم واحد على الأقل'), findsOneWidget);
      await tapKey(t, 'day-3');
      expect(find.textContaining('✓ العميلة هتختار يوم وفترة لكل زيارة'), findsOneWidget);
      expect(find.byKey(const Key('periods-note')), findsOneWidget);
      await tapKey(t, 'day-0');
      expect(find.textContaining('✓ العميلة هتختار يوم وفترة لكل زيارة'), findsOneWidget, reason: 'more days than needed is fine: the customer chooses');
      await tapKey(t, 'day-0');
      await tapKey(t, 'day-3');
      expect(find.text('اختاري يوم واحد على الأقل'), findsOneWidget);
    });
  });

  group('step 4 · benefits', () {
    testWidgets('add, remove, count label, limit message', (t) async {
      await pumpFlow(t, baseApi());
      await fillToStep4(t);
      expect(find.text('لسه مفيش مميزات'), findsOneWidget);
      expect(find.text('التالي من غير مميزات'), findsOneWidget);
      // add disabled while empty
      await tapKey(t, 'benefit-add');
      expect(find.text('لسه مفيش مميزات'), findsOneWidget);
      await t.enterText(find.byKey(const Key('benefit-input')), 'نفس المنظّفة كل زيارة');
      await t.pump();
      await tapKey(t, 'benefit-add');
      expect(find.text('نفس المنظّفة كل زيارة'), findsOneWidget);
      expect(find.text('ميزة واحدة'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
      expect(fieldOf(t, 'benefit-input').controller!.text, '');
      await t.enterText(find.byKey(const Key('benefit-input')), 'تغيير الميعاد مجانًا');
      await t.pump();
      await tapKey(t, 'benefit-add');
      expect(find.text('ميزتين'), findsOneWidget);
      await tapKey(t, 'benefit-del-0');
      expect(find.text('ميزة واحدة'), findsOneWidget);
      expect(find.text('نفس المنظّفة كل زيارة'), findsNothing);
      for (var i = 0; i < 5; i++) {
        await t.enterText(find.byKey(const Key('benefit-input')), 'ميزة رقم $i');
        await t.pump();
        await tapKey(t, 'benefit-add');
      }
      expect(find.text('٦ مميزات'), findsWidgets);
      expect(find.byKey(const Key('benefits-full')), findsOneWidget);
      expect(fieldOf(t, 'benefit-input').enabled, isFalse);
      // removing one re-opens the input
      await tapKey(t, 'benefit-del-0');
      expect(find.byKey(const Key('benefits-full')), findsNothing);
      expect(fieldOf(t, 'benefit-input').enabled, isTrue);
    });
  });

  group('step 5 · team and publish', () {
    testWidgets('chosen member survives publish: body has assigneeId, publish endpoint used', (t) async {
      final api = baseApi(workers: [worker('w1', 'هبة', last: 'علي', rating: 4.8), worker('w2', 'نورا'), worker('w3', 'خارج', active: false)]);
      await pumpFlow(t, api);
      await t.enterText(find.byKey(const Key('name-field')), 'نضافة شاملة');
      await fillToStep4(t);
      await next(t); // 4 -> 5
      expect(find.text('أي عضوة متاحة'), findsOneWidget);
      expect(find.text('أُنس بتوزّع حسب مواعيد الفريق'), findsOneWidget);
      expect(find.text('هبة علي'), findsOneWidget);
      expect(find.text('تقييم ٤٫٨'), findsOneWidget);
      expect(find.text('نورا'), findsOneWidget);
      expect(find.text('عضوة الفريق'), findsOneWidget);
      expect(find.text('خارج'), findsNothing);
      await tapKey(t, 'member-w1');
      await next(t); // 5 -> 6
      expect(find.text('هبة علي'), findsOneWidget); // review shows the NAME
      expect(find.byKey(const Key('review-name')), findsOneWidget);
      expect(find.text('نضافة شاملة'), findsWidgets);
      expect(find.text('انشري الباقة'), findsOneWidget);
      expect(find.textContaining('من الجمعة، ٩ أكتوبر ٢٠٢٦ · مستمرة من غير نهاية'), findsOneWidget);
      expect(find.text('التلات'), findsOneWidget);
      expect(find.textContaining('بدل'), findsWidgets);
      api.calls.clear();
      await next(t); // publish
      final saves = api.where('POST', '/pro/plans');
      expect(saves, isNotEmpty);
      for (final s in saves) {
        expect(s.body['assigneeMode'], 'member');
        expect(s.body['assigneeId'], 'w1');
      }
      expect(saves.last.body['status'], 'draft');
      expect(saves.last.body['name'], 'نضافة شاملة');
      expect(saves.last.body['endDate'], '');
      expect(saves.last.body['startDate'], '2026-10-09');
      expect(api.where('POST', '/pro/plans/p1/publish'), hasLength(1));
      // published screen
      expect(find.text('باقتك بقت متاحة'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('done-name'))).data, 'نضافة شاملة');
      expect(t.widget<Text>(find.byKey(const Key('done-line'))).data, contains('التلات'));
      expect(find.text('شوفيها في بروفايلي'), findsOneWidget);
      expect(find.text('ارجعي لباقاتي'), findsOneWidget);
    });

    testWidgets('«شوفيها في بروفايلي» opens the public profile', (t) async {
      var opened = 0;
      final api = baseApi();
      await pumpFlow(t, api, onProfile: () => opened++);
      await fillToStep4(t);
      await next(t);
      await next(t);
      await next(t);
      await tapKey(t, 'view-profile');
      expect(opened, 1);
    });

    testWidgets('no team: solo branch with the pointer to حسابي ← الفريق', (t) async {
      await pumpFlow(t, baseApi(workers: const []));
      await fillToStep4(t);
      await next(t);
      expect(find.text('مفيش فريق على حسابك دلوقتي، فالباقة دي هتبقى عليكي.'), findsOneWidget);
      expect(find.text('إنتي · صاحبة الحساب'), findsOneWidget);
      expect(find.text('كل زيارات الباقة هتروحيها بنفسك'), findsOneWidget);
      expect(find.text('عندك فريق؟ ضيفيهم من حسابي ← الفريق، وتقدري تعدّلي الباقة بعدين.'), findsOneWidget);
      final api = baseApi(workers: const []);
      await pumpFlow(t, api);
      await fillToStep4(t);
      await next(t);
      await next(t);
      await next(t);
      final last = api.where('POST', '/pro/plans').last.body;
      expect(last['assigneeMode'], 'self');
      expect(last['assigneeId'], '');
    });

    testWidgets('team load failure keeps her choice and offers a retry', (t) async {
      final api = baseApi();
      api.routes['GET /pro/workers'] = (_) => ApiException(500, 'خطأ');
      await pumpFlow(t, api);
      await fillToStep4(t);
      await next(t);
      expect(find.byKey(const Key('team-retry')), findsOneWidget);
      api.routes['GET /pro/workers'] = (_) => {'workers': [worker('w1', 'هبة')]};
      await tapKey(t, 'team-retry');
      expect(find.byKey(const Key('team-retry')), findsNothing);
      expect(find.text('هبة'), findsOneWidget);
    });

    testWidgets('publish failure shows the server message and keeps the wizard open', (t) async {
      final api = baseApi();
      api.routes['POST /pro/plans/p1/publish'] = (_) => ApiException(400, 'مينفعش تنشري أكتر من ٣ باقات شغّالة.');
      await pumpFlow(t, api);
      await fillToStep4(t);
      await next(t);
      await next(t);
      await next(t);
      expect(find.text('مينفعش تنشري أكتر من ٣ باقات شغّالة.'), findsOneWidget);
      expect(find.byKey(const Key('wizard-cta')), findsOneWidget);
      expect(find.text('باقتك بقت متاحة'), findsNothing);
    });

    testWidgets('step 6 section edit links jump back to the right step', (t) async {
      await pumpFlow(t, baseApi());
      await fillToStep4(t);
      await next(t);
      await next(t);
      await tapKey(t, 'edit-step-3');
      expect(find.text('حددي المواعيد'), findsOneWidget);
      await next(t);
      await next(t);
      await next(t);
      await tapKey(t, 'edit-step-2');
      expect(find.text('سعر كل خدمة في الاشتراك'), findsOneWidget);
    });
  });

  group('editing a live plan', () {
    Map<String, dynamic> live({String status = 'published'}) => Map<String, dynamic>.from(planRow(
      status: status,
      name: 'نضافة شاملة',
      assigneeMode: 'member',
      assigneeId: 'w1',
      lines: [
        {'catalogItemId': 'item-r', 'itemId': 'cat-r', 'name': {'ar': 'تنظيف عادي'}, 'quantity': 2, 'visitType': 'regular', 'subPricePiastres': 45000},
        {'catalogItemId': 'item-d', 'itemId': 'cat-d', 'name': {'ar': 'تنظيف مميز'}, 'quantity': 2, 'visitType': 'deep', 'subPricePiastres': 115000},
      ],
      weekdays: const [0, 3],
      benefits: const ['نفس المنظّفة'],
    )['plan'] as Map);

    testWidgets('quantities and prices restore, nothing is autosaved, save goes by id', (t) async {
      final api = baseApi(workers: [worker('w1', 'هبة')]);
      await pumpFlow(t, api, existing: live());
      expect(t.widget<Text>(find.byKey(const Key('qty-item-r'))).data, '٢');
      expect(t.widget<Text>(find.byKey(const Key('qty-item-d'))).data, '٢');
      expect(t.widget<Text>(find.byKey(const Key('qty-item-x'))).data, '٠');
      expect(fieldOf(t, 'name-field').controller!.text, 'نضافة شاملة');
      await tapKey(t, 'qty-inc-item-x');
      await t.pump(const Duration(milliseconds: 200));
      expect(api.where('POST', '/pro/plans'), isEmpty, reason: 'a live plan is not autosaved');
      await tapKey(t, 'qty-dec-item-x');
      await next(t);
      expect(fieldOf(t, 'sub-item-d').controller!.text, '١١٥٠');
      await next(t);
      expect(find.byKey(const Key('day-0')), findsOneWidget);
      await next(t);
      expect(find.text('نفس المنظّفة'), findsOneWidget);
      await next(t);
      await next(t);
      expect(find.text('احفظي ونشري التعديل'), findsOneWidget);
      expect(find.byKey(const Key('edit-note')), findsOneWidget);
      expect(find.text('هبة'), findsWidgets);
      await next(t);
      expect(api.where('POST', '/pro/plans'), isEmpty);
      final saves = api.where('POST', '/pro/plans/p1/publish');
      expect(saves, hasLength(1));
      expect(saves.single.body['id'], 'p1');
      expect(saves.single.body['status'], 'published');
      expect(saves.single.body['assigneeId'], 'w1');
      expect(saves.single.body['assigneeMode'], 'member');
      expect(saves.single.body['startDate'], '2026-10-20');
      expect(find.textContaining('إصدار جديد'), findsOneWidget);
    });

    testWidgets('a paused plan stays paused when edited', (t) async {
      final api = baseApi(workers: [worker('w1', 'هبة')]);
      await pumpFlow(t, api, existing: live(status: 'paused'));
      for (var i = 0; i < 5; i++) {
        await next(t);
      }
      expect(find.text('احفظي التعديل'), findsOneWidget);
      await next(t);
      expect(api.where('POST', '/pro/plans').single.body['status'], 'paused');
      expect(find.text('اتحفظ التعديل'), findsOneWidget);
    });
  });

  group('draft autosave', () {
    testWidgets('a name-only draft is saved; fast edits coalesce; the plan id is reused', (t) async {
      final api = baseApi();
      api.latency = const Duration(milliseconds: 120);
      await pumpFlow(t, api);
      await t.enterText(find.byKey(const Key('name-field')), 'باقة أولى');
      await t.pump(const Duration(milliseconds: 60)); // debounce fires, request in flight
      await t.enterText(find.byKey(const Key('name-field')), 'باقة أولى ٢');
      await t.pump(const Duration(milliseconds: 20));
      await t.enterText(find.byKey(const Key('name-field')), 'باقة أولى ٣');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      final saves = api.where('POST', '/pro/plans');
      expect(saves.length, 2, reason: 'one in flight + one coalesced follow-up: ${saves.map((c) => c.data)}');
      expect(saves.first.body.containsKey('id'), isFalse);
      expect(saves.last.body['id'], 'p1', reason: 'the second request carries the id from the first response');
      expect(saves.last.body['name'], 'باقة أولى ٣');
      expect(saves.every((c) => c.body['status'] == 'draft'), isTrue);
      expect(find.textContaining('اتحفظت كمسودة'), findsOneWidget);
      await t.pumpWidget(Container());
    });

    testWidgets('a failed autosave is shown, not swallowed', (t) async {
      final api = baseApi();
      api.routes['POST /pro/plans'] = (_) => ApiException(400, 'مسودة ناقصة');
      await pumpFlow(t, api);
      await t.enterText(find.byKey(const Key('name-field')), 'باقة');
      await t.pump(const Duration(milliseconds: 200));
      await t.pump();
      expect(find.textContaining('المسودة ما اتحفظتش'), findsOneWidget);
      await t.pumpWidget(Container());
    });

    testWidgets('resuming a draft restores it and lands on the step she left', (t) async {
      final api = baseApi(workers: [worker('w1', 'هبة')]);
      final draft = Map<String, dynamic>.from(planRow(status: 'draft', name: 'مسودتي', weekdays: const [], extra: {'step': 3})['plan'] as Map);
      draft['lines'] = [
        {'catalogItemId': 'item-r', 'itemId': 'cat-r', 'name': {'ar': 'تنظيف عادي'}, 'quantity': 4, 'subPricePiastres': 45000},
      ];
      await pumpFlow(t, api, existing: draft);
      expect(find.text('حددي المواعيد'), findsOneWidget);
      expect(find.text('اختاري يوم الزيارة'), findsOneWidget);
      // without a stored step: first incomplete step
      draft.remove('step');
      await pumpFlow(t, api, existing: draft);
      expect(find.text('حددي المواعيد'), findsOneWidget);
      // saving a draft keeps its id and does not flip it to published
      await tapKey(t, 'day-3');
      await t.pump(const Duration(milliseconds: 200));
      final s = api.where('POST', '/pro/plans').last.body;
      expect(s['id'], 'p1');
      expect(s['status'], 'draft');
      expect(s['step'], 3);
      await t.pumpWidget(Container());
    });

    testWidgets('leaving the wizard flushes the pending draft first', (t) async {
      final api = baseApi();
      phoneViewport(t);
      await t.pumpWidget(arabicHost(Builder(builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanWizardFlow(services: testServices(), api: api, now: fixedNow(), saveDelay: const Duration(seconds: 5)))),
                child: const Text('افتحي'),
              ),
            ),
          ))));
      await t.tap(find.text('افتحي'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('name-field')), 'باقة سريعة');
      await t.pump();
      expect(api.where('POST', '/pro/plans'), isEmpty);
      await tapKey(t, 'wizard-cancel');
      expect(api.where('POST', '/pro/plans'), hasLength(1));
      expect(find.byType(PlanWizardFlow), findsNothing);
    });
  });
}
