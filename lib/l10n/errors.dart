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
              ? 'تعذر إرسال الكود لهذا الرقم دلوقتي. جرّبي تاني أو تواصلي مع الدعم.'
              : 'Could not send a code to this number right now. Try again or contact support.';
        }
        break;
      case 502:
      case 503:
        if (low.contains('trial') || low.contains('whapi') || low.contains('plan')) {
          return lang == 'ar'
              ? 'إرسال واتساب محدود على الخطة الحالية. لازم ترقّي Whapi أو تبعتي رسالة لأول مرة لرقم أُنس، بعدين جرّبي تاني.'
              : 'WhatsApp sending is limited on the current plan. Upgrade Whapi, or message the Oons WhatsApp number once first, then retry.';
        }
        if (low.contains('whatsapp') || low.contains('code')) {
          return lang == 'ar'
              ? 'ما قدرناش نبعت كود واتساب. جرّبي بعد شوية.'
              : 'Could not send the WhatsApp code. Try again in a moment.';
        }
        break;
    }
    const keys = {
      'Need a valid Egyptian number.': 'badPhone',
      'Need a mobile number.': 'badPhone',
      'Wait a few minutes before requesting another code.': 'otpWait',
      'Too many attempts. Request a new code.': 'tooMany',
      "That code doesn't match.": 'otpBad',
      'That code has expired.': 'otpExpired',
      'Need the four digits.': 'otpBad',
    };
    final key = keys[msg];
    if (key != null) return '${t[key]}';
    // Never surface raw English API text in Arabic UI.
    if (lang == 'ar') return '${t['generic']}';
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
