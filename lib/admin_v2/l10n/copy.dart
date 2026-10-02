import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/pro_format.dart';

final localeCodeProvider = StateProvider<String>((ref) {
  try {
    return Hive.box('prefs').get('locale', defaultValue: 'ar') as String;
  } catch (_) {
    return 'ar';
  }
});

Future<void> setLocaleCode(WidgetRef ref, String code) async {
  await Hive.box('prefs').put('locale', code);
  ref.read(localeCodeProvider.notifier).state = code;
}

String t(Map<String, String> enAr, String lang) => lang == 'ar' ? enAr['ar']! : enAr['en']!;

/// Prototype-aligned empty / chrome copy.
abstract final class V2Copy {
  static const empty = {'en': 'Nothing here yet.', 'ar': 'لا يوجد شيء هنا بعد.'};
  static const loading = {'en': 'Loading…', 'ar': 'جاري التحميل…'};
  static const retry = {'en': 'Retry', 'ar': 'إعادة المحاولة'};
  static const search = {'en': 'Search', 'ar': 'بحث'};
  static const apply = {'en': 'Apply', 'ar': 'تطبيق'};
  static const clear = {'en': 'Clear', 'ar': 'مسح'};
  static const save = {'en': 'Save', 'ar': 'حفظ'};
  static const cancel = {'en': 'Cancel', 'ar': 'إلغاء'};
  static const confirm = {'en': 'Confirm', 'ar': 'تأكيد'};
  static const delete = {'en': 'Delete', 'ar': 'حذف'};
  static const exportCsv = {'en': 'Export CSV', 'ar': 'تصدير CSV'};
  static const bulkPay = {'en': 'Bulk pay', 'ar': 'دفع جماعي'};
  static const settle = {'en': 'Settle & send receipt', 'ar': 'تسوية وإرسال الإيصال'};
  static const exit = {'en': 'Exit', 'ar': 'خروج'};
  static const impersonating = {'en': 'Impersonating', 'ar': 'عرض كـ'};
  static const readOnly = {'en': 'read-only', 'ar': 'للقراءة فقط'};
  static const backOffice = {'en': 'Back office', 'ar': 'المكتب الخلفي'};
  static const viewAs = {'en': 'View as role', 'ar': 'عرض بدور'};
  static const signIn = {'en': 'Sign in', 'ar': 'تسجيل الدخول'};
  static const email = {'en': 'Email', 'ar': 'البريد'};
  static const password = {'en': 'Password', 'ar': 'كلمة المرور'};
  static const saved = {'en': 'Saved', 'ar': 'تم الحفظ'};
  static const all = {'en': 'All', 'ar': 'الكل'};
  static const providerGross = {'en': 'Provider gross', 'ar': 'صافي المهنية'};
  static const selected = {'en': 'selected', 'ar': 'محدد'};
}

/// Subscriptions (cleaning pilot) console copy. Arabic is the working language
/// of the pilot; English mirrors it for the language toggle.
abstract final class V2SubsCopy {
  static const title = {'en': 'Subscribers', 'ar': 'المشتركات'};
  static const colCustomer = {'en': 'Customer', 'ar': 'العميلة'};
  static const colProvider = {'en': 'Provider', 'ar': 'المتخصصة'};
  static const colPlan = {'en': 'Plan', 'ar': 'الباقة'};
  static const colVisits = {'en': 'Visits (used / min)', 'ar': 'الزيارات (المستخدم / الأدنى)'};
  static const colStatus = {'en': 'Status', 'ar': 'الحالة'};
  static const colRenewal = {'en': 'Next renewal', 'ar': 'التجديد الجاي'};
  static const filterAll = {'en': 'All', 'ar': 'الكل'};
  static const filterActive = {'en': 'Active', 'ar': 'نشطة'};
  static const filterPaused = {'en': 'Paused', 'ar': 'متوقّفة'};
  static const filterAtRisk = {'en': 'At risk', 'ar': 'معرّضة للإلغاء'};
  static const provisional = {
    'en': 'Provisional rule: "at risk" means two skipped visits in a row.',
    'ar': 'قاعدة مؤقتة: «معرّضة للإلغاء» يعني زيارتين متتاليتين اتخطّتهم المشتركة.',
  };
  static const empty = {'en': 'No subscriptions match.', 'ar': 'مفيش اشتراكات مطابقة.'};
  static const pause = {'en': 'Pause', 'ar': 'إيقاف'};
  static const cancel = {'en': 'Cancel', 'ar': 'إلغاء الاشتراك'};
  static const credit = {'en': 'Credit', 'ar': 'رصيد'};
  static const moveVisit = {'en': 'Move visit', 'ar': 'نقل زيارة'};
  static const settings = {'en': 'Pilot settings', 'ar': 'إعدادات التجربة'};
  static const pauseTitle = {'en': 'Pause this subscription?', 'ar': 'توقّفي الاشتراك ده؟'};
  static const pauseBody = {
    'en': 'No further cycles will be charged until it is resumed.',
    'ar': 'مش هيتحاسب على دورات جديدة لحد ما يرجع.',
  };
  static const pauseDone = {'en': 'Subscription paused.', 'ar': 'اتوقّف الاشتراك.'};
  static const cancelTitle = {'en': 'Cancel this subscription?', 'ar': 'تلغي الاشتراك ده؟'};
  static const cancelDone = {'en': 'Subscription cancelled.', 'ar': 'اتلغى الاشتراك.'};
  static const creditTitle = {'en': 'Credit the customer', 'ar': 'رصيد للعميلة'};
  static const creditAmount = {'en': 'Amount (EGP)', 'ar': 'المبلغ (ج.م)'};
  static const creditInvalid = {'en': 'Enter an amount above zero.', 'ar': 'اكتبي مبلغ أكبر من صفر.'};
  static const creditDone = {'en': 'Credit added.', 'ar': 'اتضاف الرصيد.'};
  static const moveTitle = {'en': 'Move a visit', 'ar': 'نقل زيارة'};
  static const moveVisitId = {'en': 'Visit id', 'ar': 'رقم الزيارة'};
  static const moveDate = {'en': 'New date', 'ar': 'التاريخ الجديد'};
  static const moveTime = {'en': 'New time', 'ar': 'الميعاد الجديد'};
  static const movePick = {'en': 'Choose', 'ar': 'اختاري'};
  static const moveInvalid = {'en': 'Choose a date and a time.', 'ar': 'اختاري التاريخ والميعاد.'};
  static const moveDone = {'en': 'Visit moved.', 'ar': 'اتنقلت الزيارة.'};
  static const confirm = {'en': 'Confirm', 'ar': 'تأكيد'};
  static const settingsTitle = {'en': 'Pilot settings', 'ar': 'إعدادات التجربة'};
  static const settingsEnabled = {'en': 'Pilot enabled', 'ar': 'التجربة شغّالة'};
  static const settingsCustomers = {'en': 'Customer ids on the allowlist (one per line)', 'ar': 'العميلات المسموح لهم (رقم في كل سطر)'};
  static const settingsProviders = {'en': 'Provider ids on the allowlist (one per line)', 'ar': 'المتخصصات المسموح لهم (رقم في كل سطر)'};
  static const settingsChecklists = {
    'en': 'One task per line. Empty means the default list: 18 tasks for deep visits; kitchen, reception and bathrooms for maintenance.',
    'ar': 'مهمة في كل سطر. فاضي يعني القائمة الافتراضية: ١٨ مهمة للزيارة المميزة، ومطبخ وريسيبشن وحمامات للصيانة.',
  };
  static const settingsDeep = {'en': 'Deep visit checklist', 'ar': 'قايمة الزيارة المميزة'};
  static const settingsMaint = {'en': 'Maintenance checklist', 'ar': 'قايمة الصيانة'};
  static const settingsSaved = {'en': 'Settings saved.', 'ar': 'اتحفظت الإعدادات.'};
  static const failed = {'en': 'Something went wrong. Try again.', 'ar': 'حصلت مشكلة. جرّبي تاني.'};

  static String summary(int active, int visits, String lang) => lang == 'ar'
      ? '${digits(active, ar: true)} مشتركة نشطة · ${digits(visits, ar: true)} زيارة الأسبوع ده'
      : '$active active subscribers · $visits visits this week';

  static String results(int n, String lang) => lang == 'ar' ? '${digits(n, ar: true)} اشتراك' : '$n subscriptions';

  static String visits(int used, int min, String lang) => '${digits(used, ar: lang == 'ar')} / ${digits(min, ar: lang == 'ar')}';

  static String status(String s, String lang) {
    final ar = switch (s) {
      'active' => 'نشطة',
      'paused' => 'متوقّفة',
      'at_risk' => 'معرّضة للإلغاء',
      'cancelled' => 'اتلغت',
      'ended' => 'خلصت',
      'pending_payment' => 'مستنية الدفع',
      'payment_failed' || 'past_due' => 'الدفع ما كملش',
      _ => s,
    };
    final en = switch (s) {
      'active' => 'Active',
      'paused' => 'Paused',
      'at_risk' => 'At risk',
      'cancelled' => 'Cancelled',
      'ended' => 'Ended',
      'pending_payment' => 'Pending payment',
      'payment_failed' || 'past_due' => 'Payment failed',
      _ => s,
    };
    return lang == 'ar' ? ar : en;
  }

  static String cancelPreview({required String amount, required int visits, required String service, required String fee, required String lang}) => lang == 'ar'
      ? 'هيتلغي الاشتراك وهيتردّ للعميلة $amount بالظبط (${digits(visits, ar: true)} زيارة متردّة: $service خدمة + $fee رسوم). العملية دي مش بتترجّع.'
      : 'The subscription will be cancelled and the customer refunded exactly $amount ($visits refundable visits: $service service + $fee fee). This cannot be undone.';
}
