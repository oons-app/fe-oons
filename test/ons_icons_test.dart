import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/icons/ons_icons.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.rtl, Size size = const Size(390, 800)}) => MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(textDirection: dir, child: Center(child: child)),
    );

void main() {
  test('design system ships all 29 icons (the brief says 28; the file has 29) and each path parses to a non-empty Path', () {
    expect(kOnsIconPaths.length, 29);
    for (final name in kOnsIconPaths.keys) {
      final b = onsIconPath(name).getBounds();
      expect(b.width > 0 || b.height > 0, isTrue, reason: name); // 'minus' is a zero-height line
      expect(b.left, greaterThanOrEqualTo(-1), reason: name);
      expect(b.top, greaterThanOrEqualTo(-1), reason: name);
      expect(b.right, lessThanOrEqualTo(25), reason: name);
      expect(b.bottom, lessThanOrEqualTo(25), reason: name);
      expect(onsIconLabel(name, ar: true), isNotEmpty);
      expect(onsIconLabel(name, ar: false), isNotEmpty);
    }
  });

  test('icon-only whitelist is exactly the eight brief cases', () {
    expect(kIconOnlyAllowed, {'close', 'search', 'bell', 'camera', 'plus', 'minus', 'advance', 'back'});
    expect(kIconOnlyAllowed.length, 8);
    expect(kIconOnlyAllowed.every(kOnsIconPaths.containsKey), isTrue);
  });

  testWidgets('every icon renders at 2px and at the tablet 2.4px stroke', (t) async {
    for (final size in const [Size(390, 800), Size(820, 1180)]) {
      for (final name in kOnsIconPaths.keys) {
        await t.pumpWidget(_host(OnsIcon(name, size: 24), size: size));
        expect(t.takeException(), isNull, reason: '$name @ $size');
      }
    }
  });

  testWidgets('OnsIconOnly rejects names outside the whitelist and exposes its accessible name', (t) async {
    expect(() => OnsIconOnly('phone', semanticLabel: 'اتصال'), throwsAssertionError);
    final h = t.ensureSemantics();
    await t.pumpWidget(_host(OnsIconOnly('close', semanticLabel: 'إغلاق')));
    expect(find.bySemanticsLabel('إغلاق'), findsOneWidget);
    h.dispose();
  });

  testWidgets('OnsIconLabel shows a visible label and hides the glyph from semantics', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_host(const OnsIconLabel('phone', 'كلّمي الدعم')));
    expect(find.text('كلّمي الدعم'), findsOneWidget);
    expect(find.bySemanticsLabel('اتصال'), findsNothing);
    h.dispose();
  });

  testWidgets('arrows mirror with locale, other icons do not', (t) async {
    Future<bool> mirrored(String name, TextDirection d) async {
      await t.pumpWidget(_host(OnsIcon(name), dir: d));
      final cp = t.widget<CustomPaint>(find.descendant(of: find.byType(OnsIcon), matching: find.byType(CustomPaint)).first);
      return (cp.painter as dynamic).mirror as bool;
    }

    expect(await mirrored('advance', TextDirection.rtl), isTrue);
    expect(await mirrored('back', TextDirection.rtl), isTrue);
    expect(await mirrored('advance', TextDirection.ltr), isFalse);
    expect(await mirrored('clock', TextDirection.rtl), isFalse);
    expect(await mirrored('camera', TextDirection.rtl), isFalse);
  });
}
