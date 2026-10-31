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

  test('a blank saved area stays blank (no silent Capital default)', () {
    final user = UserMe.fromJson({
      'id': 'u1',
      'phone': '01000000000',
      'firstName': {'en': 'Sara', 'ar': 'سارة'},
      'lastName': {'en': 'Ali', 'ar': 'علي'},
      'initials': {'en': 'SA', 'ar': 'سع'},
      'area': '',
    });
    expect(user.area, '');
  });

  group('live area catalogue', () {
    tearDown(liveAreas.clear);

    test('a console-created area gets its own name, centre and city', () {
      liveAreas['shorouk'] = const AreaInfo(
        name: Loc('El Shorouk', 'الشروق'),
        cityId: 'new_cairo',
        cityName: Loc('New Cairo', 'القاهرة الجديدة'),
        lat: 30.13,
        lng: 31.61,
        radiusM: 3000,
      );
      expect(areaName('shorouk', 'ar'), 'الشروق');
      expect(coordsForArea('shorouk'), (30.13, 31.61));
      expect(areaCityName('shorouk', 'en'), 'New Cairo');
      expect(areaIsGiza('shorouk'), isFalse);
    });

    test('offline, the fallback tables still answer', () {
      expect(areaName('madinaty', 'en'), 'Madinaty');
      expect(coordsForArea('madinaty'), (30.0917, 31.6306));
      expect(areaCityName('haram', 'en'), 'Giza');
    });
  });
}
