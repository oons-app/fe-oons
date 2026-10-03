import 'package:oons/core/format.dart' show Loc;
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/models.dart';
import 'package:oons/features/pro/v2/services_model.dart';

Map<String, dynamic> row(String id, String ar, String vertical, String status, {String slug = ''}) => {
      'categoryId': id,
      'name': {'ar': ar, 'en': ar},
      'vertical': vertical,
      'status': status,
      'slug': slug.isEmpty ? id : slug,
    };

ServiceItem item(String id, String name, {String? cat, bool active = true, int price = 100000, String kind = 'standard', int from = 0}) => ServiceItem(
      id: id,
      name: Loc(name, name),
      duration: 120,
      price: price,
      categoryId: cat,
      kind: kind,
      active: active,
      sizeFromSqm: from,
    );

void main() {
  final rows = [
    row('c-reg', 'تنظيف عادي', 'cleaning', 'active'),
    row('c-post', 'تنظيف بعد التشطيب', 'cleaning', 'active'),
    row('b-hair', 'شعر', 'beauty', 'active'),
    row('b-nails', 'أظافر', 'beauty', 'pending_addition_approval'),
    row('b-brows', 'حواجب', 'beauty', 'rejected'),
    row('b-gone', 'تاتو', 'beauty', 'removed'),
  ];

  group('groupSpecialties', () {
    test('category → specialty → service, never one mixed list', () {
      final g = groupSpecialties(
        categoryRows: rows,
        items: [item('1', 'مميز', cat: 'c-reg'), item('2', 'شقة', cat: 'c-post'), item('3', 'قص', cat: 'b-hair'), item('4', 'بدكير', cat: 'b-nails')],
      );
      expect(g.map((x) => x.vertical), ['cleaning', 'beauty']);
      expect(g[0].specialties.map((s) => s.name.ar), ['تنظيف بعد التشطيب', 'تنظيف عادي']);
      final reg = g[0].specialties.firstWhere((s) => s.categoryId == 'c-reg');
      expect(reg.items.map((i) => i.id), ['1']);
      expect(g[1].specialties.firstWhere((s) => s.categoryId == 'b-hair').items.single.id, '3');
    });

    test('her own vertical comes first', () {
      final g = groupSpecialties(categoryRows: rows, items: const [], primaryVertical: 'beauty');
      expect(g.map((x) => x.vertical), ['beauty', 'cleaning']);
    });

    test('status: approved, pending, needs changes; removed ones are hidden', () {
      final g = groupSpecialties(categoryRows: rows, items: const []);
      final beauty = g.firstWhere((x) => x.vertical == 'beauty').specialties;
      expect(beauty.map((s) => s.status), [SpecialtyStatus.approved, SpecialtyStatus.pending, SpecialtyStatus.attention]);
      expect(beauty.any((s) => s.categoryId == 'b-gone'), isFalse);
    });

    test('a service with no category follows its name, then her first approved specialty', () {
      final g = groupSpecialties(
        categoryRows: rows,
        items: [item('1', 'شعر'), item('2', 'حاجة غريبة')],
      );
      final hair = g.expand((x) => x.specialties).firstWhere((s) => s.categoryId == 'b-hair');
      expect(hair.items.map((i) => i.id), ['1']);
      final first = g.expand((x) => x.specialties).firstWhere((s) => s.categoryId == 'c-reg');
      expect(first.items.map((i) => i.id), ['2'], reason: 'her first approved specialty, in the order the API lists them');
    });

    test('counts: services, visible; tiers split from services and sorted by size', () {
      final g = groupSpecialties(
        categoryRows: rows,
        items: [
          item('1', 'مميز', cat: 'c-reg'),
          item('2', 'مخفية', cat: 'c-reg', active: false),
          item('t2', 'شريحة 2', cat: 'c-reg', kind: 'cleaning', from: 181),
          item('t1', 'شريحة 1', cat: 'c-reg', kind: 'cleaning', from: 120),
        ],
      );
      final reg = g[0].specialties.firstWhere((s) => s.categoryId == 'c-reg');
      expect(reg.serviceCount, 4);
      expect(reg.visibleCount, 3);
      expect(reg.services.map((i) => i.id), ['1', '2']);
      expect(reg.tiers.map((i) => i.id), ['t1', 't2']);
      expect(reg.hasTiers, isTrue);
    });

    test('a specialty with no services still shows up', () {
      final g = groupSpecialties(categoryRows: rows, items: const []);
      expect(g.expand((x) => x.specialties).every((s) => s.items.isEmpty), isTrue);
      expect(g.expand((x) => x.specialties).length, 5);
    });
  });

  group('prices', () {
    test('the client pays her price plus the fee on top', () {
      expect(clientPaysEgp(1200, 0.10), 1320);
      expect(clientPaysEgp(800, 0.15), 920);
      expect(clientPaysEgp(715, 0.10), 787);
    });
    test('bulk change rounds to 5 and never goes below 5', () {
      expect(bulkPrice(1200, 1.1), 1320);
      expect(bulkPrice(1200, 0.9), 1080);
      expect(bulkPrice(900, 1.1), 990);
      expect(bulkPrice(13, 0.9), 10);
      expect(bulkPrice(5, 0.5), 5);
    });
  });

  test('vertical names and icons', () {
    expect(verticalName('cleaning', ar: true), 'التنظيف المنزلي');
    expect(verticalName('beauty', ar: true), 'التجميل والعناية');
    expect(verticalName('beauty', ar: false), 'Beauty & care');
    expect(verticalIcon('cleaning'), 'clean');
    expect(verticalIcon('beauty'), 'beauty');
  });
}
