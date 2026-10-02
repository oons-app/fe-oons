import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/features/auth/auth_screens.dart';
import 'package:oons/features/client/client_chrome.dart';

/// The OTP screen types into the phone's own keyboard — no on-screen pad drawn
/// by the app.
void main() {
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('oons_otp_hive');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await Hive.openBox('cache');
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(locale: Locale('ar'), home: OtpScreen(phone: '01012345678')),
    ));
    await t.pump();
  }

  List<String> boxes(WidgetTester t) {
    final w = t.widget<ClientOtpBoxes>(find.byType(ClientOtpBoxes));
    return [for (var i = 0; i < 4; i++) i < w.code.length ? w.code[i] : ''];
  }

  testWidgets('no custom number pad; a number-keyboard field takes focus on open', (t) async {
    await open(t);
    expect(find.byType(ClientNumpad), findsNothing);
    expect(find.text('⌫'), findsNothing);
    final field = t.widget<TextField>(find.byKey(const Key('otp-input')));
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofillHints, contains('oneTimeCode'));
    expect(field.autofocus, isTrue);
    await t.pump(const Duration(seconds: 21)); // let the resend timer finish
  });

  testWidgets('typed digits fill the four boxes; Arabic digits are converted; extras ignored', (t) async {
    await open(t);
    await t.enterText(find.byKey(const Key('otp-input')), '٤١a');
    await t.pump();
    expect(boxes(t), ['4', '1', '', '']);
    await t.enterText(find.byKey(const Key('otp-input')), '4');
    await t.pump();
    expect(boxes(t), ['4', '', '', '']);
    await t.pump(const Duration(seconds: 21));
  });

  testWidgets('tapping the boxes brings the keyboard back', (t) async {
    await open(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('otp-input'))).focusNode!.hasFocus, isFalse);
    await t.tap(find.byKey(const Key('otp-input'))); // the field sits over the boxes, so a tap on them lands here
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('otp-input'))).focusNode!.hasFocus, isTrue);
    await t.pump(const Duration(seconds: 21));
  });
}
