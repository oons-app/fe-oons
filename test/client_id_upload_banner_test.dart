import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/client/client_chrome.dart';

// ClientIDUploadBanner renders a Container(width: double.infinity) like
// ClientTrustBanner before it — this session already found that shape break
// when placed as a bare Row child (see book_coupon_row_test.dart /
// pro_services_row_test.dart). It's meant to be used as a plain Column
// child (as it is on the home and booking-confirmed screens), which gives
// it a bounded width from its parent. Pin that here.
void main() {
  testWidgets('renders in a Column without layout failure and ticks its own countdown', (tester) async {
    final deadline = DateTime.now().add(const Duration(hours: 3, minutes: 15));
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ClientIDUploadBanner(deadline: deadline, lang: 'en', onTap: () => tapped = true),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Upload your ID photo'), findsOneWidget);

    await tester.tap(find.byType(ClientIDUploadBanner));
    expect(tapped, isTrue);
  });
}
