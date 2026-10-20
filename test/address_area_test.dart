import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/models.dart';

void main() {
  test('a pin in the Administrative Capital stays capital', () {
    expect(liveAreaForPin(30.02, 31.74, const ['madinaty', 'rehab', 'capital']), 'capital');
  });

  test('an empty catalog still defaults to the Administrative Capital', () {
    expect(liveAreaForPin(30.06, 31.22, const []), 'capital');
  });

  test('a blank saved area is the Administrative Capital', () {
    final user = UserMe.fromJson({
      'id': 'u1',
      'phone': '01000000000',
      'firstName': {'en': 'Sara', 'ar': 'سارة'},
      'lastName': {'en': 'Ali', 'ar': 'علي'},
      'initials': {'en': 'SA', 'ar': 'سع'},
      'area': '',
    });
    expect(user.area, 'capital');
  });
}
