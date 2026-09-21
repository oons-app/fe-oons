import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/system/nearest_match.dart';

void main() {
  const names = ['بديكير ومانيكير', 'تنظيف بشرة', 'قص شعر', 'تنظيف عادي', 'مكياج'];

  test('the design-system example resolves to the real nearest service', () {
    expect(nearestByName('باديكير جل', names, (n) => n), 'بديكير ومانيكير');
  });

  test('spelling variants and diacritics still match', () {
    expect(nearestByName('مكيّاج', names, (n) => n), 'مكياج');
    expect(nearestByName('تنضيف بشره', names, (n) => n), 'تنظيف بشرة');
  });

  test('stays silent instead of inventing a suggestion', () {
    expect(nearestByName('xyz123', names, (n) => n), isNull);
    expect(nearestByName('', names, (n) => n), isNull);
    expect(nearestByName('سباكة', const <String>[], (n) => n), isNull);
  });
}
