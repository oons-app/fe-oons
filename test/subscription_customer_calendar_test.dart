import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/subscribe/plan_calendar.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);
String k(DateTime x) => dateKey(x);

/// Prototype parity: today = Thu 2026-10-01, Friday off, three full days.
PlanCalendar proto({Map<String, Set<String>> taken = const {}, Set<String>? full}) => PlanCalendar.synthetic(
      today: d(2026, 10, 1),
      fullDates: full ?? {'2026-10-08', '2026-10-22', '2026-11-05'},
      takenSlots: taken,
    );

List<PlanVisit> four({String time = '09:00'}) => [
      PlanVisit(date: d(2026, 10, 3), time: time),
      PlanVisit(date: d(2026, 10, 10), time: time),
      PlanVisit(date: d(2026, 10, 17), time: time),
      PlanVisit(date: d(2026, 10, 24), time: time),
    ];

void main() {
  group('formatters', () {
    test('dLabel / dShort', () {
      expect(dLabel(d(2026, 10, 3)), 'السبت ٣ أكتوبر');
      expect(dShort(d(2026, 10, 3)), '٣ أكتوبر');
      expect(dLabel(d(2026, 11, 1)), 'الأحد ١ نوفمبر');
      expect(dLabel(d(2026, 10, 9)), 'الجمعة ٩ أكتوبر');
    });
    test('timeLabel', () {
      expect(timeLabel('09:00'), '٩ ص');
      expect(timeLabel('11:00'), '١١ ص');
      expect(timeLabel('13:00'), '١ م');
      expect(timeLabel('12:00'), '١٢ م');
      expect(timeLabel('00:00'), '١٢ ص');
      expect(timeLabel('09:30'), '٩:٣٠ ص');
    });
    test('arFmt groups with comma and Arabic digits', () {
      expect(arFmt(3080), '٣,٠٨٠');
      expect(arFmt(715), '٧١٥');
      expect(arFmt(1200), '١,٢٠٠');
    });
    test('month range label', () {
      expect(monthRangeLabel(d(2026, 10, 1), d(2026, 11, 6)), 'أكتوبر – نوفمبر ٢٠٢٦');
      expect(monthRangeLabel(d(2026, 10, 1), d(2026, 10, 30)), 'أكتوبر ٢٠٢٦');
      expect(monthRangeLabel(d(2026, 12, 20), d(2027, 1, 30)), 'ديسمبر ٢٠٢٦ – يناير ٢٠٢٧');
    });
  });

  group('bookable', () {
    final c = proto();
    test('lead, horizon, off, full', () {
      expect(c.bookable(d(2026, 10, 1)), isFalse, reason: 'today (lead 1)');
      expect(c.bookable(d(2026, 10, 2)), isFalse, reason: 'Friday');
      expect(c.bookable(d(2026, 10, 3)), isTrue);
      expect(c.bookable(d(2026, 10, 8)), isFalse, reason: 'full');
      expect(c.bookable(d(2026, 11, 11)), isTrue, reason: 'day 41');
      expect(c.bookable(d(2026, 11, 12)), isFalse, reason: 'day 42');
    });
  });

  group('weeklyFrom', () {
    test('plain: no shift', () {
      final r = proto().weeklyFrom(d(2026, 10, 3), 4, '09:00');
      expect(r.ok, isTrue);
      expect(r.visits.map((v) => k(v.date)), ['2026-10-03', '2026-10-10', '2026-10-17', '2026-10-24']);
      expect(r.visits.any((v) => v.shifted), isFalse);
      expect(r.visits.every((v) => v.time == '09:00'), isTrue);
    });
    test('Friday start shifts to Saturday and flags it', () {
      final r = proto().weeklyFrom(d(2026, 10, 2), 4, '09:00');
      expect(r.ok, isTrue);
      expect(r.visits.map((v) => k(v.date)), ['2026-10-03', '2026-10-10', '2026-10-17', '2026-10-24']);
      expect(r.visits.every((v) => v.shifted), isTrue);
    });
    test('full day shifts past the day off', () {
      final r = proto().weeklyFrom(d(2026, 10, 8), 4, '09:00');
      expect(r.visits.map((v) => k(v.date)), ['2026-10-10', '2026-10-15', '2026-10-24', '2026-10-29']);
      expect(r.visits.map((v) => v.shifted), [true, false, true, false]);
    });
    test('never two visits on the same day', () {
      // Oct 20 (Tue) visit 0; 27 visit 1 full -> shifts 28; ensure unique dates.
      final c = proto(full: {'2026-10-27'});
      final r = c.weeklyFrom(d(2026, 10, 20), 3, '09:00');
      expect(r.visits.map((v) => k(v.date)).toSet().length, 3);
      expect(r.visits[1].shifted, isTrue);
    });
    test('nothing bookable within 6 days -> error, no visits', () {
      final c = proto(full: {for (var i = 3; i <= 8; i++) '2026-10-0$i'});
      final r = c.weeklyFrom(d(2026, 10, 3), 4, '09:00');
      expect(r.ok, isFalse);
      expect(r.error, kMsgNoWeekly);
      expect(r.visits, isEmpty);
    });
    test('running past the horizon -> error', () {
      final r = proto().weeklyFrom(d(2026, 11, 8), 2, '09:00');
      expect(r.ok, isFalse);
    });
  });

  group('placeCustom rejections', () {
    final c = proto(taken: {
      '2026-10-12': {'09:00'},
    });
    test('off day: exact message, date not selected', () {
      final v = four();
      final r = c.placeCustom(v, 1, d(2026, 10, 9));
      expect(r.error, 'الجمعة إجازة المتخصصة.');
      expect(r.visits, v);
      expect(r.activeIndex, 1);
    });
    test('full day', () {
      expect(c.placeCustom(four(), 1, d(2026, 10, 8)).error, 'اليوم ده محجوز بالكامل عندها.');
    });
    test('generic not bookable (today and beyond horizon)', () {
      expect(c.placeCustom(four(), 1, d(2026, 10, 1)).error, 'اليوم ده مش متاح للحجز.');
      expect(c.placeCustom(four(), 1, d(2026, 11, 12)).error, 'اليوم ده مش متاح للحجز.');
    });
    test('same day as another visit', () {
      expect(c.placeCustom(four(), 1, d(2026, 10, 3)).error, 'فيه زيارة تانية في اليوم ده.');
    });
    test('gap: 1 day rejects, 2 days accepted', () {
      final r1 = c.placeCustom(four(), 1, d(2026, 10, 4));
      expect(r1.error, 'لازم يكون بين كل زيارتين يومين على الأقل.');
      final r2 = c.placeCustom(four(), 1, d(2026, 10, 5));
      expect(r2.ok, isTrue);
      expect(k(r2.visits[1].date), '2026-10-05');
    });
    test('span: 29 days accepted, 30 rejected', () {
      final ok = c.placeCustom(four(), 3, d(2026, 11, 1));
      expect(ok.ok, isTrue);
      final bad = c.placeCustom(four(), 3, d(2026, 11, 2));
      expect(bad.error, 'كل الزيارات لازم تكون جوّه ٣٠ يوم من أول زيارة.');
    });
    test('rejection order: off beats same-day/gap', () {
      final v = [PlanVisit(date: d(2026, 10, 3), time: '09:00'), PlanVisit(date: d(2026, 10, 10), time: '09:00')];
      // Oct 9 is a Friday AND one day from Oct 10.
      expect(c.placeCustom(v, 0, d(2026, 10, 9)).error, 'الجمعة إجازة المتخصصة.');
    });
  });

  group('placeCustom behaviour', () {
    final c = proto(taken: {
      '2026-10-12': {'09:00'},
    });
    test('time fallback keeps selection on the moved visit with the exact message', () {
      final r = c.placeCustom(four(), 1, d(2026, 10, 12));
      expect(r.ok, isTrue);
      expect(r.visits[1].time, '14:00', reason: 'the morning is taken, so only the afternoon is left');
      expect(r.message, 'الصبح · من ٩ ص محجوزة في اليوم ده، فحطّيناها بعد الضهر · من ٢ م. تقدري تغيّريها تحت.');
      expect(r.activeIndex, 1, reason: 'stays on the moved visit');
    });
    test('no fallback: selection advances to next visit', () {
      final r = c.placeCustom(four(), 0, d(2026, 10, 5));
      expect(r.message, isNull);
      expect(r.activeIndex, 1);
    });
    test('last visit: advance clamps', () {
      final r = c.placeCustom(four(), 3, d(2026, 10, 27));
      expect(r.activeIndex, 3);
    });
    test('re-sorts by date and advances relative to the new position', () {
      final r = c.placeCustom(four(), 0, d(2026, 10, 20));
      expect(r.visits.map((v) => k(v.date)), ['2026-10-10', '2026-10-17', '2026-10-20', '2026-10-24']);
      expect(r.activeIndex, 3, reason: 'moved visit is now index 2 -> advance to 3');
    });
    test('re-sort + fallback stays on the moved visit', () {
      final r = c.placeCustom(four(), 0, d(2026, 10, 12));
      // gap vs Oct 10 is 2 -> OK; sorted: 10, 12, 17, 24
      expect(r.visits.map((v) => k(v.date)), ['2026-10-10', '2026-10-12', '2026-10-17', '2026-10-24']);
      expect(r.visits[1].time, '14:00');
      expect(r.activeIndex, 1);
    });
  });

  group('time chips', () {
    final c = proto(taken: {
      '2026-10-10': {'14:00'},
    });
    test('a day offers exactly two periods, named by half of the day', () {
      final chips = c.timeChips(visits: four(), activeIndex: 0, weekly: false, selected: '09:00');
      expect(chips.map((x) => x.time), ['09:00', '14:00']);
      expect(chips.map((x) => x.label), ['الصبح · من ٩ ص', 'بعد الضهر · من ٢ م']);
    });
    test('weekly: free on EVERY date', () {
      final chips = c.timeChips(visits: four(), activeIndex: 0, weekly: true, selected: '09:00');
      final byTime = {for (final x in chips) x.time: x};
      expect(byTime['14:00']!.enabled, isFalse);
      expect(byTime['14:00']!.note, 'مش متاحة كل أسبوع');
      expect(byTime['09:00']!.selected, isTrue);
      expect(byTime['09:00']!.note, 'اخترتيها');
      expect(chips.length, 2);
    });
    test('custom: only the active visit date matters', () {
      final v = four();
      final first = c.timeChips(visits: v, activeIndex: 0, weekly: false, selected: '09:00');
      expect(first.firstWhere((x) => x.time == '14:00').enabled, isTrue);
      final second = c.timeChips(visits: v, activeIndex: 1, weekly: false, selected: '09:00');
      final t = second.firstWhere((x) => x.time == '14:00');
      expect(t.enabled, isFalse);
      expect(t.note, 'محجوزة');
    });
    test('commonSlot prefers the given one and falls back', () {
      final dates = four().map((v) => v.date);
      expect(c.commonSlot(dates, prefer: '14:00'), '09:00');
      expect(c.commonSlot(dates, prefer: '09:00'), '09:00');
    });
  });

  group('days the plan does not offer', () {
    PlanCalendar withClosedMonday() => PlanCalendar.fromJson({
          'today': '2026-10-01',
          'leadDays': 1,
          'horizonDays': 41,
          'slotHours': ['09:00', '14:00'],
          'days': [
            {'date': '2026-10-03', 'bookable': true, 'reason': '', 'freeSlots': ['09:00', '14:00']},
            {'date': '2026-10-05', 'bookable': false, 'reason': 'weekday', 'freeSlots': []},
          ],
        });
    test('tapping one says it is not one of the plan\'s days, and nothing is selected', () {
      final c = withClosedMonday();
      final v = four();
      final r = c.placeCustom(v, 1, d(2026, 10, 5));
      expect(r.error, 'اليوم ده مش من الأيام المتاحة في الباقة دي.');
      expect(r.visits, v);
    });
    test('its grid cell is closed, not selectable', () {
      final c = withClosedMonday();
      final cell = c.cells(visits: const [], activeIndex: 0, weekly: false).firstWhere((x) => k(x.date) == '2026-10-05');
      expect(cell.kind, CellKind.closed);
      expect(cell.tappable, isFalse);
    });
    test('periodLabel only names the two period starts', () {
      expect(periodLabel('09:00'), 'الصبح · من ٩ ص');
      expect(periodLabel('14:00'), 'بعد الضهر · من ٢ م');
      expect(periodLabel('11:00'), '١١ ص');
    });
  });

  group('cycle + grid', () {
    test('cycle bounds are start..start+29', () {
      final b = proto().cycleBounds(four());
      expect(k(b.start), '2026-10-03');
      expect(k(b.end), '2026-11-01');
      expect(dShort(b.start), '٣ أكتوبر');
      expect(dShort(b.end), '١ نوفمبر');
    });
    test('constants come from the response', () {
      final c = PlanCalendar.fromJson({
        'today': '2026-10-01',
        'leadDays': 2,
        'horizonDays': 30,
        'cycleDays': 28,
        'minGapDays': 3,
        'slotHours': ['09:00'],
        'days': [
          {'date': '2026-10-05', 'bookable': true, 'reason': '', 'freeSlots': ['09:00']},
          {'date': '2026-10-02', 'bookable': true, 'reason': '', 'freeSlots': ['09:00']},
        ],
      });
      expect(c.spanMax, 27);
      expect(c.minGapDays, 3);
      expect(c.bookable(d(2026, 10, 5)), isTrue);
      expect(c.bookable(d(2026, 10, 2)), isFalse, reason: 'lead 2');
      expect(c.bookable(d(2026, 10, 6)), isFalse, reason: 'unknown day');
    });
    test('grid is 42 Saturday-first cells (prototype: today Oct 1 -> Sep 26)', () {
      final c = proto();
      expect(k(c.gridStart), '2026-09-26');
      expect(c.gridStart.weekday, DateTime.saturday);
      final cells = c.cells(visits: four(), activeIndex: 0, weekly: true);
      expect(cells.length, 42);
      expect(k(cells.last.date), '2026-11-06');
      expect(c.monthLabel, 'أكتوبر – نوفمبر ٢٠٢٦');
    });
    test('grid for today=2026-10-29 starts Sat Oct 24 and crosses into later months', () {
      final c = PlanCalendar.synthetic(today: d(2026, 10, 29));
      expect(k(c.gridStart), '2026-10-24');
      expect(c.gridStart.weekday, DateTime.saturday);
      final cells = c.cells(visits: const [], activeIndex: 0, weekly: true);
      expect(cells.length, 42);
      expect(k(cells.last.date), '2026-12-04');
      expect(cells.map((x) => x.date.month).toSet(), {10, 11, 12});
      expect(cells.where((x) => x.isToday).single.date, d(2026, 10, 29));
    });
    test('grid start on a Saturday today and on a Sunday', () {
      expect(k(PlanCalendar.synthetic(today: d(2026, 10, 3)).gridStart), '2026-10-03');
      expect(k(PlanCalendar.synthetic(today: d(2026, 10, 4)).gridStart), '2026-10-03');
      expect(k(PlanCalendar.synthetic(today: d(2026, 10, 2)).gridStart), '2026-09-26');
    });
    test('cell classifier', () {
      final c = proto();
      CalCell at(List<CalCell> cs, DateTime x) => cs.firstWhere((e) => k(e.date) == k(x));
      final w = c.cells(visits: four(), activeIndex: 1, weekly: true);
      expect(at(w, d(2026, 9, 26)).kind, CellKind.past);
      expect(at(w, d(2026, 10, 1)).kind, CellKind.past);
      expect(at(w, d(2026, 10, 1)).isToday, isTrue);
      expect(at(w, d(2026, 10, 2)).kind, CellKind.off);
      expect(at(w, d(2026, 10, 3)).kind, CellKind.visit);
      expect(at(w, d(2026, 10, 3)).visitIndex, 0);
      expect(at(w, d(2026, 10, 8)).kind, CellKind.full);
      expect(at(w, d(2026, 10, 8)).tappable, isFalse);
      expect(at(w, d(2026, 11, 3)).kind, CellKind.inCycle, reason: 'weekly mode has no out-of-cycle');
      expect(w.any((e) => e.editing), isFalse, reason: 'ring only in custom mode');

      final cu = c.cells(visits: four(), activeIndex: 1, weekly: false);
      expect(at(cu, d(2026, 10, 6)).kind, CellKind.inCycle);
      expect(at(cu, d(2026, 11, 3)).kind, CellKind.outOfCycle);
      expect(at(cu, d(2026, 10, 10)).editing, isTrue);
      expect(cu.where((e) => e.editing).length, 1);
    });
    test('beyond-horizon day is unbookable (transparent)', () {
      final c = PlanCalendar.synthetic(today: d(2026, 10, 1));
      final cells = c.cells(visits: four(), activeIndex: 0, weekly: true);
      // grid ends Nov 6 (<= horizon) so shrink the horizon to see it.
      final short = PlanCalendar.synthetic(today: d(2026, 10, 1), horizonDays: 20);
      final x = short.cells(visits: four(), activeIndex: 0, weekly: true).firstWhere((e) => e.date == d(2026, 10, 28));
      expect(x.kind, CellKind.unbookable);
      expect(cells.length, 42);
    });
  });

  test('deepFirst orders deep visits first', () {
    expect(deepFirst(['regular', 'deep', 'regular']), ['deep', 'regular', 'regular']);
  });
}
