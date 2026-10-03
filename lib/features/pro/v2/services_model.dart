import 'package:oons/core/format.dart' show Loc;
import 'package:oons/data/models.dart';

/// Category (vertical) → Specialty → Service, built from what the API already
/// returns: her `/pro/categories` rows (one per specialty she holds or asked
/// for) and her service items. Pure functions: no widgets, no network.
enum SpecialtyStatus { approved, pending, attention }

/// `/pro/categories` status → what the UI cares about; null = not shown
/// (removed specialties).
SpecialtyStatus? specialtyStatusOf(String raw) {
  switch (raw) {
    case 'active':
      return SpecialtyStatus.approved;
    case 'pending_addition_approval':
    case 'pending_initial_vetting':
      return SpecialtyStatus.pending;
    case 'rejected':
    case 'changes_requested':
      return SpecialtyStatus.attention;
    default:
      return null;
  }
}

class ProSpecialty {
  const ProSpecialty({
    required this.categoryId,
    required this.slug,
    required this.name,
    required this.vertical,
    required this.status,
    required this.items,
    this.decisionNote = '',
  });

  final String categoryId;
  final String slug;
  final Loc name;
  final String vertical;
  final SpecialtyStatus status;
  final List<ServiceItem> items;
  final String decisionNote;

  /// Area-priced packages (cleaning size tiers), smallest first.
  List<ServiceItem> get tiers => (items.where((i) => i.isCleaning).toList()..sort((a, b) => a.sizeFromSqm.compareTo(b.sizeFromSqm)));

  /// Everything else she sells under this specialty.
  List<ServiceItem> get services => items.where((i) => !i.isCleaning).toList();

  int get serviceCount => items.length;
  int get visibleCount => items.where((i) => i.active).length;
  bool get hasTiers => items.any((i) => i.isCleaning);
}

class ProCategoryGroup {
  const ProCategoryGroup({required this.vertical, required this.specialties});
  final String vertical;
  final List<ProSpecialty> specialties;

  int get serviceCount => specialties.fold(0, (n, s) => n + s.serviceCount);
}

const _verticalOrder = ['cleaning', 'beauty', 'chef', 'childcare'];

/// Groups her specialties by vertical (her own vertical first, then the usual
/// order) and attaches each service to its specialty.
///
/// An item with no (or an unknown) `categoryId` is attached by name, then to her
/// first approved specialty, so nothing she sells ever disappears.
List<ProCategoryGroup> groupSpecialties({
  required List<Map<String, dynamic>> categoryRows,
  required List<ServiceItem> items,
  String primaryVertical = '',
  String lang = 'ar',
}) {
  final rows = <Map<String, dynamic>>[];
  for (final r in categoryRows) {
    if (specialtyStatusOf('${r['status']}') != null) rows.add(r);
  }
  String idOf(Map<String, dynamic> r) => '${r['categoryId']}';

  final firstApproved = rows.firstWhere(
    (r) => specialtyStatusOf('${r['status']}') == SpecialtyStatus.approved,
    orElse: () => const {},
  );

  String? attach(ServiceItem it) {
    final id = it.categoryId;
    if (id != null && id.isNotEmpty && rows.any((r) => idOf(r) == id)) return id;
    final label = it.name.ar.isNotEmpty ? it.name.ar : it.name.en;
    for (final r in rows) {
      final n = r['name'];
      if (n is Map) {
        final loc = Loc.fromJson(n);
        if (loc.ar == label || loc.en == label) return idOf(r);
      }
    }
    return firstApproved.isEmpty ? null : idOf(firstApproved);
  }

  final byCat = <String, List<ServiceItem>>{};
  for (final it in items) {
    final c = attach(it);
    if (c != null) byCat.putIfAbsent(c, () => []).add(it);
  }

  final byVertical = <String, List<ProSpecialty>>{};
  for (final r in rows) {
    final vertical = '${r['vertical'] ?? ''}';
    final n = r['name'];
    byVertical.putIfAbsent(vertical, () => []).add(ProSpecialty(
      categoryId: idOf(r),
      slug: '${r['slug'] ?? ''}',
      name: n is Map ? Loc.fromJson(n) : Loc('${n ?? ''}', '${n ?? ''}'),
      vertical: vertical,
      status: specialtyStatusOf('${r['status']}')!,
      items: byCat[idOf(r)] ?? const [],
      decisionNote: '${r['decisionNote'] ?? ''}',
    ));
  }

  int rank(String v) {
    if (v == primaryVertical) return -1;
    final i = _verticalOrder.indexOf(v);
    return i < 0 ? 99 : i;
  }

  final keys = byVertical.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  return [
    for (final k in keys)
      ProCategoryGroup(
        vertical: k,
        specialties: byVertical[k]!
          ..sort((a, b) {
            // approved first, then pending, then needs-changes; stable by name.
            final s = a.status.index.compareTo(b.status.index);
            return s != 0 ? s : a.name.of(lang).compareTo(b.name.of(lang));
          }),
      ),
  ];
}

/// What she takes home for a [priceEgp] service after Oons' commission.
int netEgp(num priceEgp, double commissionRate) => (priceEgp * (1 - commissionRate)).round();

/// Rounds a price after a ±% change to the nearest 5 pounds (never below 5).
int bulkPrice(int priceEgp, double factor) {
  final next = ((priceEgp * factor) / 5).round() * 5;
  return next < 5 ? 5 : next;
}

/// Vertical key → Arabic / English category name and icon.
String verticalName(String key, {required bool ar}) {
  const arNames = {'cleaning': 'التنظيف المنزلي', 'beauty': 'التجميل والعناية', 'chef': 'الطبخ', 'childcare': 'رعاية الأطفال'};
  const enNames = {'cleaning': 'Home cleaning', 'beauty': 'Beauty & care', 'chef': 'Chef', 'childcare': 'Childcare'};
  return (ar ? arNames : enNames)[key] ?? key;
}

String verticalIcon(String key) {
  switch (key) {
    case 'cleaning':
      return 'clean';
    case 'beauty':
      return 'beauty';
    case 'chef':
      return 'home';
    default:
      return 'user';
  }
}
