import 'package:oons/core/pro_format.dart';
import 'package:oons/features/subscribe/customer_copy.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String _locAr(Object? v) {
  if (v is Map) return '${v['ar'] ?? ''}'.trim();
  return '${v ?? ''}'.trim();
}

/// One line of a provider plan, e.g. `٢ × تنظيف مميز`.
class PlanLine {
  const PlanLine({
    required this.visitType,
    required this.quantity,
    this.name = '',
    this.catalogItemId = '',
    this.itemId = '',
    this.regularPiastres = 0,
    this.subPiastres = 0,
    this.durationMin = 0,
  });

  /// `deep` or anything else (treated as regular).
  final String visitType;
  final int quantity;

  /// Full catalog name in Arabic (e.g. `تنظيف مميز`); empty when missing.
  final String name;
  final String catalogItemId;
  final String itemId;
  final int regularPiastres;
  final int subPiastres;
  final int durationMin;

  bool get deep => visitType == 'deep';

  /// Full catalog name, falling back to the generic type name.
  String get fullName => name.isNotEmpty ? name : (deep ? 'تنظيف مميز' : 'تنظيف عادي');

  /// Short name for later lines of the title: `تنظيف عادي` -> `عادي`.
  String get shortName {
    final n = fullName;
    final stripped = n.startsWith('تنظيف ') ? n.substring(6).trim() : n;
    return stripped.isEmpty ? n : stripped;
  }

  factory PlanLine.fromJson(Map raw) => PlanLine(
        visitType: '${raw['visitType'] ?? raw['type'] ?? 'regular'}',
        quantity: _i(raw['quantity'] ?? raw['qty']),
        name: _locAr(raw['name']),
        catalogItemId: '${raw['catalogItemId'] ?? ''}',
        itemId: '${raw['itemId'] ?? ''}',
        regularPiastres: _i(raw['regularPriceSnapshotPiastres'] ?? raw['pricePiastres']),
        subPiastres: _i(raw['subPricePiastres']),
        durationMin: _i(raw['durationMin']),
      );
}

/// Lines ordered deep first (stable), as in the prototype planMeta.
List<PlanLine> orderedLines(List<PlanLine> lines) {
  final live = lines.where((l) => l.quantity > 0).toList();
  final deep = live.where((l) => l.deep);
  final rest = live.where((l) => !l.deep);
  return [...deep, ...rest];
}

/// Generated title: first line full catalog name, later lines short, suffix
/// ` في الشهر`. Example: `١ تنظيف مميز + ٣ عادي في الشهر`.
String planTitleFor(List<PlanLine> lines) {
  final ord = orderedLines(lines);
  if (ord.isEmpty) return '';
  final parts = <String>[
    for (var i = 0; i < ord.length; i++) '${toArabicDigits(ord[i].quantity)} ${i == 0 ? ord[i].fullName : ord[i].shortName}',
  ];
  return '${parts.join(' + ')} في الشهر';
}

/// Visit types in plan order (deep first), one entry per visit.
List<String> visitTypesFor(List<PlanLine> lines) => [
      for (final l in orderedLines(lines)) ...List.filled(l.quantity, l.deep ? 'deep' : 'regular'),
    ];

/// A plan card as served by GET /providers/:id/plans: `{plan, quote, priceDrift}`.
class PlanData {
  const PlanData({
    required this.id,
    required this.providerId,
    required this.lines,
    required this.recommended,
    required this.paygPiastres,
    required this.pricePiastres,
    required this.feePiastres,
    required this.totalPiastres,
    required this.savePiastres,
    required this.savePct,
    this.raw = const {},
    this.includedBenefits = const [],
  });

  final String id;
  final String providerId;
  final List<PlanLine> lines;
  final bool recommended;
  final int paygPiastres;
  final int pricePiastres;
  final int feePiastres;
  final int totalPiastres;
  final int savePiastres;
  final int savePct;
  final Map<String, dynamic> raw;
  final List<String> includedBenefits;

  String get title => planTitleFor(lines);
  List<PlanLine> get ordered => orderedLines(lines);
  List<String> get types => visitTypesFor(lines);
  int get visitCount => types.length;
  bool get hasDeep => lines.any((l) => l.quantity > 0 && l.deep);
  bool get hasRegular => lines.any((l) => l.quantity > 0 && !l.deep);

  /// The olive «وفّري N» block is hidden when saving <= 0 (D4).
  bool get showSave => savePiastres > 0;

  factory PlanData.fromRow(Map row) {
    final plan = row['plan'] is Map ? Map<String, dynamic>.from(row['plan'] as Map) : Map<String, dynamic>.from(row);
    final q = row['quote'] is Map ? Map<String, dynamic>.from(row['quote'] as Map) : <String, dynamic>{};
    final lines = [
      for (final l in (plan['lines'] as List? ?? const []))
        if (l is Map) PlanLine.fromJson(l),
    ];
    var payg = _i(q['paygPiastres']);
    if (payg == 0) payg = lines.fold(0, (a, l) => a + l.regularPiastres * l.quantity);
    var price = _i(q['pricePiastres']);
    if (price == 0) price = _i(plan['pricePiastres']);
    final hasFee = q['feePiastres'] != null;
    final fee = hasFee ? _i(q['feePiastres']) : feePiastresFor(price);
    final total = q['totalPiastres'] != null ? _i(q['totalPiastres']) : price + fee;
    final saveRaw = q['savingPiastres'] ?? q['savePiastres'];
    final save = saveRaw != null ? _i(saveRaw) : payg - price;
    final pctRaw = q['savingPct'] ?? q['savePct'];
    return PlanData(
      id: '${plan['id'] ?? plan['_id'] ?? ''}',
      providerId: '${plan['providerId'] ?? ''}',
      lines: lines,
      recommended: plan['recommended'] == true,
      paygPiastres: payg,
      pricePiastres: price,
      feePiastres: fee,
      totalPiastres: total,
      savePiastres: save,
      savePct: pctRaw != null ? _i(pctRaw) : savePctFor(save, payg),
      raw: plan,
      includedBenefits: [
        for (final b in (row['includedBenefits'] as List? ?? const []))
          if ('$b'.trim().isNotEmpty) '$b'.trim(),
      ],
    );
  }

  static List<PlanData> listFrom(Object? plans) => [
        for (final r in (plans as List? ?? const []))
          if (r is Map) PlanData.fromRow(r),
      ];
}

/// Highest saving across plans (piastres), 0 when none saves.
int maxSavePiastres(List<PlanData> plans) => plans.fold(0, (a, p) => p.savePiastres > a ? p.savePiastres : a);

int maxSavePct(List<PlanData> plans) => plans.fold(0, (a, p) => p.savePct > a ? p.savePct : a);

int minPricePiastres(List<PlanData> plans) {
  if (plans.isEmpty) return 0;
  return plans.map((p) => p.pricePiastres).reduce((a, b) => a < b ? a : b);
}

/// One row of the S3 «الفرق بينهم» table.
class ScopeRow {
  const ScopeRow(this.task, {required this.deep, required this.regular});
  final String task;
  final bool deep;
  final bool regular;
}

/// Prototype rows (used when the provider's catalog gives no usable task data).
List<ScopeRow> prototypeScopeRows() => [
      for (final t in CC.s3Tasks) ScopeRow(t.$1, deep: true, regular: t.$2),
    ];

/// Rows for the comparison table from the two catalog items' task checklists:
/// every task that differs first, then up to two shared ones. Falls back to the
/// prototype rows when the catalog has no excluded-task data to compare.
List<ScopeRow> scopeRowsFor({
  required List<String> deepExcluded,
  required List<String> regularExcluded,
  required Map<String, String> taskNames,
}) {
  final diff = <ScopeRow>[];
  final shared = <ScopeRow>[];
  for (final e in taskNames.entries) {
    final d = !deepExcluded.contains(e.key);
    final r = !regularExcluded.contains(e.key);
    if (!d && !r) continue;
    (d == r ? shared : diff).add(ScopeRow(e.value, deep: d, regular: r));
  }
  if (diff.isEmpty) return prototypeScopeRows();
  return [...diff, ...shared.take(2)];
}
