import 'package:oons/ds/ds.dart';

/// Weekday and date labels without `intl` locale data, so they work everywhere
/// (and in tests). Weekdays use Dart's numbering: 1 = Monday … 7 = Sunday.

const _shortAr = {6: 'سبت', 7: 'حد', 1: 'اتنين', 2: 'تلات', 3: 'أربع', 4: 'خميس', 5: 'جمعة'};
const _shortEn = {6: 'Sat', 7: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri'};
const _fullAr = {6: 'السبت', 7: 'الأحد', 1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة'};
const _fullEn = {6: 'Saturday', 7: 'Sunday', 1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday'};
const _monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The week as Egyptians read it, Saturday first (values are Dart weekdays).
const weekOrderSatFirst = [6, 7, 1, 2, 3, 4, 5];

String dayShort(int weekday, {required bool ar}) => (ar ? _shortAr : _shortEn)[weekday] ?? '';
String dayFull(int weekday, {required bool ar}) => (ar ? _fullAr : _fullEn)[weekday] ?? '';

/// «السبت ٣ أكتوبر» / «Saturday 3 Oct».
String dayTitle(DateTime d, {required bool ar}) =>
    '${dayFull(d.weekday, ar: ar)} ${DsFormat.digits(d.day, ar: ar)} ${(ar ? _monthsAr : _monthsEn)[d.month - 1]}';

/// «٣ أكتوبر» / «3 Oct».
String dayMonth(DateTime d, {required bool ar}) => '${DsFormat.digits(d.day, ar: ar)} ${(ar ? _monthsAr : _monthsEn)[d.month - 1]}';

DateTime dateOnlyOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
