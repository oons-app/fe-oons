import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/plan_wizard.dart';

import 'subscription_provider_fakes.dart';

FakeApi api0(List<Map<String, dynamic>> plans, {List<Map<String, dynamic>> workers = const []}) {
  final a = FakeApi();
  a.routes['GET /pro/plans'] = (_) => {'plans': plans, 'enabled': true};
  a.routes['GET /pro/workers'] = (_) => {'workers': workers};
  return a;
}

Future<void> pumpPlans(WidgetTester t, FakeApi api) async {
  phoneViewport(t);
  t.view.physicalSize = const Size(390, 2400);
  await t.pumpWidget(Container());
  await t.pumpWidget(arabicHost(PlanWizard(services: testServices(), api: api, providerId: 'prov1', now: () => DateTime(2026, 10, 2))));
  await t.pumpAndSettle();
}

void goBack(WidgetTester t) => t.state<NavigatorState>(find.byType(Navigator).first).pop();

Future<void> tapK(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: key);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('cards show name, mix, price, ref, member NAME, subscribers, chip; archived hidden', (t) async {
    final api = api0([
      planRow(id: 'a', name: 'الأساسيات الأسبوعية', subscribers: 3),
      planRow(id: 'b', name: 'نضافة شاملة', status: 'paused', assigneeMode: 'member', assigneeId: 'w1', pricePiastres: 320000, paygPiastres: 320000),
      planRow(id: 'c', name: 'مسودتي', status: 'draft'),
      planRow(id: 'd', name: 'قديمة', status: 'archived'),
      planRow(id: 'e', name: '', status: 'published', assigneeMode: 'self'),
    ], workers: [worker('w1', 'هبة', last: 'علي')]);
    await pumpPlans(t, api);
    expect(find.text('باقاتي'), findsWidgets);
    expect(find.text('٤ باقات · كل باقة مستقلة بسعرها ومواعيدها'), findsOneWidget);
    expect(find.text('الأساسيات الأسبوعية'), findsOneWidget);
    expect(find.text('٤ تنظيف عادي في الشهر'), findsWidgets);
    expect(find.text('١٬٨٠٠'), findsWidgets);
    expect(find.textContaining('بدل'), findsWidgets);
    expect(find.text('٣ مشتركة نشطة'), findsOneWidget);
    expect(find.text('هبة علي'), findsOneWidget, reason: 'member name from /pro/workers, not «عضوة محددة»');
    expect(find.text('عضوة محددة'), findsNothing);
    expect(find.text('[اسم الباقة]'), findsOneWidget);
    expect(find.text('إنتي · صاحبة الحساب'), findsOneWidget);
    expect(find.text('متاحة'), findsNWidgets(2));
    expect(find.text('متوقّفة'), findsOneWidget);
    expect(find.text('مسودة'), findsOneWidget);
    expect(find.text('قديمة'), findsNothing);
    expect(find.text('+ اعملي باقة جديدة'), findsOneWidget);
    await tapK(t, 'toggle-archived');
    expect(find.text('قديمة'), findsOneWidget);
    expect(find.text('مؤرشفة'), findsOneWidget);
  });

  testWidgets('three labelled entries: باقاتي · الأسبوع ده · المشتركات', (t) async {
    final api = api0([planRow()]);
    api.routes['GET /pro/schedule/week'] = (_) => {'from': '2026-10-02', 'capacityPerDay': 4, 'days': [], 'visits': []};
    api.routes['GET /pro/subscribers'] = (_) => {'summary': {'active': 0, 'visitsThisWeek': 0}, 'rows': []};
    await pumpPlans(t, api);
    expect(find.text('باقاتي'), findsWidgets);
    expect(find.text('الأسبوع ده'), findsOneWidget);
    expect(find.text('المشتركات'), findsOneWidget);
    await tapK(t, 'tab-week');
    expect(api.where('GET', '/pro/schedule/week'), hasLength(1));
    goBack(t);
    await t.pumpAndSettle();
    await tapK(t, 'tab-subscribers');
    expect(api.where('GET', '/pro/subscribers'), hasLength(1));
  });

  testWidgets('archive asks first; a 409 shows the server message and offers to pause instead', (t) async {
    final api = api0([planRow(id: 'a', subscribers: 2)]);
    api.routes['DELETE /pro/plans/a'] = (_) => ApiException(409, 'الباقة لسه فيها مشتركات. وقّفيها بدل ما تعمليها أرشيف.');
    api.routes['POST /pro/plans/a/pause'] = (_) => {'plan': {'id': 'a', 'status': 'paused'}};
    await pumpPlans(t, api);
    await tapK(t, 'archive-a');
    expect(find.text('تأرشفي الباقة؟'), findsOneWidget);
    expect(api.where('DELETE', '/pro/plans/a'), isEmpty);
    await t.tap(find.text('لأ، سيبيها'));
    await t.pumpAndSettle();
    expect(api.where('DELETE', '/pro/plans/a'), isEmpty);
    await tapK(t, 'archive-a');
    await t.tap(find.text('أرشفي'));
    await t.pumpAndSettle();
    expect(api.where('DELETE', '/pro/plans/a'), hasLength(1));
    expect(find.text('الباقة لسه فيها مشتركات. وقّفيها بدل ما تعمليها أرشيف.'), findsOneWidget);
    await t.tap(find.text('وقّفي الباقة بدلاً من كده'));
    await t.pumpAndSettle();
    expect(api.where('POST', '/pro/plans/a/pause'), hasLength(1));
  });

  testWidgets('archive success removes the card after reload', (t) async {
    var archived = false;
    final api = FakeApi();
    api.routes['GET /pro/plans'] = (_) => {'plans': archived ? [planRow(id: 'a', status: 'archived')] : [planRow(id: 'a')], 'enabled': true};
    api.routes['GET /pro/workers'] = (_) => {'workers': []};
    api.routes['DELETE /pro/plans/a'] = (_) {
      archived = true;
      return {'ok': true};
    };
    await pumpPlans(t, api);
    await tapK(t, 'archive-a');
    await t.tap(find.text('أرشفي'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('plan-a')), findsNothing);
    expect(find.text('لسه مفيش باقات شغّالة'.replaceAll('لسه مفيش باقات شغّالة', 'مفيش باقات شغّالة')), findsOneWidget);
  });

  testWidgets('pause and resume confirm first', (t) async {
    final api = api0([planRow(id: 'a'), planRow(id: 'b', status: 'paused')]);
    api.routes['POST /pro/plans/a/pause'] = (_) => {'plan': {}};
    api.routes['POST /pro/plans/b/resume'] = (_) => {'plan': {}};
    await pumpPlans(t, api);
    await tapK(t, 'pause-a');
    expect(find.text('توقّفي الباقة؟'), findsOneWidget);
    await t.tap(find.text('لأ، سيبيها'));
    await t.pumpAndSettle();
    expect(api.where('POST', '/pro/plans/a/pause'), isEmpty);
    await tapK(t, 'pause-a');
    await t.tap(find.text('وقّفي').last);
    await t.pumpAndSettle();
    expect(api.where('POST', '/pro/plans/a/pause'), hasLength(1));
    await tapK(t, 'resume-b');
    expect(find.text('ترجّعي الباقة؟'), findsOneWidget);
    await t.tap(find.text('ارجعيها').last);
    await t.pumpAndSettle();
    expect(api.where('POST', '/pro/plans/b/resume'), hasLength(1));
  });

  testWidgets('pause failure shows the Arabic message, never a raw exception', (t) async {
    final api = api0([planRow(id: 'a')]);
    api.routes['POST /pro/plans/a/pause'] = (_) => ApiException(500, 'internal');
    await pumpPlans(t, api);
    await tapK(t, 'pause-a');
    await t.tap(find.text('وقّفي').last);
    await t.pumpAndSettle();
    expect(find.text('حصلت مشكلة. جرّبي تاني.'), findsOneWidget);
    expect(find.textContaining('internal'), findsNothing);
  });

  testWidgets('empty state with the CTA, and error state with retry', (t) async {
    await pumpPlans(t, api0([]));
    expect(find.text('لسه معندكيش باقات'), findsOneWidget);
    expect(find.text('+ اعملي باقة جديدة'), findsOneWidget);
    final bad = FakeApi();
    bad.routes['GET /pro/plans'] = (_) => ApiException(500, 'x');
    await pumpPlans(t, bad);
    expect(find.text('ما قدرناش نجيب باقاتك. جرّبي تاني.'), findsOneWidget);
    bad.routes['GET /pro/plans'] = (_) => {'plans': [planRow()], 'enabled': true};
    bad.routes['GET /pro/workers'] = (_) => {'workers': []};
    await t.tap(find.text('جرّبي تاني'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('plan-p1')), findsOneWidget);
  });

  testWidgets('a draft card resumes the draft; "new plan" reuses the single draft', (t) async {
    final api = api0([planRow(id: 'dr', status: 'draft', name: 'مسودتي', weekdays: const [], extra: {'step': 3})]);
    api.routes['POST /pro/plans'] = (c) => {'plan': {...c.body, 'id': c.body['id'] ?? 'dr'}};
    await pumpPlans(t, api);
    expect(find.text('كمّلي'), findsOneWidget);
    await tapK(t, 'edit-dr');
    expect(find.text('حددي المواعيد'), findsOneWidget);
    goBack(t);
    await t.pumpAndSettle();
    await tapK(t, 'new-plan');
    expect(find.text('حددي المواعيد'), findsOneWidget, reason: 'the existing draft is resumed instead of being overwritten');
  });

  testWidgets('tap targets on a plan card are at least 44px', (t) async {
    await pumpPlans(t, api0([planRow(id: 'a')]));
    for (final k in ['edit-a', 'pause-a', 'dup-a', 'archive-a']) {
      final s = t.getSize(find.byKey(Key(k)));
      expect(s.height, greaterThanOrEqualTo(44), reason: k);
      expect(s.width, greaterThanOrEqualTo(44), reason: k);
    }
  });
}
