import 'package:oons/data/api.dart';
import 'package:oons/l10n/copy.dart';

/// User-facing line for API / network failures. Never returns `Instance of …`.
String friendlyError(Object e, String lang) {
  final t = Copy.of(lang)['errors'] as Map;
  if (e is ApiException) {
    final msg = e.message.trim();
    final low = msg.toLowerCase();
    if (e.isOffline || e.status == 0 || _network(low)) return '${t['offline']}';
    switch (e.status) {
      case 429:
        if (low.contains('wait a minute') ||
            low.contains('wait a few minutes') ||
            low.contains('wait before requesting')) {
          return '${t['otpWait']}';
        }
        return '${t['tooMany']}';
      case 401:
        if (low.contains('expir')) return '${t['otpExpired']}';
        if (low.contains('match')) return '${t['otpBad']}';
        break;
      case 400:
        if (low.contains('egyptian') || low.contains('mobile number') || low.contains('valid egyptian')) {
          return '${t['badPhone']}';
        }
        break;
      case 403:
        if (low.contains('approved test') || low.contains('allowlist') || low.contains('otp is only')) {
          return lang == 'ar'
              ? 'تعذّر إرسال الرمز لهذا الرقم الآن. حاولِي مرة أخرى أو تواصلي مع الدعم.'
              : 'Could not send a code to this number right now. Try again or contact support.';
        }
        break;
      case 502:
      case 503:
        if (low.contains('trial') || low.contains('whapi') || low.contains('plan')) {
          return lang == 'ar'
              ? 'إرسال واتساب محدود على الخطة الحالية. يلزم ترقية Whapi أو إرسال رسالة أول مرة إلى رقم أُنس، ثم أعيدي المحاولة.'
              : 'WhatsApp sending is limited on the current plan. Upgrade Whapi, or message the Oons WhatsApp number once first, then retry.';
        }
        if (low.contains('whatsapp') || low.contains('code')) {
          return lang == 'ar'
              ? 'تعذّر إرسال رمز واتساب. حاولِي بعد قليل.'
              : 'Could not send the WhatsApp code. Try again in a moment.';
        }
        break;
    }
    const keys = {
      'Need a valid Egyptian number.': 'badPhone',
      'Need a mobile number.': 'badPhone',
      'Wait a minute before requesting another code.': 'otpWait',
      'Wait a few minutes before requesting another code.': 'otpWait',
      'Wait before requesting another code for this number.': 'otpWait',
      'Too many attempts. Request a new code.': 'tooMany',
      'Too many codes from this network. Try again later.': 'tooMany',
      'Too many codes requested. Try again later.': 'tooMany',
      'Too many new-number codes from this network. Try again later.': 'tooMany',
      'Sign-in is temporarily limited. Try again later.': 'tooMany',
      "That code doesn't match.": 'otpBad',
      'That code has expired.': 'otpExpired',
      'Need the four digits.': 'otpBad',
    };
    final key = keys[msg];
    if (key != null) return '${t[key]}';

    // Curated Arabic for the provider-registration validation messages
    // (the server returns clear English; the Arabic UI must say what to fix).
    if (lang == 'ar') {
      const ar = <String, String>{
        'Need your details.': 'بعض البيانات ناقصة أو بصيغة غير صحيحة. راجعي النموذج وحاولي مرة أخرى.',
        'Need your first and last name.': 'اكتبي الاسم الأول واسم العائلة.',
        'Pick a service: beauty, cleaning, or chef.': 'اختاري الخدمة: تجميل، تنظيف، أو شيف.',
        'Pick at least one live neighbourhood.': 'اختاري منطقة تغطية واحدة على الأقل من المتاحة.',
        'Need your legal name, birth date, and residence.': 'اكتبي الاسم القانوني، تاريخ الميلاد، والعنوان.',
        'Professionals must be 21 or older.': 'يلزم أن يكون عمركِ ٢١ سنة أو أكثر، وتاريخ الميلاد بصيغة سنة-شهر-يوم (مثال: 1995-01-31).',
        'National ID must be 14 digits.': 'يلزم أن يكون الرقم القومي ١٤ رقمًا بالضبط.',
        'Need every legal consent to continue.': 'يلزم الموافقة على كل البنود للمتابعة.',
        'Need your legal name.': 'اكتبي الاسم القانوني الكامل.',
        'That photo is too large (8 MB max). Try a lower-resolution photo.':
            'الصورة كبيرة جدًا (٨ ميغابايت حدًا أقصى). حاولِي بصورة أصغر أو بجودة أقل.',
        'Need a photo.': 'اختاري صورة.',
      };
      final m = ar[msg];
      if (m != null) return m;
      // Client-side validation errors: tell them to check inputs, not "server busy".
      if (e.status >= 400 && e.status < 500) {
        return 'هناك بيانات غير صحيحة في النموذج. راجعيها وحاولي مرة أخرى.';
      }
      return '${t['generic']}';
    }
    if (msg.isNotEmpty && msg != 'error' && msg != 'offline' && !_technical(low)) return msg;
    return '${t['generic']}';
  }
  if (_network('$e'.toLowerCase())) return '${t['offline']}';
  return '${t['generic']}';
}

bool _network(String low) =>
    low.contains('offline') ||
    low.contains('socket') ||
    low.contains('connection') ||
    low.contains('timed out') ||
    low.contains('timeout') ||
    low.contains('network') ||
    low.contains('failed host lookup') ||
    low.contains('connection refused') ||
    low.contains('connection errored');

bool _technical(String low) =>
    low.contains('socket') ||
    low.contains('dioexception') ||
    low.contains('exception') ||
    low.contains('instance of');
