import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/data/models.dart';

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

  test('plural tiers ar', () {
    expect(pluralTiers(1, ar: true), 'شريحة واحدة');
    expect(pluralTiers(2, ar: true), 'شريحتين');
    expect(pluralTiers(3, ar: true), '٣ شرايح');
    expect(pluralTiers(11, ar: true), '١١ شريحة');
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

  group('service benefits', () {
    test('survive a JSON round-trip so what she typed is what she gets back', () {
      final item = ServiceItem.fromJson({
        'id': 42,
        'name': {'en': 'Haircut', 'ar': 'قص شعر'},
        'durationMin': 45,
        'price': 20000,
        'categoryId': 'cat-1',
        'benefits': [
          {'en': 'Wash and blow-dry', 'ar': 'غسيل وتصفيف'},
          {'en': 'Products included', 'ar': 'المنتجات من عندنا'},
        ],
      });

      expect(item.benefits.length, 2);
      expect(item.benefits.first.of('ar'), 'غسيل وتصفيف');
      expect(item.benefits.last.of('en'), 'Products included');

      final json = item.toPatchJson();
      expect(json['benefits'], [
        {'en': 'Wash and blow-dry', 'ar': 'غسيل وتصفيف'},
        {'en': 'Products included', 'ar': 'المنتجات من عندنا'},
      ]);
    });

    test('a service with none omits the field rather than sending an empty list', () {
      final item = ServiceItem.fromJson({
        'id': 7,
        'name': {'en': 'Manicure', 'ar': 'مانيكير'},
        'durationMin': 30,
        'price': 9000,
      });

      expect(item.benefits, isEmpty);
      expect(item.toPatchJson().containsKey('benefits'), isFalse);
    });

    test('blank entries from the server are dropped, not rendered as empty bullets', () {
      final item = ServiceItem.fromJson({
        'id': 9,
        'name': {'en': 'Facial', 'ar': 'تنظيف بشرة'},
        'durationMin': 60,
        'price': 15000,
        'benefits': [
          {'en': '', 'ar': ''},
          {'en': 'Steam', 'ar': 'بخار'},
        ],
      });

      expect(item.benefits.length, 1);
      expect(item.benefits.single.of('en'), 'Steam');
    });
  });
}
