import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/features/pro/pro_chrome.dart';

// Regression test for the "My services" screen's blank gap: ProSoftButton
// renders a Container(width: double.infinity) internally, so placing it as
// a bare (non-Expanded) child of a Row leaves it with unbounded width
// constraints. Flutter fails that layout pass, and since a Row lays out all
// its children in one pass, the sibling title disappeared along with it —
// a whole "Services" header row silently vanished, leaving a blank gap
// where a "+ Add service" button should have been.
void main() {
  testWidgets('services header Row renders its title and Add button without layout failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Services')),
              IntrinsicWidth(child: ProSoftButton(label: '+ Add service', onTap: () {})),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('+ Add service'), findsOneWidget);
  });

  test('digits() only Arabic-izes numbers when ar is true', () {
    expect(digits(90, ar: true), toArabicDigits(90));
    expect(digits(90, ar: false), '90');
    expect(digits(8, ar: false), '8');
  });
}
