import 'package:flutter/material.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';

/// Safe map/list extractors for staff API JSON (Dio often yields Map&lt;dynamic,dynamic&gt;).
Map<String, dynamic>? asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in v) {
    final m = asMap(item);
    if (m != null) out.add(m);
  }
  return out;
}

List<dynamic> asDynList(dynamic v) => v is List ? v : const [];

String idOf(dynamic row, [List<String> keys = const ['id', '_id']]) {
  if (row is! Map) return '';
  for (final k in keys) {
    final v = row[k];
    if (v == null) continue;
    final s = '$v'.trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

String shortId(String id, {int keep = 8}) {
  if (id.isEmpty) return '';
  if (id.length <= keep) return id;
  return id.substring(0, keep);
}

/// Prefer localized first+last; fall back to nested person maps, phone, then short id.
String personName(dynamic row, String lang, {String? fallbackId}) {
  final m = asMap(row);
  if (m == null) {
    final s = locName(row, lang).trim();
    return s.isNotEmpty ? s : (fallbackId != null && fallbackId.isNotEmpty ? shortId(fallbackId) : '');
  }

  for (final key in ['name', 'displayName', 'fullName', 'providerName', 'customerName', 'clientName']) {
    final direct = locName(m[key], lang).trim();
    if (direct.isNotEmpty) return direct;
  }

  final first = locName(m['firstName'], lang).trim();
  final last = locName(m['lastName'], lang).trim();
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;

  for (final nest in ['provider', 'client', 'user', 'customer', 'subject']) {
    final nested = asMap(m[nest]);
    if (nested == null) continue;
    final n = personName(nested, lang);
    if (n.isNotEmpty) return n;
  }

  final phone = '${m['phone'] ?? ''}'.trim();
  if (phone.isNotEmpty) return phone;

  final id = fallbackId ?? idOf(m);
  return id.isNotEmpty ? shortId(id) : '';
}

String bookingRef(Map row) {
  final ref = '${row['ref'] ?? ''}'.trim();
  if (ref.isNotEmpty) return ref;
  final id = idOf(row);
  return id.isEmpty ? '' : '#${shortId(id)}';
}

Map<String, dynamic>? nestedPerson(Map row, List<String> keys) {
  for (final k in keys) {
    final m = asMap(row[k]);
    if (m != null) return m;
  }
  return null;
}

String clientNameOf(Map booking, String lang) {
  final nested = nestedPerson(booking, ['client', 'customer', 'user']);
  if (nested != null) return personName(nested, lang, fallbackId: idOf(nested));
  return personName(booking['customerName'] ?? booking['clientName'], lang, fallbackId: '${booking['clientId'] ?? ''}');
}

String providerNameOf(Map booking, String lang) {
  final nested = nestedPerson(booking, ['provider', 'pro']);
  if (nested != null) return personName(nested, lang, fallbackId: idOf(nested));
  return personName(booking['providerName'], lang, fallbackId: '${booking['providerId'] ?? ''}');
}

String serviceLabel(Map row, String lang) {
  final n = locName(row['serviceName'] ?? row['service'], lang).trim();
  return n;
}

String areaLabel(dynamic area, String lang) {
  if (area == null) return '';
  if (area is Map) {
    final n = locName(area['name'] ?? area['cityName'] ?? area, lang).trim();
    if (n.isNotEmpty) return n;
    final slug = '${area['slug'] ?? area['cityId'] ?? area['id'] ?? ''}'.trim();
    return slug.isEmpty ? '' : areaName(slug, lang);
  }
  final s = '$area'.trim();
  if (s.isEmpty) return '';
  final localized = locName(area, lang).trim();
  if (localized.isNotEmpty && localized != s) return localized;
  return areaName(s, lang);
}

bool isZeroTime(dynamic v) {
  if (v == null) return true;
  final s = '$v';
  return s.isEmpty || s.startsWith('0001') || s == 'null';
}

String providerVetting(Map p, String lang) {
  if (!isZeroTime(p['rejectedAt'])) return lang == 'ar' ? 'مرفوضة' : 'Rejected';
  if (!isZeroTime(p['vettedAt'])) return lang == 'ar' ? 'تم التحقق' : 'Vetted';
  final hasId = '${p['idPhotoUrl'] ?? p['idPath'] ?? ''}'.isNotEmpty;
  final hasFish = '${p['fishPhotoUrl'] ?? p['fishPath'] ?? ''}'.isNotEmpty;
  if (!hasId || !hasFish) return lang == 'ar' ? 'بانتظار المستندات' : 'Awaiting docs';
  return lang == 'ar' ? 'بانتظار المراجعة' : 'Pending review';
}

V2Tone vettingTone(Map p) {
  if (!isZeroTime(p['rejectedAt'])) return V2Tone.bad;
  if (!isZeroTime(p['vettedAt'])) return V2Tone.ok;
  return V2Tone.warn;
}

String providerState(Map p, String lang) {
  if (!isZeroTime(p['payoutFrozenAt']) || !isZeroTime(p['suspendedAt']) || '${p['status'] ?? ''}'.toLowerCase() == 'suspended') {
    return lang == 'ar' ? 'موقوفة' : 'Suspended';
  }
  if (!isZeroTime(p['rejectedAt'])) return lang == 'ar' ? 'مرفوضة' : 'Rejected';
  if (!isZeroTime(p['vettedAt'])) return lang == 'ar' ? 'نشطة' : 'Active';
  return lang == 'ar' ? 'معلقة' : 'Pending';
}

V2Tone providerStateTone(Map p) {
  final s = providerState(p, 'en').toLowerCase();
  if (s == 'active') return V2Tone.ok;
  if (s == 'suspended' || s == 'rejected') return V2Tone.bad;
  return V2Tone.warn;
}

int listLen(dynamic v) {
  if (v is List) return v.length;
  if (v is Map) return v.length;
  return asInt(v);
}

int serviceCountOf(Map p) {
  if (p['serviceCount'] != null) return asInt(p['serviceCount']);
  if (p['items'] is List) return (p['items'] as List).length;
  if (p['services'] is List) return (p['services'] as List).length;
  return 0;
}

int areaCountOf(Map p) {
  if (p['areaCount'] != null) return asInt(p['areaCount']);
  if (p['areas'] is List) return (p['areas'] as List).length;
  return 0;
}

DateTime? parseTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = '$v'.trim();
  if (s.isEmpty || s.startsWith('0001')) return null;
  return DateTime.tryParse(s)?.toLocal();
}

String formatWhen(dynamic v, String lang) {
  final t = parseTime(v);
  if (t == null) return '';
  return formatSlot(t, lang);
}

String formatDay(dynamic v, String lang) {
  final t = parseTime(v);
  if (t == null) return '';
  return formatClock(t, lang);
}

Widget identityCell(String title, String? subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title.isEmpty ? '—' : title, style: const TextStyle(fontWeight: FontWeight.w600, color: Ops.ink)),
      if (subtitle != null && subtitle.isNotEmpty)
        Text(
          subtitle.startsWith('#') ? subtitle : '#$subtitle',
          style: const TextStyle(fontSize: 11, color: Ops.muted, fontFamily: Ops.mono),
        ),
    ],
  );
}

Map<String, dynamic> unwrapEntity(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final m = asMap(data[k]);
    if (m != null) return m;
  }
  return data;
}

String staffRoleOf(Map m) => '${m['staffRole'] ?? m['role'] ?? ''}'.trim();

bool staffEnabled(Map m) {
  if (m.containsKey('disabled')) return m['disabled'] != true;
  if (m.containsKey('enabled')) return m['enabled'] != false;
  return true;
}

String statusLabel(String? status, String lang) {
  switch ((status ?? '').toLowerCase()) {
    case 'pending':
    case 'pending_payment':
    case 'pendingpayment':
      return lang == 'ar' ? 'بانتظار الدفع' : 'Pending payment';
    case 'paid':
    case 'confirmed':
      return lang == 'ar' ? 'مؤكد' : 'Confirmed';
    case 'on_the_way':
    case 'ontheway':
      return lang == 'ar' ? 'في الطريق' : 'On the way';
    case 'in_progress':
    case 'inprogress':
      return lang == 'ar' ? 'جارية' : 'In progress';
    case 'completed':
      return lang == 'ar' ? 'مكتملة' : 'Completed';
    case 'cancelled':
    case 'canceled':
    case 'cancelled_by_client':
      return lang == 'ar' ? 'ملغاة' : 'Cancelled';
    case 'active':
      return lang == 'ar' ? 'نشطة' : 'Active';
    case 'locked':
    case 'locked_teaser':
      return lang == 'ar' ? 'مقفلة' : 'Locked';
    case 'open':
      return lang == 'ar' ? 'مفتوحة' : 'Open';
    case 'resolved':
    case 'closed':
      return lang == 'ar' ? 'مغلقة' : 'Closed';
    case 'held':
      return lang == 'ar' ? 'معلّقة' : 'Held';
    case 'requested':
    case 'pending_addition':
      return lang == 'ar' ? 'مطلوب' : 'Requested';
    case 'approved':
      return lang == 'ar' ? 'موافق عليها' : 'Approved';
    case 'rejected':
      return lang == 'ar' ? 'مرفوضة' : 'Rejected';
    default:
      return status ?? '';
  }
}

V2Tone statusTone(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'completed':
    case 'paid':
    case 'confirmed':
    case 'active':
    case 'approved':
    case 'resolved':
    case 'closed':
    case 'vetted':
      return V2Tone.ok;
    case 'pending':
    case 'pending_payment':
    case 'on_the_way':
    case 'ontheway':
    case 'in_progress':
    case 'inprogress':
    case 'held':
    case 'requested':
    case 'pending_addition':
    case 'locked':
    case 'locked_teaser':
      return V2Tone.warn;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
    case 'suspended':
    case 'open':
      return V2Tone.bad;
    default:
      return V2Tone.neutral;
  }
}
