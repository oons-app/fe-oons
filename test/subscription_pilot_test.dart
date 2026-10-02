import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/subscribe/subscription_ui.dart';

void main() {
  testWidgets('mode switch fits 390 and flips', (tester) async {
    var monthly = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: StatefulBuilder(
            builder: (c, set) => VisitModeSwitch(monthly: monthly, savePct: 16, onOnce: () => set(() => monthly = false), onMonthly: () => set(() => monthly = true)),
          ),
        ),
      ),
    ));
    expect(find.text('مرة واحدة'), findsOneWidget);
    expect(find.text('باقة شهرية'), findsOneWidget);
    expect(find.text('وفّري ١٦٪'), findsOneWidget);
    await tester.tap(find.text('باقة شهرية'));
    await tester.pump();
    expect(monthly, isTrue);
  });
}
