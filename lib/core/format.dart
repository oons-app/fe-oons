import 'package:intl/intl.dart';

class Loc {
  const Loc(this.en, this.ar);
  final String en;
  final String ar;

  String of(String lang) {
    final primary = _scrub(lang == 'ar' ? ar : en);
    if (primary.isNotEmpty) return primary;
    // English UI may fall back to Arabic; Arabic never shows English.
    if (lang == 'en') return _scrub(ar);
    return '';
  }

  static String _scrub(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    s = s.replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*·\s*'), ' · ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'^·\s*|\s*·$'), '').trim();
    return s.toLowerCase() == 'null' ? '' : s;
  }

  factory Loc.fromJson(dynamic j) {
    if (j is Map) {
      return Loc(_scrub('${j['en'] ?? ''}'), _scrub('${j['ar'] ?? ''}'));
    }
    final s = _scrub('$j');
    return Loc(s, s);
  }

  Map<String, String> toJson() => {'en': en, 'ar': ar};
}

String money(int piastres, String lang) {
  final egp = piastres / 100.0;
  if (lang == 'ar') {
    final n = NumberFormat('#,##0', 'ar').format(egp.round());
    return '$n ج.م';
  }
  final n = NumberFormat('#,##0', 'en').format(egp.round());
  return '$n EGP';
}

/// Human label for booking `paymentMethod` (card / instapay / fawry).
String paymentMethodLabel(String? method, String lang) {
  switch ((method ?? '').toLowerCase().trim()) {
    case 'instapay':
    case 'wallet':
      return lang == 'ar' ? 'محفظة الموبايل' : 'Mobile Wallet';
    case 'fawry':
    case 'kiosk':
      return lang == 'ar' ? 'فوري' : 'Fawry';
    case 'card':
      return lang == 'ar' ? 'بطاقة ائتمان' : 'Credit Card';
    default:
      return '';
  }
}

String moneySigned(int piastres, String lang) {
  final sign = piastres > 0 ? '+' : (piastres < 0 ? '−' : '');
  return '$sign${money(piastres.abs(), lang).replaceAll(' EGP', '').replaceAll(' ج.م', '')}';
}

String formatClock(DateTime t, String lang) {
  final local = t.toLocal();
  if (lang == 'ar') {
    return DateFormat('h:mm a', 'ar').format(local).replaceAll('AM', 'ص').replaceAll('PM', 'م');
  }
  return DateFormat('h:mm a').format(local);
}

/// Local clock "HH:mm" → UTC "HH:mm" using the current offset.
String localHourToUtc(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return hm;
  final now = DateTime.now();
  final local = DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
  final u = local.toUtc();
  return '${u.hour.toString().padLeft(2, '0')}:${u.minute.toString().padLeft(2, '0')}';
}

String utcHourToLocal(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return hm;
  final now = DateTime.now().toUtc();
  final u = DateTime.utc(now.year, now.month, now.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
  final l = u.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Parse availability slot instant (stored UTC, shown local).
DateTime? parseSlotStart(Map slot) {
  final raw = slot['start'];
  if (raw == null || '$raw'.isEmpty) return null;
  return DateTime.tryParse('$raw');
}

String availabilitySlotLabel(Map slot, String lang) {
  final start = parseSlotStart(slot);
  if (start != null) return formatClock(start.toLocal(), lang);
  final label = '${slot['label'] ?? ''}';
  if (label.contains('UTC')) {
    final hm = label.replaceAll(' UTC', '').trim();
    return utcHourToLocal(hm);
  }
  return label;
}

/// UTC instant to send when creating/rescheduling a booking.
DateTime availabilitySlotUtc(Map day, Map slot) {
  final start = parseSlotStart(slot);
  if (start != null) return start.toUtc();
  final d = DateTime.tryParse('${day['date']}') ?? DateTime.now();
  final label = availabilitySlotLabel(slot, 'en');
  final parts = label.split(':');
  final local = DateTime(d.year, d.month, d.day, int.tryParse(parts[0]) ?? 10, int.tryParse(parts[1]) ?? 0);
  return local.toUtc();
}

const defaultLocalSlotHours = [
  '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
  '15:00', '16:00', '17:00', '18:00', '19:00', '20:00',
];

String formatSlot(DateTime t, String lang) {
  final local = t.toLocal();
  if (lang == 'ar') {
    final d = DateFormat('EEEE d MMM', 'ar').format(local);
    final hm = DateFormat('h:mm a', 'ar').format(local).replaceAll('AM', 'ص').replaceAll('PM', 'م');
    return '$d · $hm';
  }
  return DateFormat("EEE d MMM · h:mm a").format(local);
}

String greet(DateTime now, String lang, String name) {
  final h = now.hour;
  if (lang == 'ar') {
    if (h < 12) return 'صباح الخير يا $name.';
    if (h < 18) return 'مساء الخير يا $name.';
    return 'مساء الخير يا $name.';
  }
  if (h < 12) return 'Good morning, $name.';
  if (h < 18) return 'Good afternoon, $name.';
  return 'Good evening, $name.';
}

const areaEn = {
  'zamalek': 'Zamalek',
  'dokki': 'Dokki',
  'mohandeseen': 'Mohandeseen',
  'maadi': 'Maadi',
  'nasr_city': 'Nasr City',
  'heliopolis': 'Heliopolis',
  'new_cairo': 'New Cairo',
  '6th_october': '6th of October',
  'helwan': 'Helwan',
  'shubra': 'Shubra',
  'haram': 'Haram',
  'faisal': 'Faisal',
  'agouza': 'Agouza',
  'smouha': 'Smouha',
  'stanley': 'Stanley',
  'sidi_gaber': 'Sidi Gaber',
  'montaza': 'Montaza',
  'miami': 'Miami',
  'roushdy': 'Roushdy',
  'madinaty': 'Madinaty',
  'rehab': 'El Rehab',
  'capital': 'The Capital',
};
const areaAr = {
  'zamalek': 'الزمالك',
  'dokki': 'الدقي',
  'mohandeseen': 'المهندسين',
  'maadi': 'المعادي',
  'nasr_city': 'مدينة نصر',
  'heliopolis': 'مصر الجديدة',
  'new_cairo': 'التجمع',
  '6th_october': '٦ أكتوبر',
  'helwan': 'حلوان',
  'shubra': 'شبرا',
  'haram': 'الهرم',
  'faisal': 'فيصل',
  'agouza': 'العجوزة',
  'smouha': 'سموحة',
  'stanley': 'ستانلي',
  'sidi_gaber': 'سيدي جابر',
  'montaza': 'المنتزه',
  'miami': 'ميامي',
  'roushdy': 'رشدي',
  'madinaty': 'مدينتي',
  'rehab': 'الرحاب',
  'capital': 'العاصمة الإدارية',
};

String areaName(String id, String lang) => lang == 'ar' ? (areaAr[id] ?? id) : (areaEn[id] ?? id);

/// Replace raw area slugs that were stored in older booking line items.
String localizeAreaSlugs(String text, String lang) {
  var out = text;
  for (final id in areaEn.keys) {
    final name = areaName(id, lang);
    if (name == id) continue;
    out = out.replaceAll(id, name);
  }
  return out;
}

const weekdayAr = ['اتنين', 'تلات', 'أربع', 'خميس', 'جمعه', 'سبت', 'حد'];
const weekdayEn = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

String weekdayLabel(DateTime date, String lang) {
  final i = date.weekday - 1;
  if (i < 0 || i > 6) return '';
  return lang == 'ar' ? weekdayAr[i] : weekdayEn[i];
}

/// Cairo area centroids used when a saved address has no pin.
const areaCoords = {
  'zamalek': (30.0626, 31.2194),
  'dokki': (30.0383, 31.2122),
  'mohandeseen': (30.0520, 31.2000),
  'maadi': (29.9602, 31.2569),
  'nasr_city': (30.0561, 31.3300),
  'heliopolis': (30.0909, 31.3240),
  'new_cairo': (30.0131, 31.4913),
  '6th_october': (29.9285, 30.9188),
  'helwan': (29.8414, 31.3008),
  'shubra': (30.0769, 31.2456),
  'haram': (29.9870, 31.1450),
  'faisal': (29.9980, 31.1500),
  'agouza': (30.0560, 31.2100),
  'smouha': (31.2156, 29.9400),
  'stanley': (31.2390, 29.9600),
  'sidi_gaber': (31.2180, 29.9400),
  'montaza': (31.2880, 30.0200),
  'miami': (31.2600, 29.9700),
  'roushdy': (31.2400, 29.9500),
  'madinaty': (30.0750, 31.6700),
  'rehab': (30.0600, 31.4900),
  'capital': (30.0200, 31.7400),
};

(double, double) coordsForArea(String area) => areaCoords[area] ?? (30.0444, 31.2357);

/// Closest Greater Cairo service area to a dropped pin.
String areaFromCoords(double lat, double lng) {
  var best = 'zamalek';
  var bestD = double.infinity;
  areaCoords.forEach((id, c) {
    final d = (lat - c.$1) * (lat - c.$1) + (lng - c.$2) * (lng - c.$2);
    if (d < bestD) {
      bestD = d;
      best = id;
    }
  });
  return best;
}

bool areaIsGiza(String area) => area == 'dokki' || area == 'mohandeseen';

String googleMapsUrl(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
