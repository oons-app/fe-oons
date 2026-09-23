import 'package:oons/core/format.dart';

/// Western ↔ Arabic-Indic digit helpers. Store/API = Western; display = Arabic-Indic.
const _western = '0123456789';
const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

String toArabicDigits(Object? value) {
  final s = '$value';
  final buf = StringBuffer();
  for (final cu in s.runes) {
    final ch = String.fromCharCode(cu);
    final i = _western.indexOf(ch);
    buf.write(i >= 0 ? _arabicIndic[i] : ch);
  }
  return buf.toString();
}

/// toArabicDigits itself has no language awareness — it converts whatever
/// you give it. Several call sites branch the surrounding unit/currency
/// text by `ar` (' EGP' vs 'ج.م') but call toArabicDigits unconditionally,
/// so an English-language screen still shows Arabic-Indic numerals mixed
/// into otherwise-English copy. Use this wherever `ar` is already in
/// scope instead of calling toArabicDigits directly.
String digits(Object? value, {required bool ar}) => ar ? toArabicDigits(value) : '$value';

String toWesternDigits(String input) {
  final buf = StringBuffer();
  for (final cu in input.runes) {
    final ch = String.fromCharCode(cu);
    final i = _arabicIndic.indexOf(ch);
    buf.write(i >= 0 ? _western[i] : ch);
  }
  return buf.toString();
}

/// Digits-only string; accepts Arabic-Indic or Western; strips leading zeros except "0".
String normalizeMoneyInput(String raw) {
  final w = toWesternDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  if (w.isEmpty) return '';
  final n = int.tryParse(w) ?? 0;
  return '$n';
}

/// Client-facing duration. Stored as minutes; shown as hours when ≥ 60.
String formatServiceDuration(int minutes, {required bool ar}) {
  if (minutes <= 0) return '';
  if (minutes < 60) {
    return ar ? '${digits(minutes, ar: true)} د' : '$minutes min';
  }
  final h = minutes ~/ 60;
  final rem = minutes % 60;
  final hoursLabel = _pluralHours(h, ar: ar);
  if (rem == 0) return hoursLabel;
  final minsLabel = ar ? '${digits(rem, ar: true)} د' : '$rem min';
  return ar ? '$hoursLabel و$minsLabel' : '$hoursLabel $minsLabel';
}

String _pluralHours(int n, {required bool ar}) {
  if (!ar) return n == 1 ? '1 hour' : '$n hours';
  if (n == 1) return 'ساعة';
  if (n == 2) return 'ساعتان';
  if (n >= 3 && n <= 10) return '${toArabicDigits(n)} ساعات';
  return '${toArabicDigits(n)} ساعة';
}

/// Hours field text for admin/pro editors (6, 1.5, 0.75).
String hoursInputFromMinutes(int minutes) {
  if (minutes <= 0) return '';
  if (minutes % 60 == 0) return '${minutes ~/ 60}';
  var s = (minutes / 60).toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.replaceFirst(RegExp(r'\.$'), '');
}

int minutesFromHoursInput(String raw) {
  final w = toWesternDigits(raw.trim()).replaceAll(',', '.');
  if (w.isEmpty) return 0;
  final h = double.tryParse(w);
  if (h == null) return 0;
  return (h * 60).round();
}

/// Egyptian feminine plural for خدمة / خدمات.
String pluralService(int n, {required bool ar}) {
  if (!ar) return n == 1 ? '1 service' : '$n services';
  if (n == 0) return '٠ خدمات';
  if (n == 1) return '١ خدمة';
  if (n == 2) return 'خدمتين';
  if (n >= 3 && n <= 10) return '${toArabicDigits(n)} خدمات';
  return '${toArabicDigits(n)} خدمة';
}

/// مُساعدة واحدة / مُساعدتين / ٣ مُساعدات / ١١+ مُساعدة
String pluralWorkers(int n, {required bool ar}) {
  if (!ar) {
    if (n == 1) return '1 assistant';
    if (n == 2) return '2 assistants';
    return '$n assistants';
  }
  if (n == 1) return 'مُساعدة واحدة';
  if (n == 2) return 'مُساعدتين';
  if (n >= 3 && n <= 10) return '${toArabicDigits(n)} مُساعدات';
  return '${toArabicDigits(n)} مُساعدة';
}

/// مهمة / مهام
/// Fixed home-cleaning package task count (matches server cleaning catalog).
const kCleaningCatalogTaskCount = 18;

String pluralTasks(int n, {required bool ar}) {
  if (!ar) return n == 1 ? '1 task' : '$n tasks';
  if (n == 0) return '٠ مهام';
  if (n == 1) return '١ مهمة';
  if (n == 2) return 'مهمتين';
  if (n >= 3 && n <= 10) return '${toArabicDigits(n)} مهام';
  return '${toArabicDigits(n)} مهمة';
}

/// شريحة واحدة / شريحتين / ٣ شرايح / ١١+ شريحة — cleaning size-tier count.
String pluralTiers(int n, {required bool ar}) {
  if (!ar) return n == 1 ? '1 tier' : '$n tiers';
  if (n == 0) return '٠ شرايح';
  if (n == 1) return 'شريحة واحدة';
  if (n == 2) return 'شريحتين';
  if (n >= 3 && n <= 10) return '${toArabicDigits(n)} شرايح';
  return '${toArabicDigits(n)} شريحة';
}

/// Net preview: commission on service price only; travel added after.
int netAfterCommission({
  required int priceEgp,
  required int travelEgp,
  required double commissionRate,
}) {
  final rate = commissionRate.clamp(0.0, 1.0);
  final netService = (priceEgp * (1 - rate)).round();
  return netService + travelEgp;
}

/// Suggested cleaning duration (minutes) from size × workers — editable in UI.
int suggestCleaningDurationMin({required int sizeFromSqm, required int workers}) {
  var base = 180;
  if (sizeFromSqm >= 155) {
    base = 300;
  } else if (sizeFromSqm >= 120) {
    base = 240;
  }
  return base;
}

String cleaningSizeMeta({
  required int fromSqm,
  int? toSqm,
  required int workers,
  required bool ar,
}) {
  final w = pluralWorkers(workers, ar: ar);
  if (ar) {
    if (toSqm == null) {
      return 'أكبر من ${toArabicDigits(fromSqm)} م² · $w';
    }
    return 'من ${toArabicDigits(fromSqm)} لـ ${toArabicDigits(toSqm)} م² · $w';
  }
  if (toSqm == null) return 'Over $fromSqm m² · $w';
  return '$fromSqm–$toSqm m² · $w';
}

bool cleaningSizesOverlap({
  required int aFrom,
  int? aTo,
  required int bFrom,
  int? bTo,
}) {
  final aHi = aTo ?? 1 << 30;
  final bHi = bTo ?? 1 << 30;
  return aFrom <= bHi && bFrom <= aHi;
}

/// Inclusive size match for cleaning packages. `toSqm == null` = no upper bound.
/// `fromSqm == 0` is a valid open lower bound ("up to Xm²"), not "unset".
bool cleaningSqmMatches({required int sqm, required int fromSqm, int? toSqm}) {
  if (fromSqm < 0 || sqm <= 0) return false;
  if (sqm < fromSqm) return false;
  if (toSqm == null) return true;
  return sqm <= toSqm;
}

/// Loc helper for cleaning task names from catalog JSON.
Loc locFromDynamic(dynamic v) {
  if (v is Map) return Loc.fromJson(v);
  final s = '$v';
  return Loc(s, s);
}
