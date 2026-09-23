import 'package:oons/core/format.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/data/models.dart';

/// Paymob pass-through schedule. Card and wallet are numerically identical
/// today (250 bps + 350 piastres), so an inclusive total before a method is
/// chosen is exact under current config — not just an estimate.
class ProcessingFeeSchedule {
  const ProcessingFeeSchedule({
    this.cardBps = 250,
    this.cardFixed = 350,
    this.walletBps = 250,
    this.walletFixed = 350,
    this.passThrough = true,
  });

  final int cardBps;
  final int cardFixed;
  final int walletBps;
  final int walletFixed;
  final bool passThrough;

  factory ProcessingFeeSchedule.fromJson(Map? j) {
    if (j == null) return const ProcessingFeeSchedule();
    // Bootstrap sends the schedule (bps/fixed). bookingDTO sends amounts
    // per method for a known total — ignore those here.
    if (j.containsKey('cardBps') || j.containsKey('passThrough')) {
      return ProcessingFeeSchedule(
        cardBps: (j['cardBps'] as num?)?.toInt() ?? 250,
        cardFixed: (j['cardFixed'] as num?)?.toInt() ?? 350,
        walletBps: (j['walletBps'] as num?)?.toInt() ?? 250,
        walletFixed: (j['walletFixed'] as num?)?.toInt() ?? 350,
        passThrough: j['passThrough'] != false,
      );
    }
    return const ProcessingFeeSchedule();
  }

  int feeFor(int basePiastres, [String method = 'card']) {
    if (!passThrough || basePiastres <= 0) return 0;
    var bps = cardBps;
    var fixed = cardFixed;
    final m = method.toLowerCase().trim();
    if (m == 'instapay' || m == 'wallet') {
      bps = walletBps;
      fixed = walletFixed;
    }
    if (m == 'manual' || m == 'instapay_manual' || m == 'instapay_transfer' || m == 'fawry' || m == 'kiosk') {
      return 0;
    }
    return (basePiastres * bps) ~/ 10000 + fixed;
  }

  int charge(int basePiastres, [String method = 'card']) =>
      basePiastres + feeFor(basePiastres, method);
}

class BookLine {
  BookLine({
    required this.item,
    required this.qty,
    required this.unit,
    required this.mult,
    required this.extra,
  });
  final ServiceItem item;
  final int qty;
  final int unit;
  final int mult;
  final String extra;
  int get amount => unit * mult;
  bool get isCleaning => item.isCleaning;
}

int hairAddFor(ServiceItem it, String hair) {
  if (!it.needsHairLength) return 0;
  return it.hairSurcharge[hair] ?? 0;
}

List<BookLine> bookLines({
  required List<ServiceItem> items,
  required Map<String, int> qty,
  required int guests,
  required String hair,
}) {
  final out = <BookLine>[];
  for (final it in items) {
    final q = qty[it.id] ?? 0;
    if (q <= 0) continue;
    final extraHair = hairAddFor(it, hair);
    final unit = it.price + extraHair;
    final extra = extraHair > 0
        ? (hair == 'long' ? 'long' : hair == 'short' ? 'short' : 'medium')
        : (it.isCleaning ? 'size' : '');
    final mult = it.isCleaning ? q : q * guests;
    out.add(BookLine(item: it, qty: q, unit: unit, extra: extra, mult: mult));
  }
  return out;
}

int bookSubtotal(List<BookLine> lines) => lines.fold(0, (a, l) => a + l.amount);

/// Matches the API: `ServiceItem.travelFee` is optional per-item travel in
/// piastres, multiplied by the line count (`bookings.go` does the same).
/// Area-level platform travel is a separate admin default and is not applied
/// here. Do not collapse this to one trip-per-address — the receipt would
/// disagree with the charge.
int bookTravel(List<BookLine> lines) {
  var t = 0;
  for (final l in lines) {
    if (l.item.travelFee > 0) t += l.item.travelFee * l.mult;
  }
  return t;
}

int bookTools({required List<BookLine> lines, required bool toolsFromProvider}) {
  if (!toolsFromProvider) return 0;
  if (!lines.any((l) => l.isCleaning)) return 0;
  return 5000;
}

int bookCartDuration(List<BookLine> lines) {
  var d = 0;
  for (final l in lines) {
    d += l.item.duration * l.mult;
  }
  return d < 1 ? 90 : d;
}

int bookExclusiveTotal({
  required List<BookLine> lines,
  required bool toolsFromProvider,
  int discount = 0,
  int trustFee = 0,
}) {
  final raw = bookSubtotal(lines) + bookTravel(lines) + bookTools(lines: lines, toolsFromProvider: toolsFromProvider) + trustFee - discount;
  return raw < 0 ? 0 : raw;
}

int bookInclusiveTotal({
  required List<BookLine> lines,
  required bool toolsFromProvider,
  required ProcessingFeeSchedule fees,
  int discount = 0,
  int trustFee = 0,
  String method = 'card',
}) {
  final base = bookExclusiveTotal(
    lines: lines,
    toolsFromProvider: toolsFromProvider,
    discount: discount,
    trustFee: trustFee,
  );
  return fees.charge(base, method);
}

String crewLine({required int workers, required int durationMin, required bool ar}) {
  final w = pluralWorkers(workers < 1 ? 1 : workers, ar: ar);
  final dur = formatServiceDuration(durationMin < 1 ? 60 : durationMin, ar: ar);
  if (dur.isEmpty) return w;
  return '$w · $dur';
}

const cleaningTaskNames = <String, Loc>{
  'cleaning.reception.chandelier': Loc('Polish chandelier', 'تلميع النجف'),
  'cleaning.reception.furniture': Loc('Polish furniture (wood & glass)', 'تلميع الأثاث (خشب وزجاج)'),
  'cleaning.reception.carpet_sweep': Loc('Sweep carpets', 'كنس السجاد'),
  'cleaning.reception.floors': Loc('Polish floors', 'تلميع الأرضيات'),
  'cleaning.reception.carpet_lay': Loc('Lay carpets', 'فرش السجاد'),
  'cleaning.kitchen.dishes': Loc('Wash dishes & sink', 'غسل الأطباق وتنظيف الحوض'),
  'cleaning.kitchen.stove': Loc('Wash stove racks & polish stove', 'غسل حوامل البوتاجاز وتلميعه'),
  'cleaning.kitchen.oven_microwave': Loc('Polish oven & microwave exterior', 'تلميع الفرن والميكروويف من بره'),
  'cleaning.kitchen.counter': Loc('Polish countertops', 'تلميع الرخامة'),
  'cleaning.kitchen.cabinets': Loc('Polish kitchen exterior', 'تلميع المطبخ من بره'),
  'cleaning.kitchen.floors': Loc('Mop floors & lay carpets', 'مسح الأرضيات وفرش السجاد'),
  'cleaning.bedrooms.sheets': Loc('Change bed linens', 'تغيير الملايات'),
  'cleaning.bedrooms.glass_furniture': Loc('Polish glass & furniture', 'تلميع الزجاج والأثاث'),
  'cleaning.bedrooms.floors': Loc('Mop floors', 'مسح الأرضيات'),
  'cleaning.bathrooms.walls': Loc('Wash walls', 'غسل الحائط'),
  'cleaning.bathrooms.sink': Loc('Wash sink', 'غسل الحوض'),
  'cleaning.bathrooms.toilet': Loc('Clean toilet', 'تنظيف التواليت'),
  'cleaning.bathrooms.floors': Loc('Mop floors', 'مسح الأرضيات'),
};

List<String> cleaningIncludeIds(ServiceItem it) {
  final ex = it.excludedTaskIds.toSet();
  return cleaningTaskNames.keys.where((id) => !ex.contains(id)).toList();
}

List<String> cleaningExcludeIds(ServiceItem it) =>
    it.excludedTaskIds.where((id) => cleaningTaskNames.containsKey(id)).toList();
