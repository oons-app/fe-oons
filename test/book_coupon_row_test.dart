import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/client/client_chrome.dart';

// Regression test for the coupon row on the booking screen: ClientGhostButton
// renders a Container(width: double.infinity) internally, so placing it in a
// Row without giving its wrapper a concrete width leaves it with unbounded
// width constraints — Flutter fails that layout pass silently in release
// mode, and the whole Row (including the sibling TextField) disappears with
// it. This pins the fix: a SizedBox with both width and height set.
void main() {
  testWidgets('coupon Row renders its text field and Apply button without layout failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(hintText: 'Enter coupon code'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                height: 48,
                child: ClientGhostButton(label: 'Apply', onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });
}
