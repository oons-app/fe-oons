import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/pro_screens.dart';
import 'package:oons/l10n/copy.dart';

Map<String, dynamic> _cat(String id, String en, String ar) => {
      'id': id,
      'name': {'en': en, 'ar': ar},
      'slug': id,
    };

class _FakeRepo extends Repo {
  final asked = <String>[];
  @override
  Future<List<Map<String, dynamic>>> categories({
    String? vertical,
    bool includeLocked = true,
    bool activeOnly = false,
    String? area,
    String? parent,
  }) async {
    asked.add('$vertical');
    switch (vertical) {
      case 'beauty':
        return [_cat('hair', 'Hair', 'شعر'), _cat('nails', 'Nails', 'أظافر')];
      case 'cleaning':
        return [_cat('deep', 'Deep Cleaning', 'تنظيف عميق')];
      default:
        return [];
    }
  }
}

/// Step 2 of provider sign-up ("your work"): several categories, specialties
/// under each, and areas she has to choose herself.
void main() {
  late Map p;
  late Map svc;
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('oons_reg_hive');
    Hive.init(dir.path);
    await Hive.openBox('prefs');
    await Hive.openBox('cache');
    p = Copy.of('ar')['pro'] as Map;
    svc = Copy.of('ar')['svc'] as Map;
  });

  Future<_FakeRepo> open(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final repo = _FakeRepo();
    await t.pumpWidget(ProviderScope(
      overrides: [repoProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: ProRegisterScreen(phone: '01012345678', code: '4192', initialStep: 1),
      ),
    ));
    await t.pump();
    return repo;
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text);
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> next(WidgetTester t) => tapText(t, '${p['next']}');

  testWidgets('nothing is pre-picked: she must choose a category, specialties and areas', (t) async {
    await open(t);
    expect(find.text('${p['specialtiesIn']} ${svc['beauty']}'.toUpperCase()), findsNothing);
    await next(t);
    expect(find.text('${p['needServices']}'), findsOneWidget);
  });

  testWidgets('several categories, each needing a specialty, then an area', (t) async {
    final repo = await open(t);

    await tapText(t, '${svc['beauty']}');
    expect(repo.asked, ['beauty']);
    expect(find.text('شعر'), findsOneWidget);
    expect(find.text('أظافر'), findsOneWidget);

    await next(t);
    expect(find.text('${p['needSpecialties']}'), findsOneWidget);

    await tapText(t, 'شعر');
    await tapText(t, 'أظافر'); // more than one specialty in a category

    // A second category brings its own specialties — and its own requirement.
    await tapText(t, '${svc['cleaning']}');
    expect(find.text('تنظيف عميق'), findsOneWidget);
    expect(find.text('شعر'), findsOneWidget, reason: 'first category keeps its picks on screen');
    await next(t);
    expect(find.text('${p['needSpecialties']}'), findsOneWidget);

    await tapText(t, 'تنظيف عميق');
    await next(t);
    expect(find.text('${p['needAreas']}'), findsOneWidget, reason: 'no area is chosen for her');

    await tapText(t, 'مدينتي');
    await next(t);
    expect(find.text('${p['needAreas']}'), findsNothing);
    expect(find.textContaining('${p['stepPay']}'), findsOneWidget, reason: 'moved on to the payout step');
  });

  testWidgets('unticking a category drops its specialties', (t) async {
    await open(t);
    await tapText(t, '${svc['beauty']}');
    await tapText(t, 'شعر');
    await tapText(t, '${svc['cleaning']}');
    await tapText(t, 'تنظيف عميق');

    // Remove beauty (and with it the hair pick); cleaning alone now satisfies step 2.
    await tapText(t, '${svc['beauty']}');
    expect(find.text('شعر'), findsNothing);
    await next(t);
    expect(find.text('${p['needSpecialties']}'), findsNothing);
    expect(find.text('${p['needAreas']}'), findsOneWidget);
  });
}
