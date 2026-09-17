import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/alert_toast_banner.dart';
import 'package:oons/data/alerts.dart';

// AlertToastBanner's dismiss IconButton sets `tooltip: 'Dismiss'`, which
// wraps it in a RawTooltip/OverlayPortal that needs an Overlay ancestor.
// In OonsApp's MaterialApp.router `builder`, the banner used to be mounted
// as a bare Positioned sibling of the routed page inside a Stack — outside
// the Navigator that owns the app's real Overlay — so it crashed with
// "No Overlay widget found" as soon as a toast was shown anywhere in the
// app. The fix wraps that subtree in its own Overlay
// (see OonsApp's `_ToastOverlayHost` in lib/app/app.dart). This test pins
// the same "Positioned sibling of a routed child, outside the app's own
// Overlay, sized only by top/left/right" shape and confirms it renders
// without throwing.
void main() {
  final toast = AlertToast(title: 'تحديث على زيارة', body: 'Your visit was updated.', bookingId: 'abc123');

  testWidgets('renders without crashing once the banner is hosted in its own Overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      canSizeOverlay: true,
                      builder: (context) => AlertToastBanner(toast: toast, onDismiss: () {}),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertToastBanner), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    expect(tester.takeException(), isNull);
  });
}
