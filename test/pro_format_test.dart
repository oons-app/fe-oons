import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/pro_format.dart';

void main() {
  test('digit conversion round-trip', () {
    expect(toArabicDigits('120'), '١٢٠');
    expect(toWesternDigits('١٢٠'), '120');
    expect(normalizeMoneyInput('٠٨٠٠'), '800');
    expect(normalizeMoneyInput('٨٠٠ج'), '800');
  });

  test('plural services ar', () {
    expect(pluralService(1, ar: true), '١ خدمة');
    expect(pluralService(2, ar: true), 'خدمتين');
    expect(pluralService(5, ar: true), '٥ خدمات');
    expect(pluralService(11, ar: true), '١١ خدمة');
  });

  test('plural workers ar', () {
    expect(pluralWorkers(1, ar: true), 'عاملة واحدة');
    expect(pluralWorkers(2, ar: true), 'عاملتين');
    expect(pluralWorkers(3, ar: true), '٣ عاملات');
  });

  test('plural tasks ar', () {
    expect(pluralTasks(18, ar: true), '١٨ مهمة');
    expect(pluralTasks(5, ar: true), '٥ مهام');
  });

  test('net after commission — travel not commissioned', () {
    expect(netAfterCommission(priceEgp: 1000, travelEgp: 50, commissionRate: 0.1), 950);
    expect(netAfterCommission(priceEgp: 800, travelEgp: 0, commissionRate: 0.1), 720);
  });

  test('cleaning size overlap', () {
    expect(
      cleaningSizesOverlap(aFrom: 120, aTo: 150, bFrom: 140, bTo: 190),
      isTrue,
    );
    expect(
      cleaningSizesOverlap(aFrom: 120, aTo: 150, bFrom: 155, bTo: 190),
      isFalse,
    );
    expect(
      cleaningSizesOverlap(aFrom: 191, aTo: null, bFrom: 200, bTo: null),
      isTrue,
    );
  });
}
