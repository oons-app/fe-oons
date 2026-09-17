import 'dart:convert';

import 'package:hive/hive.dart';

class BookDraft {
  BookDraft({
    this.qty = const {},
    this.vertical,
    this.areaM = '',
    this.chipSqm,
    this.toolsFromProvider = true,
    this.guests = 1,
    this.hair = 'medium',
    this.day = 0,
    this.slot = 0,
    this.addressId,
    this.notes = '',
    this.noteChipIds = const [],
    this.coupon = '',
  });

  Map<String, int> qty;
  String? vertical;
  String areaM;
  int? chipSqm;
  bool toolsFromProvider;
  int guests;
  String hair;
  int day;
  int slot;
  String? addressId;
  String notes;
  List<String> noteChipIds;
  String coupon;

  Map<String, dynamic> toJson() => {
        'qty': qty,
        'vertical': vertical,
        'areaM': areaM,
        'chipSqm': chipSqm,
        'toolsFromProvider': toolsFromProvider,
        'guests': guests,
        'hair': hair,
        'day': day,
        'slot': slot,
        'addressId': addressId,
        'notes': notes,
        'noteChipIds': noteChipIds,
        'coupon': coupon,
      };

  factory BookDraft.fromJson(Map j) {
    final q = <String, int>{};
    final raw = j['qty'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final n = e.value is num ? (e.value as num).toInt() : int.tryParse('${e.value}') ?? 0;
        if (n > 0) q['${e.key}'] = n;
      }
    }
    return BookDraft(
      qty: q,
      vertical: j['vertical'] as String?,
      areaM: '${j['areaM'] ?? ''}',
      chipSqm: (j['chipSqm'] as num?)?.toInt(),
      toolsFromProvider: j['toolsFromProvider'] != false,
      guests: ((j['guests'] as num?)?.toInt() ?? 1).clamp(1, 6),
      hair: '${j['hair'] ?? 'medium'}',
      day: (j['day'] as num?)?.toInt() ?? 0,
      slot: (j['slot'] as num?)?.toInt() ?? 0,
      addressId: j['addressId'] as String?,
      notes: '${j['notes'] ?? ''}',
      noteChipIds: ((j['noteChipIds'] as List?) ?? const []).map((e) => '$e').toList(),
      coupon: '${j['coupon'] ?? ''}',
    );
  }
}

String _draftKey(String providerId) => 'bookDraft:$providerId';

BookDraft? loadBookDraft(String providerId) {
  if (!Hive.isBoxOpen('prefs')) return null;
  final raw = Hive.box('prefs').get(_draftKey(providerId));
  if (raw is! String || raw.isEmpty) return null;
  try {
    final j = jsonDecode(raw);
    if (j is Map) return BookDraft.fromJson(Map<String, dynamic>.from(j));
  } catch (_) {}
  return null;
}

Future<void> saveBookDraft(String providerId, BookDraft draft) async {
  if (!Hive.isBoxOpen('prefs')) return;
  await Hive.box('prefs').put(_draftKey(providerId), jsonEncode(draft.toJson()));
}

Future<void> clearBookDraft(String providerId) async {
  if (!Hive.isBoxOpen('prefs')) return;
  await Hive.box('prefs').delete(_draftKey(providerId));
}
