import 'package:oons/core/pro_format.dart' as legacy;

/// Ons design system — number and text formatting.
///
/// Rule: every number, price, time and count a person reads is shown in
/// Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) when the app is in Arabic, and in plain digits
/// in English. Latin digits stay Latin only for booking IDs, the clock in a
/// status bar, coupon codes and URLs — those never go through this file.
class DsFormat {
  DsFormat._();

  /// «120» → «١٢٠» (Arabic) / «120» (English).
  static String digits(Object? v, {required bool ar}) => ar ? legacy.toArabicDigits(v) : '$v';

  /// «1200» → «1,200» with an ASCII comma (before digit conversion).
  static String grouped(num n) {
    final neg = n < 0;
    final s = n.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return neg ? '-$b' : '$b';
  }

  /// Amount in pounds: «١,٢٠٠ ج.م» / «1,200 EGP».
  static String price(num egp, {required bool ar}) {
    final n = digits(grouped(egp), ar: ar);
    return ar ? '$n ج.م' : '$n EGP';
  }

  /// Amount held in piastres (the API's unit).
  static String pricePiastres(int piastres, {required bool ar}) => price(piastres / 100, ar: ar);

  /// Pounds without the currency, for places that print the unit separately.
  static String amount(num egp, {required bool ar}) => digits(grouped(egp), ar: ar);

  /// «9:00» / «09:00» → «٠٩:٠٠».
  static String time(String hhmm, {required bool ar}) {
    final p = hhmm.split(':');
    if (p.length < 2) return digits(hhmm, ar: ar);
    return digits('${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}', ar: ar);
  }

  /// «50» → «٥٠٪».
  static String percent(num n, {required bool ar}) => '${digits(n.round(), ar: ar)}${ar ? '٪' : '%'}';

  /// Hours after the clock-hour: «١٠ ساعات» style handled by the caller; this
  /// is only the «من–لحد» pair used by tiers: «١٢٠–١٥٠ م²».
  static String range(num from, num to, {required bool ar, String unit = ''}) =>
      '${digits(from, ar: ar)}–${digits(to, ar: ar)}${unit.isEmpty ? '' : ' $unit'}';

  /// Counted noun with correct Arabic number agreement:
  /// 1 → «تخصص واحد», 2 → «تخصصين», 3–10 → «٥ تخصصات», 11+ → «١١ تخصص».
  /// English: «1 specialty» / «5 specialties».
  static String count(
    int n, {
    required bool ar,
    required String one,
    required String two,
    required String few,
    required String many,
    String oneEn = '',
    String manyEn = '',
  }) {
    if (!ar) return n == 1 ? '$n $oneEn' : '$n $manyEn';
    if (n == 1) return one;
    if (n == 2) return two;
    if (n >= 3 && n <= 10) return '${digits(n, ar: true)} $few';
    return '${digits(n, ar: true)} $many';
  }

  static String specialties(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'تخصص واحد', two: 'تخصصين', few: 'تخصصات', many: 'تخصص', oneEn: 'specialty', manyEn: 'specialties');

  static String services(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'خدمة واحدة', two: 'خدمتين', few: 'خدمات', many: 'خدمة', oneEn: 'service', manyEn: 'services');

  static String visits(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'زيارة', two: 'زيارتين', few: 'زيارات', many: 'زيارة', oneEn: 'visit', manyEn: 'visits');

  static String tasks(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'بند', two: 'بندين', few: 'بنود', many: 'بند', oneEn: 'item', manyEn: 'items');

  static String plans(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'باقة واحدة', two: 'باقتين', few: 'باقات', many: 'باقة', oneEn: 'plan', manyEn: 'plans');

  static String days(int n, {required bool ar}) =>
      count(n, ar: ar, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم', oneEn: 'day', manyEn: 'days');

  /// «١ ساعة» / «ساعتين» / «٦ ساعات» — duration in minutes.
  static String duration(int minutes, {required bool ar}) => legacy.formatServiceDuration(minutes, ar: ar);

  /// Short duration for a visit card's time column: «٦ س».
  static String durationShort(int minutes, {required bool ar}) {
    if (minutes <= 0) return '';
    if (minutes < 60) return ar ? '${digits(minutes, ar: true)} د' : '${minutes}m';
    final h = minutes / 60;
    final txt = h == h.roundToDouble() ? '${h.round()}' : h.toStringAsFixed(1);
    return ar ? '${digits(txt, ar: true)} س' : '${txt}h';
  }
}
