import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/system/progress.dart';

/// The "added X · undo" toast: must not cover the bottom action bar and must go
/// away with a swipe in any direction, not only down.
void main() {
  var undone = 0;

  Future<void> open(WidgetTester t) async {
    undone = 0;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => showUndoSnack(context, message: 'أُضيفت تنظيف عادي', undoLabel: 'تراجع', onUndo: () => undone++),
                child: const Text('add'),
              ),
              const SizedBox(height: 60, child: Center(child: Text('NEXT'))),
            ],
          ),
        ),
      ),
    ));
    await t.tap(find.text('add'));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
  }

  testWidgets('sits at the top, clear of the bottom action bar', (t) async {
    await open(t);
    final r = t.getRect(find.text('أُضيفت تنظيف عادي'));
    expect(r.center.dy, lessThan(844 / 2));
    expect(t.getRect(find.text('NEXT')).bottom, greaterThan(800));
    await t.pumpAndSettle(const Duration(seconds: 6));
  });

  for (final e in {
    'up': const Offset(0, -160),
    'down': const Offset(0, 160),
    'left': const Offset(-260, 0),
    'right': const Offset(260, 0),
  }.entries) {
    testWidgets('swipe ${e.key} dismisses it', (t) async {
      await open(t);
      expect(find.text('أُضيفت تنظيف عادي'), findsOneWidget);
      await t.fling(find.text('أُضيفت تنظيف عادي'), e.value, 1200);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('أُضيفت تنظيف عادي'), findsNothing);
      expect(undone, 0, reason: 'dismissing is not undoing');
    });
  }

  testWidgets('تراجع undoes and closes; a second add replaces the first', (t) async {
    await open(t);
    await t.tap(find.text('add'));
    await t.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('أُضيفت تنظيف عادي'), findsOneWidget);
    await t.tap(find.text('تراجع'));
    await t.pumpAndSettle(const Duration(milliseconds: 400));
    expect(undone, 1);
    expect(find.text('أُضيفت تنظيف عادي'), findsNothing);
  });

  testWidgets('goes away by itself', (t) async {
    await open(t);
    await t.pumpAndSettle(const Duration(seconds: 6));
    expect(find.text('أُضيفت تنظيف عادي'), findsNothing);
  });
}
