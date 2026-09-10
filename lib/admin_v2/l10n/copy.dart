import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
