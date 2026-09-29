import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/models.dart';
import 'package:oons/features/book/book_pricing.dart';

void main() {
  test('clientServiceFeeBps 1000 adds 10% of service subtotal', () {
    final item = ServiceItem(
      id: 'pkg-a',
      name: const Loc('Cut', 'قص'),
      duration: 60,
      price: 10000, // 100 EGP
    );
    final lines = [
      BookLine(item: item, qty: 1, unit: 10000, mult: 1, extra: ''),
    ];
    expect(bookSubtotal(lines), 10000);
    expect(bookClientServiceFee(lines, 1000), 1000);
    expect(
      bookExclusiveTotal(lines: lines, toolsFromProvider: false, clientServiceFeeBps: 1000),
      11000,
    );
  });
}
