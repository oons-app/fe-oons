import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/features/invite/invite_model.dart';
import 'package:oons/features/invite/invite_screen.dart';
import 'package:oons/l10n/invite_copy.dart';

import 'pro_v2_fakes.dart';

class InviteRepo extends FakeProRepo {
  InviteRepo(this.info) : super(profile: providerJson());
  Map<String, dynamic> info;
  final redeemed = <String>[];
  Object? redeemError;

  @override
  Future<Map<String, dynamic>> referralInfo() async => info;

  @override
  Future<Map<String, dynamic>> redeemReferral(String code) async {
    if (redeemError != null) throw redeemError!;
    redeemed.add(code);
    info = {...info, 'canApplyCode': false, 'usedCode': true};
    return {'ok': true, 'percent': 50};
  }
}

Map<String, dynamic> infoJson({List<Map<String, dynamic>> rewards = const [], bool enabled = true, bool canApply = true, int percent = 50, int cap = 50000}) => {
      'enabled': enabled,
      'code': 'K7M2QX',
      'percent': percent,
      'maxDiscount': cap,
      'validDays': 90,
      'invited': 2,
      'completed': 1,
      'rewards': rewards,
      'usedCode': false,
      'canApplyCode': canApply,
    };

Future<void> open(WidgetTester t, InviteRepo r, {String lang = 'ar'}) async {
  phone(t, height: 2400);
  await t.pumpWidget(proHost(const InviteScreen(), repo: r, lang: lang));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(initHive);
  setUp(() => Hive.box('prefs').delete('inviteRef'));
  final ar = InviteCopy.ar;

  test('the model reads the API shape', () {
    final i = ReferralInfo.fromJson(infoJson(rewards: [
      {'code': 'REFAAAAAA', 'percent': 50, 'maxDiscount': 0, 'status': 'available', 'expiresAt': '2027-01-01T00:00:00Z'},
      {'code': 'REFBBBBBB', 'percent': 50, 'status': 'used'},
    ]));
    expect(i.code, 'K7M2QX');
    expect(i.rewards.length, 2);
    expect(i.rewards.first.available, isTrue);
    expect(i.rewards.last.available, isFalse);
    expect(i.canApplyCode, isTrue);
  });

  testWidgets('shows her code, how it works and the numbers from the server', (t) async {
    await open(t, InviteRepo(infoJson()));
    expect(find.byKey(const Key('invite-code')), findsOneWidget);
    expect(find.text('K7M2QX'), findsOneWidget);
    expect(find.text(ar['heroTitle']!.replaceAll('{p}', '٥٠')), findsOneWidget);
    expect(find.text(ar['step3']!.replaceAll('{p}', '٥٠')), findsOneWidget);
    expect(find.text(ar['rewardsEmpty']!), findsOneWidget);
    expect(find.text(ar['whatsapp']!), findsOneWidget);
    expect(find.text(ar['copy']!), findsOneWidget);
  });

  testWidgets('the percent follows the server, never a hard-coded 50', (t) async {
    await open(t, InviteRepo(infoJson(percent: 30)));
    expect(find.text(ar['heroTitle']!.replaceAll('{p}', '٣٠')), findsOneWidget);
    expect(find.text(ar['step3']!.replaceAll('{p}', '٣٠')), findsOneWidget);
  });

  testWidgets('earned coupons: available one is shown with its code, used one is dimmed', (t) async {
    await open(t, InviteRepo(infoJson(rewards: [
      {'code': 'REFAAAAAA', 'percent': 50, 'maxDiscount': 0, 'status': 'available', 'expiresAt': '2099-01-01T00:00:00Z'},
      {'code': 'REFBBBBBB', 'percent': 50, 'maxDiscount': 0, 'status': 'used'},
    ])));
    expect(find.text('REFAAAAAA'), findsOneWidget);
    expect(find.text('REFBBBBBB'), findsOneWidget);
    expect(find.text(ar['available']!), findsOneWidget);
    expect(find.text(ar['used']!), findsOneWidget);
    expect(find.text(ar['useAtCheckout']!), findsOneWidget);
    expect(find.text(ar['rewardsEmpty']!), findsNothing);
  });

  testWidgets('a new customer can add a friend\'s code once', (t) async {
    final r = InviteRepo(infoJson());
    await open(t, r);
    expect(find.text(ar['haveCode']!), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ABC234');
    await t.tap(find.text(ar['apply']!));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(r.redeemed, ['ABC234']);
    await t.pump(const Duration(seconds: 2));
    expect(find.text(ar['haveCode']!), findsNothing, reason: 'the entry field goes away once a code is used');
  });

  testWidgets('a refused code says why, in Arabic, and keeps the field', (t) async {
    final r = InviteRepo(infoJson())..redeemError = apiError('That invite code is not valid.', 404);
    await open(t, r);
    await t.enterText(find.byType(TextField), 'WRONG1');
    await t.tap(find.text(ar['apply']!));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('كود الدعوة غير صحيح.'), findsOneWidget);
    expect(find.text(ar['haveCode']!), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('already booked: no entry field', (t) async {
    await open(t, InviteRepo(infoJson(canApply: false)));
    expect(find.text(ar['haveCode']!), findsNothing);
  });

  testWidgets('switched off: says so and offers no code to share', (t) async {
    await open(t, InviteRepo(infoJson(enabled: false, canApply: false)));
    expect(find.text(ar['paused']!), findsOneWidget);
    expect(find.byKey(const Key('invite-code')), findsNothing);
  });

  testWidgets('the terms state the 500 EGP cap and that subscriptions are excluded', (t) async {
    await open(t, InviteRepo(infoJson(cap: 50000)));
    expect(find.textContaining('٥٠٠'), findsOneWidget);
    expect(find.textContaining(ar['terms']!.split('{cap}').last), findsOneWidget, reason: 'subscriptions are excluded');
  });

  testWidgets('English', (t) async {
    await open(t, InviteRepo(infoJson()), lang: 'en');
    expect(find.text('Invite a friend, get 50% off'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
  });
}
