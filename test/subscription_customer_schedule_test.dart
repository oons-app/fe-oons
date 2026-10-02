import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/subscribe/fee_explainer.dart';
import 'package:oons/features/subscribe/month_dates_copy.dart';
import 'package:oons/features/subscribe/month_dates_screen.dart';

class _FakeSession extends StateNotifier<SessionState> implements Session {
  _FakeSession() : super(const SessionState());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake API: today = Thu 2026-10-01, Friday off, Oct 8 full.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://fake.invalid');

  final posts = <String, List<Map<String, dynamic>>>{};
  bool failPlans = false;
  String quoteError = '';
  Set<String> noAfternoon = {};
  Set<String> takenMorning = {};

  static const slots = ['09:00', '14:00'];

  Map<String, dynamic> _availability() {
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i <= 48; i++) {
      final d = DateTime(2026, 10, 1 + i);
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final off = d.weekday == DateTime.friday;
      final full = k == '2026-10-08';
      days.add({
        'date': k,
        'bookable': !off && !full,
        'reason': off ? 'off' : full ? 'full' : '',
        'freeSlots': (off || full)
            ? <String>[]
            : [
                for (final s in slots)
                  if (!(s == '14:00' && noAfternoon.contains(k)) && !(s == '09:00' && takenMorning.contains(k))) s,
              ],
      });
    }
    return {'today': '2026-10-01', 'leadDays': 1, 'horizonDays': 41, 'cycleDays': 30, 'minGapDays': 2, 'slotHours': slots, 'days': days};
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/plans')) {
      if (failPlans) throw ApiException(0, 'offline');
      return {
        'feeRate': 0.1,
        'plans': [
          {
            'plan': {
              'id': 'plan1',
              'providerId': 'p1',
              'lines': [
                {'visitType': 'deep', 'quantity': 1, 'name': {'ar': 'تنظيف مميز'}},
                {'visitType': 'regular', 'quantity': 3, 'name': {'ar': 'تنظيف عادي'}},
              ],
            },
            'quote': {'paygPiastres': 300000, 'pricePiastres': 280000, 'feePiastres': 28000, 'totalPiastres': 308000, 'savingPiastres': 20000, 'savingPct': 7},
          }
        ],
      };
    }
    if (path == '/subscriptions/availability') return _availability();
    throw ApiException(404, 'Not found.');
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data, String? idem}) async {
    posts.putIfAbsent(path, () => []).add(Map<String, dynamic>.from(data as Map));
    if (path == '/subscriptions/quote') {
      return {
        'ok': quoteError.isEmpty,
        'error': quoteError,
        'message': '',
        'totals': {'pricePiastres': 280000, 'feePiastres': 28000, 'totalPiastres': 308000},
      };
    }
    return {};
  }
}

Future<_FakeApi> _pump(WidgetTester tester, {void Function(_FakeApi)? setup}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = _FakeApi();
  setup?.call(fake);
  subApi = fake;
  await tester.pumpWidget(ProviderScope(
    overrides: [sessionProvider.overrideWith((ref) => _FakeSession())],
    child: const MaterialApp(home: PlanScheduleScreen(providerId: 'p1', planId: 'plan1')),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  return fake;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, warnIfMissed: false);
  await _settle(tester);
}

bool _ctaEnabled(WidgetTester tester) {
  final w = tester.widget<InkWell>(find.byKey(const Key('schedule-cta')));
  return w.onTap != null;
}

void main() {
  tearDown(() => subApi = api);

  testWidgets('42-cell grid, step strip, CTA disabled until the server quote is valid', (tester) async {
    await _pump(tester);
    final cells = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('cell-'));
    expect(cells, findsNWidgets(42));
    expect(find.text('٢ مواعيد الشهر'), findsOneWidget);
    expect(find.text('أكتوبر – نوفمبر ٢٠٢٦'), findsOneWidget);
    expect(find.text('٣,٠٨٠ ج.م'), findsOneWidget);
    expect(find.text('ادفعي مقدّم · ٣,٠٨٠ ج.م'), findsOneWidget);
    expect(_ctaEnabled(tester), isTrue);
    // Four weekly visits Oct 3, 10, 17, 24 at 11 ص.
    expect(find.text('السبت ٣ أكتوبر'), findsOneWidget);
    expect(find.text('السبت ٢٤ أكتوبر'), findsOneWidget);
  });

  testWidgets('CTA stays disabled while the server says the schedule is invalid', (tester) async {
    await _pump(tester, setup: (f) => f.quoteError = 'اليوم ده محجوز بالكامل عندها.');
    expect(_ctaEnabled(tester), isFalse);
    expect(find.text('اليوم ده محجوز بالكامل عندها.'), findsOneWidget);
  });

  testWidgets('English server errors are shown as the generic Arabic message', (tester) async {
    await _pump(tester, setup: (f) => f.quoteError = 'Internal error');
    expect(find.text(MD.generic), findsOneWidget);
    expect(find.text('Internal error'), findsNothing);
  });

  testWidgets('rejected date is not selected and the exact message shows', (tester) async {
    await _pump(tester);
    await _tapKey(tester, 'tab-custom');
    await _tapKey(tester, 'cell-2026-10-09'); // Friday: provider day off
    expect(find.text('الجمعة إجازة المتخصصة.'), findsOneWidget);
    expect(find.text('الجمعة ٩ أكتوبر'), findsNothing);
    expect(find.text('السبت ١٠ أكتوبر'), findsOneWidget);
    await _tapKey(tester, 'cell-2026-10-08'); // full
    expect(find.text('اليوم ده محجوز بالكامل عندها.'), findsOneWidget);
    await _tapKey(tester, 'cell-2026-10-03'); // another visit's own cell -> select it, no error
    await _tapKey(tester, 'cell-2026-10-04'); // 1 day after visit 2? active=0 is Oct 3 itself
    expect(find.text('لازم يكون بين كل زيارتين يومين على الأقل.'), findsNothing);
  });

  testWidgets('custom mode: gap rule rejects, a valid day moves the visit and advances', (tester) async {
    final fake = await _pump(tester);
    await _tapKey(tester, 'tab-custom');
    await _tapKey(tester, 'visit-row-1'); // select visit 2 (Oct 10)
    await _tapKey(tester, 'cell-2026-10-04'); // 1 day after Oct 3
    expect(find.text('لازم يكون بين كل زيارتين يومين على الأقل.'), findsOneWidget);
    expect(find.text('السبت ١٠ أكتوبر'), findsOneWidget);
    await _tapKey(tester, 'cell-2026-10-12'); // Mon: ok
    expect(find.text('لازم يكون بين كل زيارتين يومين على الأقل.'), findsNothing);
    expect(find.text('الاتنين ١٢ أكتوبر'), findsOneWidget);
    // Server was asked about the new custom schedule.
    final last = fake.posts['/subscriptions/quote']!.last;
    expect(last['mode'], 'custom');
    expect((last['visits'] as List)[1]['date'], '2026-10-12');
  });

  testWidgets('time fallback shows an info (not error) line and keeps the moved visit active', (tester) async {
    await _pump(tester, setup: (f) => f.takenMorning = {'2026-10-12'});
    await _tapKey(tester, 'tab-custom');
    await _tapKey(tester, 'visit-row-1');
    await _tapKey(tester, 'cell-2026-10-12');
    expect(find.text('الصبح · من ٩ ص محجوزة في اليوم ده، فحطّيناها بعد الضهر · من ٢ م. تقدري تغيّريها تحت.'), findsOneWidget);
    expect(find.text('الفترة — زيارة ٢ · ١٢ أكتوبر'), findsOneWidget);
  });

  testWidgets('time chips: weekly = free on every date, custom = active date only', (tester) async {
    await _pump(tester, setup: (f) => f.noAfternoon = {'2026-10-10'});
    // weekly: the afternoon is missing on Oct 10 -> disabled everywhere
    expect(find.text('مش متاحة كل أسبوع'), findsOneWidget);
    final chip = tester.widget<InkWell>(find.byKey(const Key('chip-14:00')));
    expect(chip.onTap, isNull);
    final other = tester.widget<InkWell>(find.byKey(const Key('chip-09:00')));
    expect(other.onTap, isNotNull);
    expect(find.text('اخترتيها'), findsOneWidget);
    // custom, visit 1 (Oct 3): the afternoon is free there
    await _tapKey(tester, 'tab-custom');
    expect(tester.widget<InkWell>(find.byKey(const Key('chip-14:00'))).onTap, isNotNull);
    expect(find.text('مش متاحة كل أسبوع'), findsNothing);
    // visit 2 (Oct 10): the afternoon is taken -> «محجوزة»
    await _tapKey(tester, 'visit-row-1');
    expect(tester.widget<InkWell>(find.byKey(const Key('chip-14:00'))).onTap, isNull);
    expect(find.text('محجوزة'), findsOneWidget);
  });

  testWidgets('fee tip toggles in the bottom bar', (tester) async {
    await _pump(tester);
    expect(find.text('الـ١٠٪ دي بتروح فين؟'), findsNothing);
    await tester.tap(find.byType(FeeTipButton));
    await tester.pump();
    expect(find.text('الـ١٠٪ دي بتروح فين؟'), findsOneWidget);
    await tester.tap(find.byType(FeeTipButton));
    await tester.pump();
    expect(find.text('الـ١٠٪ دي بتروح فين؟'), findsNothing);
  });

  testWidgets('load failure shows a retryable empty state, not zeros', (tester) async {
    await _pump(tester, setup: (f) => f.failPlans = true);
    expect(find.byKey(const Key('schedule-cta')), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('ج.م'), findsNothing);
  });
}
