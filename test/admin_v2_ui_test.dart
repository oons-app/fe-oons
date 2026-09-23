import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/features/bookings/bookings_screen.dart';
import 'package:oons/admin_v2/features/customers/customers_screen.dart';
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

  testWidgets('V2GridTable shows skeleton rows while loading, not the empty text', (tester) async {
    await tester.pumpWidget(host(
      const V2GridTable(
        columns: [V2Col('A')],
        rows: [],
        emptyText: 'Nothing here yet',
        loading: true,
        skeletonRows: 4,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nothing here yet'), findsNothing);
    expect(find.byKey(const ValueKey('v2-skeleton-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('v2-skeleton-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('v2-skeleton-4')), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // let the repeat() settle for teardown
  });

  testWidgets('V2GridTable bulk mode renders a checkbox column, checked when selected', (tester) async {
    await tester.pumpWidget(host(
      V2GridTable(
        bulkMode: true,
        columns: const [V2Col('Ref', fixed: 120)],
        rows: [
          V2GridRow(cells: const [Text('ONS-1')], selectable: true, selected: false, onToggleSelect: () {}),
          V2GridRow(cells: const [Text('ONS-2')], selectable: true, selected: true, onToggleSelect: () {}),
        ],
      ),
    ));
    expect(find.text('ONS-1'), findsOneWidget);
    expect(find.text('ONS-2'), findsOneWidget);
    // Exactly the one selected row shows the check glyph.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('V2GridTable lays out in RTL without overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: opsV2Theme(arabic: true),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: V2GridTable(
              columns: const [V2Col('المرجع', fixed: 140), V2Col('العميلة'), V2Col('الحالة', fixed: 120)],
              rows: [
                V2GridRow(
                  cells: const [Text('ONS-1465-99'), Text('ندى'), Text('مؤكد')],
                  actions: [V2Btn(label: 'فتح', size: V2BtnSize.row, onPressed: () {})],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(find.text('ONS-1465-99'), findsOneWidget);
    expect(find.text('فتح'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V2Btn is inert while onPressed is null', (tester) async {
    await tester.pumpWidget(host(const V2Btn(label: 'Disabled', onPressed: null)));
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('Disabled'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('V2GridTable sortable header reports the column key', (tester) async {
    String? tapped;
    await tester.pumpWidget(host(
      V2GridTable(
        sortKey: 'createdAt',
        sortAsc: false,
        onSort: (key) => tapped = key,
        columns: const [
          V2Col('Customer', sortKey: 'name'),
          V2Col('Joined', fixed: 110, sortKey: 'createdAt'),
        ],
        rows: const [
          V2GridRow(cells: [Text('Nada'), Text('2026-09-23')]),
        ],
      ),
    ));
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    await tester.tap(find.text('Customer'));
    expect(tapped, 'name');
    await tester.tap(find.text('Joined'));
    expect(tapped, 'createdAt');
  });

  test('compareCustomerRows defaults to newest joined first', () {
    final older = {'firstName': 'A', 'createdAt': '2026-09-20T10:00:00Z', 'bookingCount': 3};
    final newer = {'firstName': 'B', 'createdAt': '2026-09-23T10:00:00Z', 'bookingCount': 0};
    final empty = {'firstName': 'C'};
    final rows = [older, empty, newer]..sort((a, b) => compareCustomerRows(a, b, 'createdAt', false, 'en'));
    expect(rows[0]['firstName'], 'B');
    expect(rows[1]['firstName'], 'A');
    expect(rows[2]['firstName'], 'C');
  });

  test('compareCustomerRows sorts bookings and names', () {
    final a = {'firstName': 'Zeinab', 'bookingCount': 1};
    final b = {'firstName': 'Amina', 'bookingCount': 4};
    expect(compareCustomerRows(a, b, 'bookingCount', false, 'en') > 0, isTrue);
    expect(compareCustomerRows(a, b, 'name', true, 'en') > 0, isTrue);
  });

  test('compareBookingRows defaults to newest slot first', () {
    final older = {'ref': 'ONS-1', 'slotStart': '2026-09-20T10:00:00Z', 'total': 500};
    final newer = {'ref': 'ONS-2', 'slotStart': '2026-09-23T10:00:00Z', 'total': 100};
    final empty = {'ref': 'ONS-3'};
    final rows = [older, empty, newer]..sort((a, b) => compareBookingRows(a, b, 'slotStart', false, 'en'));
    expect(rows[0]['ref'], 'ONS-2');
    expect(rows[1]['ref'], 'ONS-1');
    expect(rows[2]['ref'], 'ONS-3');
  });

  test('compareBookingRows sorts total and ref', () {
    final a = {'ref': 'ONS-9', 'total': 100};
    final b = {'ref': 'ONS-1', 'total': 900};
    expect(compareBookingRows(a, b, 'total', false, 'en') > 0, isTrue);
    expect(compareBookingRows(a, b, 'ref', true, 'en') > 0, isTrue);
  });
}
