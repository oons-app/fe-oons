import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/app/app.dart';
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

  _toastLayerOutsideNavigatorTests();
}

// Regression: OonsApp mounts AlertToastLayer in MaterialApp.builder, i.e. as a
// sibling of the Navigator, OUTSIDE its Overlay. The tests above host the
// banner inside `home:` (which has an Overlay) and so could never catch the
// "No Overlay widget found" crash from the banner's tooltip IconButton.
void _toastLayerOutsideNavigatorTests() {
  testWidgets('AlertToastLayer renders outside the Navigator overlay without throwing', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(alertToastProvider.notifier).state =
        const AlertToast(title: 'تم تأكيد الاشتراك', body: 'زيارتك الأولى السبت.', bookingId: 'b1');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => Stack(children: [child ?? const SizedBox.shrink(), const AlertToastLayer()]),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertToastBanner), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(container.read(alertToastProvider), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second toast replaces the first (new overlay per toast)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(alertToastProvider.notifier);
    n.state = const AlertToast(title: 'أولى', body: 'a');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => Stack(children: [child ?? const SizedBox.shrink(), const AlertToastLayer()]),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    expect(find.text('أولى'), findsOneWidget);
    n.state = const AlertToast(title: 'تانية', body: 'b');
    await tester.pump();
    expect(find.text('أولى'), findsNothing);
    expect(find.text('تانية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
