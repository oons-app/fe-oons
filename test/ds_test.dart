import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/ds/gallery.dart';
import 'package:oons/features/client/client_chrome.dart';

Widget host(Widget child, {String lang = 'ar'}) => MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Builder(builder: (c) => child)),
    );

void main() {
  group('tokens', () {
    test('the palette is the customer app\'s palette — they must never drift', () {
      expect(Ds.cream, T.bg);
      expect(Ds.cream, Client.bg);
      expect(Ds.ink, T.ink);
      expect(Ds.ink, Client.ink);
      expect(Ds.plum, T.action);
      expect(Ds.plum, Client.plum);
      expect(Ds.plumPressed, T.actionPressed);
      expect(Ds.plumLight, T.plumTint);
      expect(Ds.plumLight, Client.plumTint);
      expect(Ds.olive, T.trust);
      expect(Ds.olive, Client.olive);
      expect(Ds.oliveText, T.trustInk);
      expect(Ds.oliveText, Client.oliveInk);
      expect(Ds.terracotta, Client.terracotta);
      expect(Ds.terracottaBg, Client.warnTint);
      expect(Ds.terracottaText, Client.defer);
      expect(Ds.divider, T.line);
      expect(Ds.divider, Client.line);
      expect(Ds.surface, Client.sand2);
      expect(Ds.textBody, T.body);
      expect(Ds.textMuted, T.muted);
      expect(Ds.textFaint, Client.muted2);
    });

    test('shape: no radius, 1px rule, 44px targets', () {
      expect(Ds.radius, 0);
      expect(Ds.rule, 1);
      expect(Ds.minTarget, 44);
      expect(T.radius, 0);
    });

    test('numbers are always IBM Plex Mono', () {
      expect(DsText.num().fontFamily, T.mono);
    });
  });

  group('format', () {
    test('digits follow the language', () {
      expect(DsFormat.digits(120, ar: true), '١٢٠');
      expect(DsFormat.digits(120, ar: false), '120');
    });
    test('prices', () {
      expect(DsFormat.price(1200, ar: true), '١,٢٠٠ ج.م');
      expect(DsFormat.price(1200, ar: false), '1,200 EGP');
      expect(DsFormat.price(0, ar: true), '٠ ج.م');
      expect(DsFormat.price(1234567, ar: true), '١,٢٣٤,٥٦٧ ج.م');
      expect(DsFormat.pricePiastres(240000, ar: true), '٢,٤٠٠ ج.م');
      expect(DsFormat.amount(800, ar: true), '٨٠٠');
    });
    test('time, percent, range', () {
      expect(DsFormat.time('9:00', ar: true), '٠٩:٠٠');
      expect(DsFormat.time('16:00', ar: false), '16:00');
      expect(DsFormat.percent(10, ar: true), '١٠٪');
      expect(DsFormat.range(120, 150, ar: true, unit: 'م²'), '١٢٠–١٥٠ م²');
    });
    test('Arabic number agreement', () {
      expect(DsFormat.specialties(1, ar: true), 'تخصص واحد');
      expect(DsFormat.specialties(2, ar: true), 'تخصصين');
      expect(DsFormat.specialties(5, ar: true), '٥ تخصصات');
      expect(DsFormat.specialties(11, ar: true), '١١ تخصص');
      expect(DsFormat.services(0, ar: true), '٠ خدمة');
      expect(DsFormat.services(3, ar: true), '٣ خدمات');
      expect(DsFormat.visits(2, ar: true), 'زيارتين');
      expect(DsFormat.tasks(5, ar: true), '٥ بنود');
      expect(DsFormat.services(1, ar: false), '1 service');
      expect(DsFormat.services(4, ar: false), '4 services');
    });
    test('durations', () {
      expect(DsFormat.durationShort(360, ar: true), '٦ س');
      expect(DsFormat.durationShort(90, ar: true), '١.٥ س');
      expect(DsFormat.durationShort(45, ar: true), '٤٥ د');
      expect(DsFormat.duration(360, ar: true), '٦ ساعات');
    });
  });

  group('components', () {
    testWidgets('button: 54px / 46px, fires once, silent when busy or disabled', (t) async {
      var n = 0;
      await t.pumpWidget(host(Column(children: [
        DsButton(key: const Key('a'), label: 'احفظي', onTap: () => n++),
        DsButton(key: const Key('b'), label: 'ثانوي', kind: DsButtonKind.secondary, compact: true, onTap: () => n++),
        DsButton(key: const Key('c'), label: 'مشغول', busy: true, onTap: () => n++),
        const DsButton(key: Key('d'), label: 'مقفول', onTap: null),
      ])));
      expect(t.getSize(find.byKey(const Key('a'))).height, 54);
      expect(t.getSize(find.byKey(const Key('b'))).height, 46);
      for (final k in ['a', 'b', 'c', 'd']) {
        await t.tap(find.byKey(Key(k)));
      }
      expect(n, 2, reason: 'busy and disabled buttons never fire');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('switch: toggles, is 44px tall, announces its state', (t) async {
      var on = false;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, set) => DsSwitch(on: on, label: 'متاحة', onChanged: (v) => set(() => on = v)))));
      expect(t.getSize(find.byType(DsSwitch)).height, greaterThanOrEqualTo(44));
      await t.tap(find.byType(DsSwitch));
      await t.pump();
      expect(on, isTrue);
      final sem = t.getSemantics(find.byType(DsSwitch));
      expect(sem.label, 'متاحة');
      expect(sem.getSemanticsData().flagsCollection.isToggled, Tristate.isTrue);
    });

    testWidgets('segmented selects; each cell is at least 44px', (t) async {
      var i = 0;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, set) => DsSegmented(labels: const ['الخدمات', 'المناطق', 'المواعيد'], index: i, onChanged: (v) => set(() => i = v)))));
      expect(t.getSize(find.byType(DsSegmented)).height, greaterThanOrEqualTo(44));
      await t.tap(find.text('المناطق'));
      await t.pump();
      expect(i, 1);
    });

    testWidgets('chip toggles and meets the 44px target', (t) async {
      var on = false;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, set) => DsChip(label: 'مدينتي', on: on, onTap: () => set(() => on = !on)))));
      expect(t.getSize(find.byType(DsChip)).height, greaterThanOrEqualTo(44));
      await t.tap(find.byType(DsChip));
      expect(on, isTrue);
    });

    testWidgets('chips hug their label: side by side in a Wrap, never one per row', (t) async {
      await t.pumpWidget(host(Wrap(spacing: 8, children: [
        DsChip(label: 'الكل ٢', on: true, onTap: () {}),
        DsChip(label: 'ظاهرة ١', on: false, onTap: () {}),
        DsChip(label: 'مخفية ١', on: false, onTap: () {}),
      ])));
      final rects = t.widgetList(find.byType(DsChip)).map((w) => t.getRect(find.byWidget(w))).toList();
      expect(rects.map((r) => r.top).toSet().length, 1, reason: 'all three on the same row');
      expect(rects.every((r) => r.width < 150), isTrue);
      expect(rects.every((r) => r.height >= 44), isTrue);
    });

    testWidgets('seven compact day chips share one narrow row without cutting their labels', (t) async {
      t.view.physicalSize = const Size(350, 400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const days = ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة'];
      await t.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: DsChip(compact: true, label: days[i], on: i.isEven, onTap: () {})),
          ],
        ]),
      )));
      expect(t.takeException(), isNull);
      for (final d in days) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.byType(FittedBox), findsNWidgets(7), reason: 'long labels scale down instead of ending in …');
    });

    testWidgets('list row: tappable rows expose a button; danger row uses the attention colour', (t) async {
      var tapped = false;
      await t.pumpWidget(host(DsListRow(label: 'احذفي حسابي', danger: true, onTap: () => tapped = true)));
      expect(t.getSize(find.byType(DsListRow)).height, greaterThanOrEqualTo(56));
      expect(t.widget<Text>(find.text('احذفي حسابي')).style!.color, Ds.terracottaText);
      await t.tap(find.byType(DsListRow));
      expect(tapped, isTrue);
    });

    testWidgets('badge tones', (t) async {
      await t.pumpWidget(host(const Row(children: [DsStatusBadge('خلصت', tone: DsTone.olive), DsStatusBadge('اتلغت'), DsStatusBadge('قيد المراجعة', tone: DsTone.attention)])));
      final boxes = t.widgetList<Container>(find.byType(Container)).map((c) => (c.decoration as BoxDecoration?)?.color).whereType<Color>().toList();
      expect(boxes, containsAll([Ds.olive, Ds.neutral, Ds.terracottaBg]));
    });

    testWidgets('empty state: icon tile, fact, why, one action, optional link', (t) async {
      var cta = 0, link = 0;
      await t.pumpWidget(host(DsEmptyState(icon: 'calendar', title: 'مفيش زيارات', body: 'الحجوزات هتظهر هنا.', cta: 'زوّدي مناطق', onCta: () => cta++, link: 'أو زوّدي ساعات', onLink: () => link++)));
      expect(find.byType(DsIconTile), findsOneWidget);
      expect(find.text('مفيش زيارات'), findsOneWidget);
      await t.tap(find.text('زوّدي مناطق'));
      await t.tap(find.text('أو زوّدي ساعات'));
      expect((cta, link), (1, 1));
    });

    testWidgets('sheet opens with its title and closes with ×', (t) async {
      await t.pumpWidget(host(Builder(builder: (c) => TextButton(onPressed: () => showDsSheet<void>(c, title: 'العنوان', builder: (_) => const Text('المحتوى')), child: const Text('open')))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('العنوان'), findsOneWidget);
      expect(find.text('المحتوى'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('إغلاق'));
      await t.pumpAndSettle();
      expect(find.text('المحتوى'), findsNothing);
    });

    testWidgets('toast shows for 1.8s, replaces the previous one and lets taps through', (t) async {
      var taps = 0;
      await t.pumpWidget(host(Builder(builder: (c) => Column(children: [
            TextButton(onPressed: () { taps++; DsToast.show(c, 'اتحفظ'); }, child: const Text('save')),
          ]))));
      await t.tap(find.text('save'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('اتحفظ'), findsOneWidget);
      await t.tap(find.text('save'));
      await t.pump(const Duration(milliseconds: 200));
      expect(taps, 2, reason: 'the toast does not swallow taps');
      expect(find.text('اتحفظ'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1700));
      expect(find.text('اتحفظ'), findsNothing);
    });

    testWidgets('bottom nav marks the active tab', (t) async {
      var i = 1;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, set) => DsBottomNav(
            items: const [DsNavItem(label: 'الزيارات', icon: 'calendar'), DsNavItem(label: 'خدماتي', icon: 'list')],
            index: i,
            onTap: (v) => set(() => i = v),
          ))));
      await t.tap(find.text('الزيارات'));
      await t.pump();
      expect(i, 0);
    });

    for (final lang in ['ar', 'en']) {
      testWidgets('gallery renders in $lang without errors', (t) async {
        t.view.physicalSize = const Size(390, 6000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(ProviderScope(child: host(const DsGalleryScreen(), lang: lang)));
        await t.pump();
        expect(find.text('Ons Design System'), findsOneWidget);
        expect(tester(t), isNull);
      });
    }
  });
}

Object? tester(WidgetTester t) => t.takeException();
