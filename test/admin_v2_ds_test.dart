import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/theme/theme.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/ds/tokens.dart';

Widget host(Widget child) => MaterialApp(
      theme: opsV2Theme(arabic: true),
      home: Scaffold(body: Center(child: child)),
    );

/// The console (bo.oons.app) is the Ons design system, not a palette of its own.
void main() {
  group('Ops tokens ARE the design system', () {
    test('colours resolve to Ds', () {
      expect(Ops.page, Ds.cream);
      expect(Ops.card, Ds.white);
      expect(Ops.ink, Ds.ink);
      expect(Ops.border, Ds.ink, reason: 'one 1px ink border on cards, fields, buttons');
      expect(Ops.borderSoft, Ds.divider, reason: 'hairlines only between rows inside a card');
      expect(Ops.plum, Ds.plum);
      expect(Ops.green, Ds.olive);
      expect(Ops.terracotta, Ds.terracotta);
      expect(Ops.terracottaTint, Ds.terracottaBg);
      expect(Ops.muted, Ds.textMuted);
      expect(Ops.headBg, Ds.surface);
    });

    test('every corner is square', () {
      for (final r in [Ops.radiusCard, Ops.radiusCtl, Ops.radiusBtn, Ops.radiusNav, Ops.radiusModal, Ops.radiusPill]) {
        expect(r, 0);
      }
    });

    test('targets are 44px', () => expect(Ops.minTarget, 44));
  });

  group('theme', () {
    final th = opsV2Theme(arabic: false);
    test('inputs and buttons are square with the ink rule', () {
      final b = th.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(b.borderRadius, BorderRadius.zero);
      expect(b.borderSide.color, Ds.ink);
      final shape = th.elevatedButtonTheme.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.zero);
    });
  });

  group('atoms', () {
    testWidgets('V2Btn is a square, bordered, 44px target', (t) async {
      await t.pumpWidget(host(V2Btn.primary('Save', onPressed: () {})));
      final box = t.getSize(find.byType(V2Btn));
      expect(box.height, greaterThanOrEqualTo(44));
      final deco = t.widget<Container>(find.descendant(of: find.byType(V2Btn), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(deco.borderRadius, isNull);
      expect(deco.border, isNotNull);
    });

    testWidgets('status pill: olive for done, terracotta for needs attention, label always present', (t) async {
      await t.pumpWidget(host(Column(mainAxisSize: MainAxisSize.min, children: const [
        V2StatusPill(label: 'Completed', tone: V2Tone.ok),
        V2StatusPill(label: 'Disputed', tone: V2Tone.bad),
      ])));
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Disputed'), findsOneWidget);
      final fills = t.widgetList<Container>(find.descendant(of: find.byType(V2StatusPill), matching: find.byType(Container))).map((c) => (c.decoration! as BoxDecoration).color).toList();
      expect(fills, [Ds.olive, Ds.terracottaBg]);
    });

    testWidgets('card, filter chip and meter have no rounded corners', (t) async {
      await t.pumpWidget(host(Column(mainAxisSize: MainAxisSize.min, children: [
        const V2Card(child: Text('x')),
        V2FilterChip(label: 'All', selected: true, onTap: () {}),
        const SizedBox(width: 300, child: V2MiniBar(label: 'a', fraction: .5, value: '5')),
      ])));
      for (final c in t.widgetList<Container>(find.byType(Container))) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          expect(d.borderRadius, isNull);
          expect(d.shape, BoxShape.rectangle);
          expect(d.boxShadow, isNull);
        }
      }
    });
  });

  test('the console source has no hard-coded radius, hex colour or shadow', () {
    final offenders = <String>[];
    for (final f in Directory('lib/admin_v2').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('theme/tokens.dart')) continue; // the token file defines the translucent plum tints
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (RegExp(r'BorderRadius\.circular\(\s*\d').hasMatch(l) ||
            RegExp(r'Radius\.circular\(\s*\d').hasMatch(l) ||
            l.contains('BoxShape.circle') ||
            l.contains('BoxShadow') ||
            RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)').hasMatch(l)) {
          offenders.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
