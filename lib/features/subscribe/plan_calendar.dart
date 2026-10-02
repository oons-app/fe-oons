// Pure-Dart port of the S4 calendar logic from the cleaning prototype
// (cleaning_dc.js), driven by the server's availability response. The server
// stays the authority (it re-validates every quote/hold); this exists for
// instant tap feedback and for painting the grid.
//
// No Flutter imports on purpose: everything here is unit-tested.

const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// Western digits -> Arabic-Indic digits.
String arDigits(Object? v) =>
    '$v'.replaceAllMapped(RegExp(r'[0-9]'), (m) => _arDigits[int.parse(m[0]!)]);

/// `2750000` piastres is NOT handled here — pass whole EGP. Arabic digits with
/// a `,` thousands separator, as the customer prototype does (toLocaleString).
String arFmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return arDigits('${n < 0 ? '-' : ''}$b');
}

const kDaysFull = ['الأحد', 'الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت'];
const kMonthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// Day names indexed by Dart weekday (Mon=1 .. Sun=7).
String dayName(DateTime d) => kDaysFull[d.weekday % 7];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int diffDays(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String? k) {
  if (k == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(k);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// «السبت ٣ أكتوبر»
String dLabel(DateTime d) => '${dayName(d)} ${arDigits(d.day)} ${kMonthsAr[d.month - 1]}';

/// «٣ أكتوبر»
String dShort(DateTime d) => '${arDigits(d.day)} ${kMonthsAr[d.month - 1]}';

/// «09:00» -> «٩ ص», «13:00» -> «١ م», «12:00» -> «١٢ م», «09:30» -> «٩:٣٠ ص».
String timeLabel(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return arDigits(hhmm);
  final h = int.parse(m[1]!);
  final mi = int.parse(m[2]!);
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final suffix = h < 12 ? 'ص' : 'م';
  return '${arDigits(h12)}${mi == 0 ? '' : ':${arDigits(mi.toString().padLeft(2, '0'))}'} $suffix';
}

/// A visit is booked into a half of the day: «الصبح · من ٩ ص» (09:00) or
/// «بعد الضهر · من ٢ م» (14:00). Any other hour (an older booking) keeps its
/// plain clock label.
String periodLabel(String hhmm) {
  if (hhmm == '09:00') return 'الصبح · من ${timeLabel(hhmm)}';
  if (hhmm == '14:00') return 'بعد الضهر · من ${timeLabel(hhmm)}';
  return timeLabel(hhmm);
}

/// Compact form for a visit row: «الصبح · ٩ ص» / «بعد الضهر · ٢ م».
String periodShort(String hhmm) {
  if (hhmm == '09:00') return 'الصبح · ${timeLabel(hhmm)}';
  if (hhmm == '14:00') return 'بعد الضهر · ${timeLabel(hhmm)}';
  return timeLabel(hhmm);
}

/// Month label for the visible range, e.g. «أكتوبر – نوفمبر ٢٠٢٦».
String monthRangeLabel(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == to.month) {
    return '${kMonthsAr[from.month - 1]} ${arDigits(from.year)}';
  }
  if (from.year == to.year) {
    return '${kMonthsAr[from.month - 1]} – ${kMonthsAr[to.month - 1]} ${arDigits(from.year)}';
  }
  return '${kMonthsAr[from.month - 1]} ${arDigits(from.year)} – ${kMonthsAr[to.month - 1]} ${arDigits(to.year)}';
}

// ── Messages (exact prototype copy) ─────────────────────────────────────────

const kMsgFull = 'اليوم ده محجوز بالكامل عندها.';
const kMsgUnbookable = 'اليوم ده مش متاح للحجز.';
const kMsgNotOffered = 'اليوم ده مش من الأيام المتاحة في الباقة دي.';
const kMsgSameDay = 'فيه زيارة تانية في اليوم ده.';
const kMsgGap = 'لازم يكون بين كل زيارتين يومين على الأقل.';
const kMsgSpan = 'كل الزيارات لازم تكون جوّه ٣٠ يوم من أول زيارة.';
const kMsgNoWeekly = 'مفيش أيام متاحة قريبة من اليوم ده، جرّبي يوم تاني.';
const kMsgShifted = 'اتنقلت يوم عشان اليوم الأصلي مش متاح';
String msgOff(DateTime d) => '${dayName(d)} إجازة المتخصصة.';
String msgTimeFallback(String from, String to) =>
    '${periodLabel(from)} محجوزة في اليوم ده، فحطّيناها ${periodLabel(to)}. تقدري تغيّريها تحت.';
String msgWeeklyTimeFallback(String from, String to) =>
    '${periodLabel(from)} مش متاحة كل أسبوع، فحطّيناها ${periodLabel(to)}. تقدري تغيّريها تحت.';

// ── Availability model ──────────────────────────────────────────────────────

class DayInfo {
  const DayInfo({required this.date, required this.bookable, this.reason = '', this.freeSlots = const []});
  final DateTime date;
  final bool bookable;

  /// "" | "off" | "weekday" (not one of the plan's days) | "full" | "window"
  final String reason;
  final List<String> freeSlots;
}

/// Server availability for the calendar. Constants come from the response.
class PlanCalendar {
  PlanCalendar({
    required this.today,
    this.leadDays = 1,
    this.horizonDays = 41,
    this.cycleDays = 30,
    this.minGapDays = 2,
    this.slotHours = const [],
    Map<String, DayInfo> days = const {},
  }) : _days = days;

  final DateTime today;
  final int leadDays, horizonDays, cycleDays, minGapDays;
  final List<String> slotHours;
  final Map<String, DayInfo> _days;

  /// Last day of a cycle counted from its first visit (start .. start+29).
  int get spanMax => cycleDays - 1;

  factory PlanCalendar.fromJson(Map<String, dynamic> j) {
    final days = <String, DayInfo>{};
    for (final raw in (j['days'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final d = parseDateKey(raw['date']?.toString());
      if (d == null) continue;
      days[dateKey(d)] = DayInfo(
        date: d,
        bookable: raw['bookable'] == true,
        reason: (raw['reason'] ?? '').toString(),
        freeSlots: [for (final s in (raw['freeSlots'] as List? ?? const [])) s.toString()],
      );
    }
    int n(String k, int def) => (j[k] is num) ? (j[k] as num).toInt() : def;
    return PlanCalendar(
      today: parseDateKey(j['today']?.toString()) ?? dateOnly(DateTime.now()),
      leadDays: n('leadDays', 1),
      horizonDays: n('horizonDays', 41),
      cycleDays: n('cycleDays', 30),
      minGapDays: n('minGapDays', 2),
      slotHours: [for (final s in (j['slotHours'] as List? ?? const [])) s.toString()],
      days: days,
    );
  }

  /// Deterministic calendar (tests / prototype parity): [offWeekday] is a Dart
  /// weekday (default Friday), [fullDates] are `yyyy-mm-dd`, [takenSlots] maps
  /// a date key to already-booked slots.
  factory PlanCalendar.synthetic({
    required DateTime today,
    int offWeekday = DateTime.friday,
    Set<String> fullDates = const {},
    Map<String, Set<String>> takenSlots = const {},
    List<String> slotHours = const ['09:00', '14:00'],
    int leadDays = 1,
    int horizonDays = 41,
    int cycleDays = 30,
    int minGapDays = 2,
  }) {
    final days = <String, DayInfo>{};
    for (var i = 0; i <= horizonDays + 7; i++) {
      final d = addDays(today, i);
      final k = dateKey(d);
      final off = d.weekday == offWeekday;
      final full = fullDates.contains(k);
      final taken = takenSlots[k] ?? const <String>{};
      days[k] = DayInfo(
        date: d,
        bookable: !off && !full,
        reason: off ? 'off' : full ? 'full' : '',
        freeSlots: (off || full) ? const [] : [for (final s in slotHours) if (!taken.contains(s)) s],
      );
    }
    return PlanCalendar(
      today: dateOnly(today),
      leadDays: leadDays,
      horizonDays: horizonDays,
      cycleDays: cycleDays,
      minGapDays: minGapDays,
      slotHours: slotHours,
      days: days,
    );
  }

  DayInfo? info(DateTime d) => _days[dateKey(d)];

  bool inWindow(DateTime d) {
    final n = diffDays(today, d);
    return n >= leadDays && n <= horizonDays;
  }

  bool bookable(DateTime d) => inWindow(d) && (info(d)?.bookable ?? false);

  bool isPast(DateTime d) => diffDays(today, d) < leadDays;

  bool isOff(DateTime d) => info(d)?.reason == 'off';
  bool isFull(DateTime d) => info(d)?.reason == 'full';
  bool isClosed(DateTime d) => info(d)?.reason == 'weekday';

  List<String> freeSlots(DateTime d) => info(d)?.freeSlots ?? const [];

  /// Message for a tapped non-bookable day (prototype: off -> full -> generic).
  String rejectMessage(DateTime d) {
    if (isOff(d)) return msgOff(d);
    if (isClosed(d)) return kMsgNotOffered;
    if (isFull(d)) return kMsgFull;
    return kMsgUnbookable;
  }

  // ── Weekly ────────────────────────────────────────────────────────────────

  /// [count] weekly visits from [start]; a day that is not bookable (or is
  /// already taken by an earlier visit) shifts forward up to 6 days.
  WeeklyResult weeklyFrom(DateTime start, int count, String time) {
    final out = <PlanVisit>[];
    for (var i = 0; i < count; i++) {
      var d = addDays(dateOnly(start), 7 * i);
      var shifted = false;
      var guard = 0;
      bool bad(DateTime x) => !bookable(x) || out.any((v) => dateKey(v.date) == dateKey(x));
      while (bad(d) && guard++ < 6) {
        d = addDays(d, 1);
        shifted = true;
      }
      if (bad(d)) return const WeeklyResult([], kMsgNoWeekly);
      out.add(PlanVisit(date: d, time: time, shifted: shifted));
    }
    return WeeklyResult(out, null);
  }

  // ── Custom ────────────────────────────────────────────────────────────────

  /// Move visit [activeIndex] onto [date]. Rejections in prototype order:
  /// not bookable -> same day -> gap < min -> span > cycle-1. On rejection
  /// [PlaceResult.visits] is the unchanged input (the date is NOT selected).
  PlaceResult placeCustom(List<PlanVisit> visits, int activeIndex, DateTime date) {
    final d = dateOnly(date);
    PlaceResult reject(String m) => PlaceResult(visits, activeIndex, error: m);
    if (!bookable(d)) return reject(rejectMessage(d));
    final others = [
      for (var j = 0; j < visits.length; j++)
        if (j != activeIndex) visits[j].date,
    ];
    if (others.any((o) => dateKey(o) == dateKey(d))) return reject(kMsgSameDay);
    if (others.any((o) => diffDays(o, d).abs() < minGapDays)) return reject(kMsgGap);
    final all = [...others, d]..sort();
    if (diffDays(all.first, all.last) > spanMax) return reject(kMsgSpan);

    final cur = visits[activeIndex];
    var time = cur.time;
    String? message;
    final free = freeSlots(d);
    if (free.isNotEmpty && !free.contains(time)) {
      time = free.first;
      message = msgTimeFallback(cur.time, time);
    }
    final moved = [
      for (var j = 0; j < visits.length; j++)
        (j, j == activeIndex ? PlanVisit(date: d, time: time) : visits[j]),
    ]..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final newActive = moved.indexWhere((e) => e.$1 == activeIndex);
    final sorted = [for (final e in moved) e.$2];
    final next = message != null ? newActive : (newActive + 1 > sorted.length - 1 ? sorted.length - 1 : newActive + 1);
    return PlaceResult(sorted, next, message: message);
  }

  // ── Time chips ────────────────────────────────────────────────────────────

  /// Chip state per slot. Weekly: free on EVERY visit date; custom: free on the
  /// active visit's date.
  List<TimeChip> timeChips({
    required List<PlanVisit> visits,
    required int activeIndex,
    required bool weekly,
    required String selected,
  }) {
    if (visits.isEmpty) return const [];
    final dates = weekly ? [for (final v in visits) v.date] : [visits[(activeIndex < visits.length ? activeIndex : visits.length - 1)].date];
    return [
      for (final t in slotHours)
        () {
          final unavailable = dates.any((d) => !freeSlots(d).contains(t));
          final on = selected == t;
          return TimeChip(
            time: t,
            label: periodLabel(t),
            enabled: !unavailable,
            selected: on && !unavailable,
            note: unavailable ? (weekly ? 'مش متاحة كل أسبوع' : 'محجوزة') : on ? 'اخترتيها' : 'متاحة',
          );
        }(),
    ];
  }

  /// First slot free on every date in [dates], or null.
  String? commonSlot(Iterable<DateTime> dates, {String? prefer}) {
    bool ok(String t) => dates.every((d) => freeSlots(d).contains(t));
    if (prefer != null && ok(prefer)) return prefer;
    for (final t in slotHours) {
      if (ok(t)) return t;
    }
    return null;
  }

  // ── Cycle + grid ──────────────────────────────────────────────────────────

  /// Cycle bounds from the earliest visit: start .. start+cycleDays-1.
  ({DateTime start, DateTime end}) cycleBounds(List<PlanVisit> visits) {
    final start = visits.map((v) => v.date).reduce((a, b) => a.isBefore(b) ? a : b);
    return (start: start, end: addDays(start, spanMax));
  }

  /// Saturday on/before [today] (grid is Saturday-first).
  DateTime get gridStart => addDays(today, -((today.weekday + 1) % 7));

  static const gridCells = 42;

  DateTime get gridEnd => addDays(gridStart, gridCells - 1);

  /// «أكتوبر – نوفمبر ٢٠٢٦»: from today to the last grid cell (past leading
  /// cells of the previous month are not named, as in the prototype).
  String get monthLabel => monthRangeLabel(today, gridEnd);

  List<CalCell> cells({
    required List<PlanVisit> visits,
    required int activeIndex,
    required bool weekly,
    ({DateTime start, DateTime end})? cycle,
  }) {
    final byKey = {for (var i = 0; i < visits.length; i++) dateKey(visits[i].date): i};
    final activeKey = (visits.isNotEmpty && activeIndex < visits.length) ? dateKey(visits[activeIndex].date) : null;
    final cyc = cycle ?? (visits.isEmpty ? null : cycleBounds(visits));
    return [
      for (var i = 0; i < gridCells; i++)
        () {
          final d = addDays(gridStart, i);
          final k = dateKey(d);
          final vi = byKey[k];
          final inCycle = cyc != null && !d.isBefore(cyc.start) && !d.isAfter(cyc.end);
          CellKind kind;
          if (vi != null) {
            kind = CellKind.visit;
          } else if (isPast(d)) {
            kind = CellKind.past;
          } else if (isOff(d)) {
            kind = CellKind.off;
          } else if (isClosed(d)) {
            kind = CellKind.closed;
          } else if (isFull(d)) {
            kind = CellKind.full;
          } else if (!bookable(d)) {
            kind = CellKind.unbookable;
          } else if (!weekly && !inCycle) {
            kind = CellKind.outOfCycle;
          } else {
            kind = CellKind.inCycle;
          }
          return CalCell(
            date: d,
            kind: kind,
            visitIndex: vi,
            isToday: k == dateKey(today),
            editing: !weekly && vi != null && k == activeKey,
            tappable: vi != null || bookable(d),
          );
        }(),
    ];
  }
}

// ── Value types ─────────────────────────────────────────────────────────────

class PlanVisit {
  const PlanVisit({required this.date, required this.time, this.shifted = false});
  final DateTime date;

  /// `HH:MM` 24h.
  final String time;
  final bool shifted;

  PlanVisit copyWith({DateTime? date, String? time, bool? shifted}) =>
      PlanVisit(date: date ?? this.date, time: time ?? this.time, shifted: shifted ?? this.shifted);

  Map<String, dynamic> toJson() => {'date': dateKey(date), 'time': time};

  @override
  bool operator ==(Object other) =>
      other is PlanVisit && dateKey(other.date) == dateKey(date) && other.time == time && other.shifted == shifted;
  @override
  int get hashCode => Object.hash(dateKey(date), time, shifted);
  @override
  String toString() => 'PlanVisit(${dateKey(date)} $time${shifted ? ' shifted' : ''})';
}

class WeeklyResult {
  const WeeklyResult(this.visits, this.error);
  final List<PlanVisit> visits;
  final String? error;
  bool get ok => error == null;
}

class PlaceResult {
  const PlaceResult(this.visits, this.activeIndex, {this.error, this.message});
  final List<PlanVisit> visits;
  final int activeIndex;

  /// Blocking rejection (terracotta). When set, [visits] is unchanged.
  final String? error;

  /// Informational (time fallback).
  final String? message;
  bool get ok => error == null;
}

class TimeChip {
  const TimeChip({required this.time, required this.label, required this.enabled, required this.selected, required this.note});
  final String time, label, note;
  final bool enabled, selected;
}

enum CellKind { visit, past, off, closed, full, unbookable, outOfCycle, inCycle }

class CalCell {
  const CalCell({
    required this.date,
    required this.kind,
    required this.visitIndex,
    required this.isToday,
    required this.editing,
    required this.tappable,
  });
  final DateTime date;
  final CellKind kind;
  final int? visitIndex;
  final bool isToday, editing, tappable;
}

/// Visit order for a plan: deep visits first (prototype `planMeta`).
/// [types] is the per-visit list, e.g. ['regular','deep','regular'].
List<String> deepFirst(List<String> types) {
  final deep = types.where((t) => t == 'deep');
  final rest = types.where((t) => t != 'deep');
  return [...deep, ...rest];
}
