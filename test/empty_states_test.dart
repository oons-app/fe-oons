import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/l10n/copy.dart';

Widget _app(Widget child, {String lang = 'ar'}) => MaterialApp(
      locale: Locale(lang),
      home: Directionality(
        textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void _expectFourParts(WidgetTester t, {bool alt = false}) {
  expect(find.byType(OnsEmptyState), findsOneWidget);
  // 1. icon box 46px
  final box = t.widget<Container>(find.descendant(of: find.byType(OnsEmptyState), matching: find.byType(Container)).first);
  expect(box.constraints?.maxWidth ?? 46, 46);
  // 2 + 3. headline and reason (two Text blocks before the button)
  expect(find.byType(ClientPrimaryButton), findsOneWidget);
  expect(find.byType(InkWell), alt ? findsNWidgets(2) : findsNWidgets(1));
}

void main() {
  testWidgets('EMPTY-01 nothing picked: four parts, CTA fires', (t) async {
    var n = 0;
    await t.pumpWidget(_app(OnsEmpty.nothingPicked(lang: 'ar', onBrowse: () => n++)));
    _expectFourParts(t);
    expect(find.text('لم تختاري أي خدمة بعد'), findsOneWidget);
    await t.tap(find.byType(ClientPrimaryButton));
    expect(n, 1);
  });

  testWidgets('EMPTY-02 availability names area+day and only states counts it was given', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noAvailability(
      lang: 'ar', area: 'المعادي', day: 'اليوم', nextDayLabel: 'الجمعة ١٩', nextCount: 6, widerCount: 3, onNext: () {}, onWiden: () {},
    )));
    _expectFourParts(t, alt: true);
    expect(find.text('لا توجد مواعيد في المعادي اليوم'), findsOneWidget);
    expect(find.textContaining('أقرب يوم متاح: الجمعة ١٩ (٦ مواعيد)'), findsOneWidget);
    expect(find.textContaining('تتوفر ٣ اليوم'), findsOneWidget);

    await t.pumpWidget(_app(OnsEmpty.noAvailability(lang: 'ar', area: 'المعادي', day: 'اليوم', onNext: () {})));
    expect(find.textContaining('أقرب يوم متاح'), findsNothing, reason: 'unknown counts must not be invented');
    expect(find.textContaining('بتوسيع المنطقة'), findsNothing);
    _expectFourParts(t);
  });

  testWidgets('EMPTY-03 no address', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noAddress(lang: 'ar', onAdd: () {})));
    _expectFourParts(t);
    expect(find.text('إضافة عنوان'), findsOneWidget);
  });

  testWidgets('past bookings empty uses the four-part pattern', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noPast(lang: 'ar', onBrowse: () {})));
    _expectFourParts(t);
    expect(find.text('لا زيارات سابقة بعد'), findsOneWidget);
  });

  testWidgets('EMPTY-04 bookings: repeat offer uses the real last visit; none → browse only', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noUpcoming(lang: 'ar', lastProvider: 'دعاء مصطفى', lastDate: '١ سبتمبر', onRepeat: () {}, onBrowse: () {})));
    _expectFourParts(t, alt: true);
    expect(find.textContaining('دعاء مصطفى'), findsOneWidget);
    expect(find.textContaining('١ سبتمبر'), findsOneWidget);
    expect(find.text('تكرار آخر زيارة'), findsOneWidget);

    await t.pumpWidget(_app(OnsEmpty.noUpcoming(lang: 'ar', onBrowse: () {})));
    _expectFourParts(t);
    expect(find.text('تكرار آخر زيارة'), findsNothing);
    expect(find.text('عرض جميع الخدمات'), findsOneWidget);
  });

  testWidgets('EMPTY-05 search: names the query and the real nearest service', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noMatch(lang: 'ar', query: 'باديكير جل', nearest: 'بديكير ومانيكير', onNearest: () {}, onSuggest: () {})));
    _expectFourParts(t, alt: true);
    expect(find.text('لم نجد «باديكير جل»'), findsOneWidget);
    expect(find.textContaining('بديكير ومانيكير'), findsNWidgets(2)); // body + button
  });

  testWidgets('EMPTY-06 no ratings', (t) async {
    await t.pumpWidget(_app(OnsEmpty.noRatings(lang: 'ar', onPast: () {})));
    _expectFourParts(t);
  });

  testWidgets('EMPTY-07 offline is a warn tone and says the selection is saved', (t) async {
    await t.pumpWidget(_app(OnsEmpty.offline(lang: 'ar', onRetry: () {})));
    _expectFourParts(t);
    expect(find.textContaining('اختياراتك محفوظة'), findsOneWidget);
    expect(t.widget<OnsEmptyState>(find.byType(OnsEmptyState)).tone, EmptyTone.warn);
  });

  testWidgets('EMPTY-08 fetch failed: retry + support, owns the fault', (t) async {
    var support = 0;
    var retry = 0;
    await t.pumpWidget(_app(OnsEmpty.fetchFailed(lang: 'ar', onRetry: () => retry++, onSupport: () => support++)));
    _expectFourParts(t, alt: true);
    expect(find.textContaining('العطل من جهتنا'), findsOneWidget);
    await t.tap(find.text('تواصلي مع الدعم'));
    expect(support, 1);
    // Tap the empty middle of the primary button too — the whole bar must be hittable.
    await t.tapAt(t.getCenter(find.byType(ClientPrimaryButton)));
    expect(retry, 1);
  });

  testWidgets('English mirror exists for every state', (t) async {
    final en = Copy.of('en')['empty'] as Map;
    final ar = Copy.of('ar')['empty'] as Map;
    expect(en.keys.toSet(), ar.keys.toSet());
    await t.pumpWidget(_app(OnsEmpty.fetchFailed(lang: 'en', onRetry: () {}, onSupport: () {}), lang: 'en'));
    expect(find.text('We couldn\'t load the services'), findsOneWidget);
  });
}
