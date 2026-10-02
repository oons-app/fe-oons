import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/plan_calendar.dart';

/// API client used by the S4 / pay / reschedule screens. A seam so widget
/// tests can substitute a fake; production uses the global [api].
ApiClient subApi = api;

/// Arabic copy for S4 + the subscribe/pay flow. Prototype wording verbatim
/// (cleaning_dc.js / cleaning_template.html); the few strings the prototype
/// does not have are marked NEW.
class MD {
  static const title = 'مواعيد الشهر';
  static const back = 'رجوع';
  static const steps = ['١ الباقة', '٢ مواعيد الشهر', '٣ الدفع'];
  static const tabWeekly = 'كل أسبوع';
  static const tabCustom = 'أختار كل زيارة';
  static const howWeekly = 'دوسي على يوم أول زيارة، وهنكمّل الباقي كل ٧ أيام في نفس الميعاد.';
  static const howCustom = 'اختاري زيارة من القايمة تحت، وبعدين دوسي على اليوم اللي عايزاها فيه.';
  static const listWeekly = 'الزيارات · كل أسبوع';
  static const listCustom = 'الزيارات · دوسي على واحدة تغيّريها';
  static const timeWeekly = 'الفترة — لكل الزيارات';
  static const rules =
      'كل الزيارات جوّه ٣٠ يوم من أول زيارة، وبين كل زيارتين يومين على الأقل. تقدري تغيّري أي زيارة بعدين من صفحة الباقة.';
  static const advanceBar = 'مقدّم للشهر';

  static String feeIncl(String pct) => 'مقدّم للشهر · شامل $pct٪ رسوم';
  static String timeCustom(int index, DateTime d) => 'الفترة — زيارة ${arDigits(index + 1)} · ${dShort(d)}';
  static String cycleShort(DateTime a, DateTime b) => '${dShort(a)} – ${dShort(b)}';
  static String cycleLong(DateTime a, DateTime b) => 'الدورة: ${dShort(a)} لحد ${dShort(b)}';
  static String cta(String total) => 'ادفعي مقدّم · $total ج.م';

  // NEW strings (not in the prototype).
  static const generic = 'حصلت مشكلة، جرّبي تاني.';
  static const loadingHeading = 'بنجهّز مواعيد المتخصصة';
  static const loadingCaption = 'ثواني ونفتح لك التقويم.';
  static const retry = 'جرّبي تاني';
  static const holdLabel = 'مواعيدك محجوزة لمدة';
  static const holdExpired = 'مهلة حجز المواعيد خلصت، وحجزناها لك من جديد.';
  static const holdLost = 'مهلة حجز المواعيد خلصت. اختاري مواعيدك تاني.';
  static const planMissing = 'الباقة دي مش متاحة دلوقتي.';
  static const noWeekdayTitle = 'مفيش مواعيد متاحة';
  static const noWeekdayBody = 'المتخصصة مفيهاش أيام فاضية للباقة دي في الفترة الجاية. جرّبي بعد شوية.';

  // Reschedule (S5 → reschedule one visit).
  static const reTitle = 'غيّري ميعاد الزيارة';
  static const reCta = 'غيّري الميعاد';
  static const reHowCustom = 'دوسي على اليوم الجديد للزيارة، وبعدين اختاري الفترة: الصبح من ٩ أو بعد الضهر من ٢.';
  static const reLoading = 'بنجهّز مواعيد الزيارة';
  static const reMissing = 'الزيارة دي مش موجودة.';
  static const reTooLate = 'مينفعش تغيّري ميعاد الزيارة دي دلوقتي. لازم قبلها ٢٤ ساعة على الأقل، وتغيير واحد في الدورة.';
  static const reOutOfCycle = 'اليوم ده برّه الدورة الحالية.';
  static const reDone = 'اتغيّر ميعاد الزيارة.';
  static String reLabel(int index, DateTime d) => 'الزيارة ${arDigits(index + 1)} · ${dLabel(d)}';
  static const reRules = 'الزيارة الجديدة لازم تكون جوّه نفس الدورة، وقبلها ٢٤ ساعة على الأقل.';
  static String reFrom(String when) => 'الميعاد الحالي: $when';
}

/// Customer-facing message for any failure: the server's Arabic text, never
/// raw English / exception strings.
String arMessage(Object? e) {
  final m = e is ApiException ? e.message : (e is String ? e : '');
  if (m.trim().isNotEmpty && RegExp(r'[؀-ۿ]').hasMatch(m)) return m.trim();
  return MD.generic;
}
