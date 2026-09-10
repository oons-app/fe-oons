import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/theme/theme.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';

void main() {
  group('toneForLabel — mirrors the prototype TONE_OF map', () {
    test('ok / plum / warn / bad / neutral / info buckets', () {
      expect(toneForLabel('Completed'), V2Tone.ok);
      expect(toneForLabel('Vetted'), V2Tone.ok);
      expect(toneForLabel('In progress'), V2Tone.plum);
      expect(toneForLabel('Confirmed'), V2Tone.plum);
      expect(toneForLabel('Pending payment'), V2Tone.warn);
      expect(toneForLabel('Awaiting docs'), V2Tone.warn);
      expect(toneForLabel('Cancelled by client'), V2Tone.bad);
      expect(toneForLabel('Undersupplied'), V2Tone.bad);
      expect(toneForLabel('Draft'), V2Tone.neutral);
      expect(toneForLabel('Settled'), V2Tone.neutral);
      expect(toneForLabel('Refunded'), V2Tone.info);
      expect(toneForLabel('Split'), V2Tone.info);
    });

    test('is case-insensitive and trims', () {
      expect(toneForLabel('  completed '), V2Tone.ok);
    });

    test('unknown labels fall back to neutral', () {
      expect(toneForLabel('Whatever'), V2Tone.neutral);
    });
  });

  Widget host(Widget child) => MaterialApp(
        theme: opsV2Theme(arabic: false),
        home: Scaffold(body: SizedBox(width: 1200, height: 800, child: child)),
      );

  testWidgets('V2GridTable renders headers, rows and per-row actions', (tester) async {
    var opened = 0;
    await tester.pumpWidget(host(
      V2GridTable(
        columns: const [V2Col('Ref', fixed: 120), V2Col('Customer')],
        rows: [
          V2GridRow(
            cells: const [Text('ONS-1'), Text('Nada')],
            actions: [V2Btn(label: 'Open', size: V2BtnSize.row, onPressed: () => opened++)],
          ),
        ],
      ),
    ));
    expect(find.text('Ref'), findsOneWidget);
    expect(find.text('ONS-1'), findsOneWidget);
    expect(find.text('Nada'), findsOneWidget);
    await tester.tap(find.text('Open'));
    expect(opened, 1);
  });

  testWidgets('V2GridTable shows the empty text when there are no rows', (tester) async {
    await tester.pumpWidget(host(
      const V2GridTable(columns: [V2Col('A')], rows: [], emptyText: 'Nothing here yet'),
    ));
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('V2Btn is inert while onPressed is null', (tester) async {
    await tester.pumpWidget(host(const V2Btn(label: 'Disabled', onPressed: null)));
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('Disabled'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, lessThan(1));
  });
}
