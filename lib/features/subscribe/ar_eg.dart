import 'package:flutter/services.dart';
import 'package:oons/core/pro_format.dart';

/// Provider-side subscription copy, tokens and pure helpers. Arabic for the
/// plan wizard / visit operations lives here (Egyptian dialect, feminine
/// imperative, Arabic-Indic numerals). Everything below the tokens is pure so it
/// can be unit tested without a widget tree.
class Wiz {
  static const plum = Color(0xFF4A1E3C);
  static const gold = Color(0xFFC9A97E);
  static const cream = Color(0xFFF7F3EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241820);
  static const plumTint = Color(0xFFEDE4EA);
  static const goldTint = Color(0xFFF3EADB);
  static const goldInk = Color(0xFF5E4320);
  static const goldNote = Color(0xFF7A5A2E);
  static const goldBorder = Color(0xFFE3CFAE);
  static const border = Color(0xFFE4DBD3);
  static const muted = Color(0xFF8A7C84);
  static const soft = Color(0xFF6C5F66);
  static const body = Color(0xFF4E434A);
  static const successBg = Color(0xFFE6F0E8);
  static const successFg = Color(0xFF2F5D3A);
  static const pendingBg = Color(0xFFFBF1E2);
  static const pendingFg = Color(0xFF8A6420);
  static const danger = Color(0xFF9B3B3B);
  static const dangerBg = Color(0xFFFDF4F4);

  // Template-only greys (wizard prototype).
  static const tile = Color(0xFFFBF8F5);
  static const chip = Color(0xFFF2ECE6);
  static const disabled = Color(0xFFDCD2CB);
  static const inputBorder = Color(0xFFE0D6CE);
  static const hair = Color(0xFFF0E9E2);
  static const faint = Color(0xFFC9BCC4);
  static const sand = Color(0xFFEDE7E0);
  static const divider = Color(0xFFE9E1DA);
  static const ghost = Color(0xFFA6999F);

  static const text = 'IBMPlexSansArabic';
  static const mono = 'IBMPlexMono';
}

// ---------------------------------------------------------------------------
// Numbers and digits
// ---------------------------------------------------------------------------

/// Arabic-Indic digits with the `٬` thousands separator (`٢٬٧٥٠`). The one
/// number helper for the provider subscription surfaces.
String arGrouped(int n) {
  final neg = n < 0;
  final s = (neg ? -n : n).toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final out = toArabicDigits(buf.toString()).replaceAll(',', '٬');
  return neg ? '-$out' : out;
}

/// Arabic-Indic digits, no grouping (counts, dates).
String arNum(int n) => toArabicDigits(n);

/// Value of one digit character: Latin 0-9, Arabic-Indic ٠-٩ or Persian ۰-۹.
int? digitValue(String ch) {
  if (ch.isEmpty) return null;
  final c = ch.codeUnitAt(0);
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x660 && c <= 0x669) return c - 0x660;
  if (c >= 0x6F0 && c <= 0x6F9) return c - 0x6F0;
  return null;
}

const kPriceMaxDigits = 5;

/// Digits only, Latin, capped. `"٤٥٠"`, `"450"`, `"4a5.0"` all normalise to a
/// digit string. Typing `0` stays `"0"` (the price row then reads empty/red).
String normalizeDigits(String raw, {int maxLen = kPriceMaxDigits}) {
  final out = StringBuffer();
  for (final r in raw.runes) {
    final d = digitValue(String.fromCharCode(r));
    if (d == null) continue;
    if (out.length >= maxLen) break;
    out.write(d);
  }
  return out.toString();
}

/// Price typed into the step-2 row. Empty / zero ⇒ 0 (invalid).
int priceFromRaw(String raw) => int.tryParse(normalizeDigits(raw)) ?? 0;

/// Keeps the field in Arabic-Indic digits, strips anything else and caps the
/// length, while keeping the caret where the user put it.
class ArDigitsFormatter extends TextInputFormatter {
  const ArDigitsFormatter({this.maxLen = kPriceMaxDigits});
  final int maxLen;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final caret = newValue.selection.isValid ? newValue.selection.extentOffset : raw.length;
    final out = StringBuffer();
    var newCaret = 0;
    var i = 0;
    for (final r in raw.runes) {
      final ch = String.fromCharCode(r);
      final d = digitValue(ch);
      if (d != null && out.length < maxLen) {
        out.write(toArabicDigits(d));
        if (i < caret) newCaret++;
      }
      i += ch.length;
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: newCaret.clamp(0, text.length)),
    );
  }
}

// ---------------------------------------------------------------------------
// Plurals (wizard_dc.js: visits / plansCount / bCount)
// ---------------------------------------------------------------------------

String visitsPhrase(int n) {
  if (n == 1) return 'زيارة واحدة';
  if (n == 2) return 'زيارتين';
  if (n <= 10) return '${toArabicDigits(n)} زيارات';
  return '${toArabicDigits(n)} زيارة';
}

String plansPhrase(int n) {
  if (n == 1) return 'باقة واحدة';
  if (n == 2) return 'باقتين';
  if (n <= 10) return '${toArabicDigits(n)} باقات';
  return '${toArabicDigits(n)} باقة';
}

String featuresPhrase(int n) {
  if (n == 1) return 'ميزة واحدة';
  if (n == 2) return 'ميزتين';
  return '${toArabicDigits(n)} مميزات';
}

String subscribersPhrase(int n) => '${arGrouped(n)} مشتركة نشطة';

// ---------------------------------------------------------------------------
// Pricing (wizard_dc.js: sugU / unitOf / subOf / refOf)
// ---------------------------------------------------------------------------

/// `sugU(v, p)`: regular price minus [pct]%, rounded half-up to the nearest
/// 10 EGP. Integer maths so it never wobbles on .5 boundaries.
int defaultSubEgp(int regularEgp, [int pct = 10]) => (regularEgp * (100 - pct) + 500) ~/ 1000 * 10;

int monthlyEgp(Iterable<({int qty, int sub})> rows) {
  var n = 0;
  for (final r in rows) {
    n += r.qty * r.sub;
  }
  return n;
}

int referenceEgp(Iterable<({int qty, int regular})> rows) {
  var n = 0;
  for (final r in rows) {
    n += r.qty * r.regular;
  }
  return n;
}

/// Saving percent, rounded like `Math.round(save / ref * 100)`.
int savingPct(int ref, int price) => ref == 0 ? 0 : ((ref - price) * 100 / ref).round();

/// Per-visit average (`يعني للزيارة`). `null` when nothing is picked.
int? perVisitEgp(int price, int visits) => visits == 0 ? null : (price / visits).round();

/// What lands with the provider after the 10% commission (`بيوصلك بعد العمولة`).
int netEgp(int price) => (price * 0.9).round();

String priceNote(int regular, int sub) {
  if (sub <= 0) return 'اكتبي السعر';
  final diff = regular - sub;
  if (diff > 0) return 'أقل ${toArabicDigits((diff / regular * 100).round())}٪';
  if (diff < 0) return 'أعلى من العادي';
  return 'نفس العادي';
}

/// Copy under the saving block when there is nothing to celebrate.
String noSaveText({required bool allPriced, required int price, required int save}) {
  if (!allPriced) return 'اكتبي سعر كل خدمة في الاشتراك عشان تشوفي التوفير.';
  if (price <= 0) return 'اكتبي سعر الاشتراك عشان تشوفي التوفير.';
  if (save == 0) return 'السعر ده نفس الحجز بالزيارة — العميلة مش هتوفّر حاجة.';
  return 'السعر ده أعلى من الحجز بالزيارة بـ ${arGrouped(-save)} ج.م.';
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

/// Index 0 = Saturday … 6 = Friday (the server's `PlanWeekday`).
const dayShort = ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة'];
const dayFull = ['السبت', 'الحد', 'الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة'];

/// Plan weekday (0 = Saturday) of a Dart [DateTime].
int planWeekday(DateTime d) => (d.weekday + 1) % 7;

/// The days she ticks are the days the CUSTOMER may choose from (she picks a day
/// and a half of the day for every visit) — not the days the provider works.
/// Each weekday occurs about four times in a 30-day cycle, so the days only work
/// when they can hold every visit of the plan. (Replaces the prototype's
/// "≈ N visits a month, spread over the chosen days" line, which assumed she
/// decided the dates.)
bool daysEnough(int nDays, int visits) => nDays > 0 && nDays * 4 >= visits;

String fitLine(int nDays, int visits) {
  if (nDays == 0) return 'اختاري يوم واحد على الأقل';
  if (!daysEnough(nDays, visits)) {
    return 'الأيام دي مش كفاية لـ ${visitsPhrase(visits)} — زوّدي أيام عشان العميلة تلاقي مكان لكل زيارة';
  }
  return '✓ العميلة هتختار يوم وفترة لكل زيارة من الأيام دي — الصبح من ٩ أو بعد الضهر من ٢';
}

String daysLine(Iterable<int> days) {
  final sorted = days.toList()..sort();
  if (sorted.isEmpty) return '—';
  return sorted.map((i) => dayFull[i]).join(' و');
}

const _arWeekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _arMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIso(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `nice()` of wizard_dc.js: weekday، day month year, Arabic-Indic digits.
String niceDate(String iso) {
  final d = parseIso(iso);
  if (d == null) return '—';
  return '${_arWeekdays[d.weekday - 1]}، ${arNum(d.day)} ${_arMonths[d.month - 1]} ${arNum(d.year)}';
}

/// Compact numeric form shown in the date field: ٢٠٢٦/١٠/١٠.
String shortDate(String iso) {
  final d = parseIso(iso);
  if (d == null) return '';
  return toArabicDigits('${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}');
}

/// New plans default to starting a week from today.
String defaultStartDate(DateTime now) => isoDate(dateOnly(now).add(const Duration(days: 7)));

const kEndAfterStart = 'لازم يكون بعد تاريخ البداية';
const kPickEnd = 'اختاري تاريخ النهاية';

/// `true` when the end date is set and not strictly after the start.
bool endBeforeStart(String start, String end) {
  final s = parseIso(start), e = parseIso(end);
  if (s == null || e == null) return false;
  return !e.isAfter(s);
}

/// The grey/red line under the end-date field.
String endNiceLine(String start, String end) {
  if (parseIso(end) == null) return kPickEnd;
  if (endBeforeStart(start, end)) return kEndAfterStart;
  return niceDate(end);
}

/// Disabled-CTA label of step 3.
String step3DisabledLabel({required bool hasDays}) => hasDays ? 'حددي تاريخ النهاية' : 'اختاري يوم الزيارة';

String endLine({required bool ongoing, required String end}) {
  if (ongoing) return 'مستمرة من غير نهاية';
  return parseIso(end) == null ? 'من غير تاريخ نهاية' : 'لحد ${niceDate(end)}';
}

String publishLabel({required bool editing}) => editing ? 'احفظي ونشري التعديل' : 'انشري الباقة';

// ---------------------------------------------------------------------------
// Plan status / visit type / subscriber status copy
// ---------------------------------------------------------------------------

String planStatusLabel(String status) {
  switch (status) {
    case 'published':
    case 'active':
      return 'متاحة';
    case 'paused':
      return 'متوقّفة';
    case 'archived':
      return 'مؤرشفة';
    default:
      return 'مسودة';
  }
}

String visitTypeLabel(String type) => type == 'deep' ? 'تنظيف مميز' : 'صيانة · تنظيف عادي';

/// Same rule the server uses to classify a catalog item: «مميز» means a deep
/// visit; so does a plain «عميق» unless it is the regular visit with an extra
/// deep kitchen («تنظيف عادي + مطبخ عميق»).
String visitTypeForName(String arName, {String id = '', String? declared}) {
  if (declared == 'deep' || declared == 'regular') return declared!;
  if (id.contains('deep') || arName.contains('مميز')) return 'deep';
  if (arName.contains('عميق') && !arName.contains('مطبخ')) return 'deep';
  return 'regular';
}

String subscriberStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'نشطة';
    case 'paused':
      return 'متوقّفة';
    case 'at_risk':
      return 'معرّضة للإلغاء';
    case 'cancelled':
      return 'اتلغت';
    case 'ended':
      return 'خلصت';
    case 'pending_payment':
      return 'مستنية الدفع';
    case 'payment_failed':
    case 'past_due':
      return 'الدفع ما كملش';
    default:
      return status;
  }
}

/// `٣ / ٤` used visits of the minimum this cycle.
String usedOfMinimum(int used, int minimum) => '${arNum(used)} / ${arNum(minimum)}';
