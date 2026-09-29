import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/alert_toast_banner.dart';
import 'package:oons/data/alerts.dart';

// AlertToastBanner is a full-screen Stack (dimmer + bottom card). In OonsApp
// it is mounted via Positioned.fill inside the routed Stack (see
// lib/app/app.dart `_ToastLayer`). This test pins that hosting shape and
// confirms dismiss via the close control / dimmer works without throwing.
void main() {
  final toast = AlertToast(title: 'تحديث على زيارة', body: 'Your visit was updated.', bookingId: 'abc123');

  Widget host({required VoidCallback onDismiss}) {
    return MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            Positioned.fill(
              child: AlertToastBanner(toast: toast, onDismiss: onDismiss),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('renders without crashing when hosted in Positioned.fill', (tester) async {
    await tester.pumpWidget(host(onDismiss: () {}));
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertToastBanner), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
  });

  testWidgets('dismiss button closes the banner', (tester) async {
    var gone = 0;
    await tester.pumpWidget(host(onDismiss: () => gone++));
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(gone, 1);
  });

  testWidgets('dimmer tap closes the banner', (tester) async {
    var gone = 0;
    await tester.pumpWidget(host(onDismiss: () => gone++));
    // Tap the top of the screen (dimmer), away from the bottom card.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(gone, 1);
  });
}
