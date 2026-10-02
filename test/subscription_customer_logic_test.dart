import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/my_plan_logic.dart';
import 'package:oons/features/subscribe/plan_models.dart';

PlanLine _l(String type, int n, {String name = '', int reg = 0, int sub = 0}) =>
    PlanLine(visitType: type, quantity: n, name: name, regularPiastres: reg, subPiastres: sub);

void main() {
  const deepName = 'تنظيف مميز', regName = 'تنظيف عادي';

  group('plan title generator', () {
    test('1 deep + 3 regular: deep first, full name then short', () {
      expect(planTitleFor([_l('regular', 3, name: regName), _l('deep', 1, name: deepName)]), '١ تنظيف مميز + ٣ عادي في الشهر');
    });
    test('2 + 2', () {
      expect(planTitleFor([_l('deep', 2, name: deepName), _l('regular', 2, name: regName)]), '٢ تنظيف مميز + ٢ عادي في الشهر');
    });
    test('4 regular only', () {
      expect(planTitleFor([_l('regular', 4, name: regName)]), '٤ تنظيف عادي في الشهر');
    });
    test('single line and names from data', () {
      expect(planTitleFor([_l('deep', 1, name: 'تنظيف شامل')]), '١ تنظيف شامل في الشهر');
      expect(planTitleFor([_l('deep', 1, name: deepName), _l('regular', 2, name: 'تنضيف المطبخ')]), '١ تنظيف مميز + ٢ تنضيف المطبخ في الشهر');
    });
    test('zero-quantity lines are dropped, no lines gives empty', () {
      expect(planTitleFor([_l('deep', 0), _l('regular', 2, name: regName)]), '٢ تنظيف عادي في الشهر');
      expect(planTitleFor(const []), '');
    });
    test('visit types are deep first', () {
      expect(visitTypesFor([_l('regular', 2), _l('deep', 1)]), ['deep', 'regular', 'regular']);
    });
  });

  group('pricing / fee / saving display', () {
    test('fee is whole-EGP half-up of 10% (server rule)', () {
      expect(feePiastresFor(71500), 7200); // 71.5 -> 72
      expect(feePiastresFor(280000), 28000);
      expect(feePiastresFor(240000), 24000);
      expect(feePiastresFor(0), 0);
    });
    test('money text uses Arabic-Indic digits with comma grouping', () {
      expect(egpText(120000), '١,٢٠٠');
      expect(egpUnit(71500), '٧١٥ ج.م');
      expect(arNum(1234567), '١,٢٣٤,٥٦٧');
      expect(arNum(0), '٠');
    });
    test('PlanData prefers server totals and hides save when <= 0', () {
      final p = PlanData.fromRow({
        'plan': {'id': 'p1', 'providerId': 'x', 'recommended': true, 'lines': [
          {'visitType': 'deep', 'quantity': 1, 'name': {'ar': deepName}, 'regularPriceSnapshotPiastres': 120000, 'subPricePiastres': 110000},
          {'visitType': 'regular', 'quantity': 3, 'name': {'ar': regName}, 'regularPriceSnapshotPiastres': 71500, 'subPricePiastres': 60000},
        ]},
        'quote': {'paygPiastres': 334500, 'pricePiastres': 290000, 'feePiastres': 29000, 'totalPiastres': 319000, 'savingPiastres': 44500, 'savingPct': 13},
      });
      expect(p.title, '١ تنظيف مميز + ٣ عادي في الشهر');
      expect(p.totalPiastres, 319000);
      expect(p.showSave, isTrue);
      expect(p.savePct, 13);
      final none = PlanData.fromRow({
        'plan': {'id': 'p2', 'lines': [{'visitType': 'regular', 'quantity': 1, 'name': {'ar': regName}}]},
        'quote': {'paygPiastres': 50000, 'pricePiastres': 55000, 'savingPiastres': -5000},
      });
      expect(none.showSave, isFalse);
      expect(none.feePiastres, 5500); // computed whole-EGP half-up when absent
      expect(none.totalPiastres, 60500);
    });
    test('max save and pct across plans', () {
      PlanData mk(int save, int pct) => PlanData(id: 'a', providerId: 'p', lines: const [], recommended: false, paygPiastres: 0, pricePiastres: 0, feePiastres: 0, totalPiastres: 0, savePiastres: save, savePct: pct);
      expect(maxSavePiastres([mk(100, 5), mk(900, 12), mk(-4, 0)]), 900);
      expect(maxSavePct([mk(100, 5), mk(900, 12)]), 12);
      expect(maxSavePiastres([mk(-1, 0)]), 0);
    });
  });

  group('dates and slots', () {
    test('date labels', () {
      expect(dateLabelAr(DateTime(2026, 10, 3)), 'السبت ٣ أكتوبر');
      expect(dateShortAr(DateTime(2026, 10, 30)), '٣٠ أكتوبر');
      expect(slotLabelAr('11:00'), '١١ ص');
      expect(slotLabelAr('15:00'), '٣ م');
      expect(slotLabelAr('12:30'), '١٢:٣٠ م');
    });
  });

  group('my plan model', () {
    final resp = {
      'subscription': {'id': 's1', 'status': 'active', 'title': '١ تنظيف مميز + ٣ عادي في الشهر', 'providerName': 'ندى', 'used': 1, 'minimum': 4, 'makeupDeadline': '2026-10-28',
        'planSnapshot': {'lines': [{'visitType': 'deep', 'quantity': 1, 'name': {'ar': deepName}}, {'visitType': 'regular', 'quantity': 3, 'name': {'ar': regName}}]}},
      'cycle': {'id': 'c1', 'startsOn': '2026-10-03T00:00:00+03:00', 'endsOn': '2026-11-01', 'status': 'paid'},
      'visits': [
        {'id': 'v1', 'status': 'done', 'type': 'deep', 'date': '2026-10-03', 'time': '11:00', 'timeLabel': '١١ ص'},
        {'id': 'v2', 'status': 'skipped', 'type': 'regular', 'date': '2026-10-10', 'time': '11:00'},
        {'id': 'v3', 'status': 'booked', 'type': 'regular', 'date': '2026-10-17', 'time': '11:00', 'canSkip': true},
        {'id': 'v4', 'status': 'needs_date', 'type': 'regular', 'date': '', 'isMakeup': true, 'makeupReason': 'skipped'},
      ],
    };
    test('tags, make-up line, next visit and counters', () {
      final p = MyPlan.fromResponse(Map<String, dynamic>.from(resp));
      expect(p.visits.map((v) => visitTagLabel(v.tag)).toList(), ['اتعملت', 'اتخطّتيها', 'جاية', 'محتاجة يوم']);
      expect(p.visits.last.typeLine, 'تنظيف عادي · بدل اللي اتخطّت');
      expect(p.nextVisit!.id, 'v3');
      expect(p.nextVisit!.when, 'السبت ١٧ أكتوبر · ١١ ص');
      expect(p.usedLabel, '١ من ٤ زيارات اتعملت الدورة دي');
      expect(p.cycleLong, 'الدورة: ٣ أكتوبر لحد ١ نوفمبر');
      expect(p.pendingMakeup!.id, 'v4');
      expect(p.skippable!.id, 'v3');
    });
    test('server visit statuses booked|scheduled|confirmed all count as upcoming', () {
      for (final s in ['booked', 'scheduled', 'confirmed']) {
        expect(isUpcomingStatus(s), isTrue);
        expect(visitTagFor(s), VisitTag.next);
      }
      expect(isUpcomingStatus('done'), isFalse);
    });
  });

  test('scope rows: differing tasks first, falls back to prototype rows', () {
    final rows = scopeRowsFor(deepExcluded: const [], regularExcluded: const ['b', 'c'], taskNames: const {'a': 'أ', 'b': 'ب', 'c': 'ج'});
    expect(rows.map((r) => r.task).toList(), ['ب', 'ج', 'أ']);
    expect(rows.first.regular, isFalse);
    expect(scopeRowsFor(deepExcluded: const [], regularExcluded: const [], taskNames: const {'a': 'أ'}).length, 5);
  });
}
