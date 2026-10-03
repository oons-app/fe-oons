import 'package:oons/core/pro_format.dart';

/// Customer-side copy for the cleaning-subscriptions pilot, taken VERBATIM from
/// the prototype (cleaning_dc.js / cleaning_template.html). One place.
class CC {
  CC._();

  // Shared / fee explainer
  static const feeTipLabel = 'ليه رسوم الخدمة؟';
  static const feeTipTitle = 'الـ١٠٪ دي بتروح فين؟';
  static const feeShort =
      'بتغطي التحقق من المتخصصة (بطاقة وفيش ومقابلة)، وحفظ فلوسك لحد ما الزيارة تخلص، والدعم طول اليوم، وبديلة لو هي اعتذرت. سعر الخدمة نفسه بيروح لها كامل.';
  static const feeReasons = [
    'التحقق من كل متخصصة: البطاقة والفيش ومقابلة وش لوش، وبنراجعهم كل سنة.',
    'فلوسك بتفضل محفوظة عندنا لحد ما الزيارة تخلص وإنتي تأكدي.',
    'دعم بشري طول اليوم، وبديلة في نفس الميعاد لو هي اعتذرت.',
    'الدفع الآمن، وتشغيل التطبيق والمواعيد والتذكيرات.',
  ];
  static const feeClosing = 'سعر الخدمة نفسه بيروح لها كامل.';
  static const payingAdvance = 'مقدّم للشهر · شامل ١٠٪ رسوم';

  // E1
  static const e1PlanFilter = 'عندها باقة شهرية بس';
  static const e1MoreSearch = 'بحث أدق';

  // E2
  static const e2Once = 'مرة واحدة';
  static const e2Monthly = 'باقة شهرية';
  static const e2Intro = 'باقات من المتخصصة اللي اخترتيها. نفس المتخصصة كل زيارة، والشهر بيتدفع مقدّم.';
  static const e2BeautyLine = 'الباقات الشهرية متاحة للتنظيف بس في فترة التجربة.';
  static const e2BarMonthly = 'الباقة · مقدّم للشهر';
  static const e2BarNone = 'لم تُختر خدمة بعد';
  static const e2BarNoneSub = 'اختاري خدمة للبدء';
  static const e2CtaMonthly = 'اختاري مواعيد الشهر';
  static const e2CtaOnce = 'تابعي إلى الموعد';
  static const stepPlan = '١ الباقة';
  static const stepService = '١ الخدمة';
  static const stepMonthDates = '٢ مواعيد الشهر';
  static const stepSlot = '٢ الموعد';
  static const stepPay = '٣ الدفع';
  static const pickPlan = 'اختاري الباقة';
  static const picked = 'الباقة مختارة';

  // Plan card (E2 / S2)
  static const paygLabel = 'زيارة بزيارة';
  static const subLabel = 'بالاشتراك';
  static const perMonth = ' /شهر';
  static const recommended = 'مناسبة لو البيت محتاج تنظيف كامل الأول';
  static const startPlan = 'ابدئي الباقة';

  // S2
  static const s2Title = 'باقات التنظيف';
  static const s2Footnote = 'الأسعار توضيحية، وهي اللي حددتها المتخصصة لباقاتها في فترة التجربة.';
  static const s2PricesLine = 'الأسعار بالجنيه · رسوم خدمة ١٠٪';
  static const s2AdvanceTail = '· الشهر بيتدفع مقدّم';

  static const s2FromPrefix = 'من ';
  static const s2LoadFailedTitle = 'مقدرناش نحمّل الباقات';
  static const s2Retry = 'جرّبي تاني';
  static const s2EmptyTitle = 'مفيش باقات شهرية دلوقتي';
  static const s2EmptyBody = 'المتخصصة دي لسه ما نشرتش باقات. تقدري تحجزي مرة واحدة.';
  static const s2EmptyCta = 'احجزي مرة واحدة';

  // S3
  static const s3Title = 'الباقة فيها إيه';
  static const s3Includes = 'ما تشمله الخدمات';
  static const s3Deep = 'تنظيف مميز';
  static const s3Regular = 'تنظيف عادي';
  static const s3DeepHeading = 'كامل من فوق لتحت';
  static const s3DeepBody = 'تنظيف شامل لكل الأوض في أول زيارة.';
  static const s3RegularHeading = 'زيارة متابعة خفيفة';
  static const s3RegularBody = 'تنظيف أخف كل أسبوع عشان البيت يفضل نضيف بين التنظيف المميز.';
  static const s3Diff = 'الفرق بينهم';
  static const s3ColWork = 'الشغل';
  static const s3ColDeep = 'مميز';
  static const s3ColRegular = 'عادي';
  static const s3Inside = 'داخل';
  static const s3Outside = 'مش داخل';
  static const s3Cta = 'اختاري المواعيد';
  static const s3Tasks = [
    ('تنضيف المطبخ بالعمق', false),
    ('جوّه الأجهزة', false),
    ('إزالة الجير من الحمام', false),
    ('مسح الأسطح', true),
    ('كنس ومسح الأرضيات', true),
  ];
  static String s3SaveLine(String save, int pct) => 'وفّري $save ج.م في الشهر · ${toArabicDigits(pct)}٪';

  // S5
  static const s5Title = 'باقتي';
  static const s5NextVisit = 'الزيارة الجاية';
  static const s5NoNext = 'مفيش زيارة جاية متحدّدة';
  static const s5VisitsLabel = 'زيارات الدورة دي';
  static const s5Note = 'الزيارة اللي اتخطّيتيها مش بتضيع — بتختاريلها يوم تاني جوّه نفس الدورة.';
  static const s5Reschedule = 'غيّري ميعاد الزيارة الجاية';
  static const s5Skip = 'اتخطّي الزيارة دي';
  static const s5Pause = 'وقّفي الباقة';
  static const s5Resume = 'كمّلي الباقة';
  static const s5Cancel = 'الغي الباقة';
  static const s5Bill = 'الفاتورة';
  static const s5PlaceMakeup = 'اختاري يوم للزيارة البديلة';
  static const s5PaidAdvance = ' · اتدفعت مقدّم';
  static String s5With(String name) => 'مع $name';
  static const s5Back = 'رجوع';
  static const s5NoPlanTitle = 'مفيش باقة دلوقتي';
  static const s5NoPlanBody = 'لما تشتركي في باقة شهرية هتلاقي زياراتها هنا.';
  static const s5NoPlanCta = 'ارجعي للرئيسية';
  static const s5Confirm = 'أكّدي';
  static const s5Keep = 'لأ، سيبيها';
  static const s5SkipTitle = 'تتخطّي الزيارة دي؟';
  static String s5SkipBody(String? deadline) =>
      'الزيارة مش هتضيع، هتختاري لها يوم تاني جوّه نفس الدورة${deadline == null ? '' : ' قبل $deadline'}. لو ما اخترتيش يوم قبل الميعاد ده، الزيارة البديلة بتضيع ومش بترجع فلوسها.';
  static const s5PauseTitle = 'توقّفي الباقة؟';
  static const s5PauseBody = 'الباقة هتتوقّف من الدورة الجاية. الزيارات اللي في الدورة دي تفضل زي ما هي.';
  static const s5ResumeTitle = 'تكمّلي الباقة؟';
  static const s5ResumeBody = 'الباقة هترجع تشتغل، وممكن الدورة الجاية تتدفع دلوقتي.';
  static const s5Done = 'تمام، اتعمل.';
  static const s5Failed = 'حصلت مشكلة. جرّبي تاني.';
  static const s5RetryLoad = 'جرّبي تاني';

  // Cancel flow
  static const cancelTitle = 'الغي الباقة';
  static const cancelRefundLabel = 'هيرجعلك';
  static String cancelRefundLine(int visits) => 'عن ${arNum(visits)} زيارات لسه متعملتش';
  static const cancelReasonLabel = 'ليه عايزة تلغي؟';
  static const cancelNoteHint = 'تحبي تقولي حاجة تانية؟ (اختياري)';
  static const cancelConfirm = 'أكّدي إلغاء الباقة';
  static const cancelKeep = 'خلّيني في الباقة';
  static const cancelDone = 'الباقة اتلغت.';
  static const cancelFootnote = 'الزيارات اللي اتعملت أو اللي فاضل لها أقل من ٤٨ ساعة مش بترجع فلوسها.';

  // S6
  static const s6Title = 'الفاتورة';
  static const s6PaidAdvance = 'اتدفعت مقدّم';
  static const s6Cycle = 'الدورة';
  static const s6PayDate = 'تاريخ الدفع';
  static const s6Method = 'طريقة الدفع';
  static const s6Visits = 'الزيارات اللي في الفاتورة دي';
  static const s6PlanPrice = 'سعر الباقة';
  static const s6Fee = 'رسوم الخدمة · ١٠٪';
  static const s6Total = 'الإجمالي المدفوع مقدّم';
  static const s6DraftLabel = 'مسودة سياسة · مش نهائية';
  static const s6DraftBody = 'الباقة بتتدفع مقدّم كل شهر. لو لغيتي، الزيارات اللي ما اتعملتش بترجعلك فلوسها بالنسبة.';
  static const s6Receipt = 'نزّلي الإيصال';
  static const s6ChangeCard = 'غيّري الكارت';
  static const s6ReceiptFailed = 'مقدرناش نفتح الإيصال. جرّبي تاني.';
  static const s6ChangeCardSoon = 'تغيير الكارت هيتوفّر قريب.';
  static String s6Saved(String save) => 'وفّرتي $save ج.م الشهر ده عن الحجز زيارة بزيارة';

  // S1
  static const s1Subscribe = 'اشتركي ووفّري';
  static const s1Once = 'احجزي مرة واحدة';
  static String s1SaveLine(int pct) => 'وفّري لحد ${toArabicDigits(pct)}٪ لما تحجزي بانتظام';
  static String s1BlockTitle(int n) => 'عندها ${toArabicDigits(n)} باقات شهرية';
  static const s1BlockBody = 'نفس المتخصصة كل مرة';
  static String s1BlockBodyFull(String maxSave) =>
      'نفس المتخصصة كل مرة، وتوفّري لحد $maxSave ج.م في الشهر عن الحجز زيارة زيارة.';

  static String e2Nudge(String maxSave) => 'بتنظّفي كل أسبوع؟ الباقة الشهرية أوفر لحد $maxSave ج.م';
  static String planBoxTitle(int n) => 'باقة شهرية · ${toArabicDigits(n)} باقات';
  static String planBoxSub(String from, int pct) => 'من $from ج.م/شهر · وفّري لحد ${toArabicDigits(pct)}٪';
  static String resultCount(int n) => '${toArabicDigits(n)} متخصصة متاحة';
  static String subCount(int n) => '${toArabicDigits(n)} متخصصة';
  static String saveBlock(String save) => 'وفّري $save';
}

// --- Arabic digits / money helpers (pure) ---

/// `1,200` style grouping with Arabic-Indic digits (prototype: AR(n.toLocaleString('en-US'))).
String arNum(num n) {
  final v = n.round();
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return toArabicDigits('${neg ? '-' : ''}$b');
}

/// Piastres to whole-EGP text in Arabic digits, e.g. 120000 -> `١,٢٠٠`.
String egpText(int piastres) => arNum((piastres / 100).round());

/// Piastres to `١,٢٠٠ ج.م`.
String egpUnit(int piastres) => '${egpText(piastres)} ج.م';

/// Server rule (D3): fee = whole-EGP half-up of 10% of the plan price.
int feePiastresFor(int pricePiastres, {double rate = 0.10}) {
  if (pricePiastres <= 0 || rate <= 0) return 0;
  final egp = pricePiastres / 100 * rate;
  return (egp + 0.5 + 1e-9).floor() * 100;
}

int savePctFor(int savePiastres, int paygPiastres) =>
    paygPiastres <= 0 ? 0 : (savePiastres / paygPiastres * 100).round();

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _daysFull = ['الأحد', 'الاتنين', 'التلات', 'الأربع', 'الخميس', 'الجمعة', 'السبت'];

/// `السبت ٣ أكتوبر` (prototype dLabel).
String dateLabelAr(DateTime d) => '${_daysFull[d.weekday % 7]} ${toArabicDigits(d.day)} ${_months[d.month - 1]}';

/// `٣ أكتوبر` (prototype dShort).
String dateShortAr(DateTime d) => '${toArabicDigits(d.day)} ${_months[d.month - 1]}';

DateTime? parseYmd(Object? v) {
  final s = '${v ?? ''}';
  if (s.length < 10) return null;
  final p = DateTime.tryParse(s.substring(0, 10));
  return p == null ? null : DateTime(p.year, p.month, p.day);
}

/// `HH:MM` to Arabic-Indic prototype slot label (`١١ ص`, `٣ م`).
String slotLabelAr(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm.trim());
  if (m == null) return toArabicDigits(hhmm);
  final h = int.parse(m.group(1)!);
  final min = m.group(2)!;
  final suffix = h >= 12 ? 'م' : 'ص';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '${toArabicDigits(h12)}${min == '00' ? '' : ':${toArabicDigits(min)}'} $suffix';
}
