import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/subscribe/prov_api.dart';
import 'package:oons/features/subscribe/wizard_logic.dart';

class Call {
  Call(this.method, this.path, this.data, this.query);
  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic>? query;
  Map<String, dynamic> get body => Map<String, dynamic>.from(data as Map);
  @override
  String toString() => '$method $path';
}

typedef FakeRoute = Object? Function(Call c);

/// A scriptable [ProApi]: register `routes['POST /pro/plans'] = (c) => {...}`.
class FakeApi implements ProApi {
  final calls = <Call>[];
  final routes = <String, FakeRoute>{};
  Duration latency = Duration.zero;

  List<Call> where(String method, String path) => calls.where((c) => c.method == method && c.path == path).toList();

  Future<Map<String, dynamic>> _do(String method, String path, {Object? data, Map<String, dynamic>? query}) async {
    final c = Call(method, path, data, query);
    calls.add(c);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final h = routes['$method $path'];
    if (h == null) throw ApiException(404, 'مش موجود');
    final r = h(c);
    if (r is Exception) throw r;
    return Map<String, dynamic>.from(r as Map);
  }

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _do('GET', path, query: query);
  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) => _do('POST', path, data: data);
  @override
  Future<Map<String, dynamic>> delete(String path) => _do('DELETE', path);
}

List<PlanService> testServices() => [
      PlanService(id: 'item-r', catalogItemId: 'cat-r', name: 'تنظيف عادي', regularEgp: 500),
      PlanService(id: 'item-d', catalogItemId: 'cat-d', name: 'تنظيف مميز', regularEgp: 1250, visitType: 'deep'),
      PlanService(id: 'item-x', catalogItemId: 'cat-x', name: 'تنظيف عادي + مطبخ عميق', regularEgp: 1600),
    ];

Map<String, dynamic> worker(String id, String first, {String last = '', bool active = true, double? rating}) =>
    {'id': id, 'firstName': first, 'lastName': last, 'active': active, if (rating != null) 'rating': rating};

/// The app shell tests run in: Arabic locale + the Material delegates the real
/// app provides (the date picker needs them).
Widget arabicHost(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

void phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Plan JSON as GET /pro/plans returns it.
Map<String, dynamic> planRow({
  String id = 'p1',
  String status = 'published',
  String name = 'الأساسيات الأسبوعية',
  List<Map<String, dynamic>>? lines,
  int pricePiastres = 180000,
  int paygPiastres = 200000,
  int subscribers = 0,
  String assigneeMode = 'any',
  String assigneeId = '',
  List<int> weekdays = const [3],
  String startDate = '2026-10-20',
  bool ongoing = true,
  String endDate = '',
  List<String> benefits = const [],
  Map<String, dynamic> extra = const {},
}) =>
    {
      'plan': {
        'id': id,
        'status': status,
        'name': name,
        'lines': lines ??
            [
              {'catalogItemId': 'item-r', 'itemId': 'cat-r', 'name': {'ar': 'تنظيف عادي'}, 'quantity': 4, 'visitType': 'regular', 'subPricePiastres': 45000, 'pricePiastres': 50000},
            ],
        'pricePiastres': pricePiastres,
        'assigneeMode': assigneeMode,
        'assigneeId': assigneeId,
        'weekdays': weekdays,
        'startDate': startDate,
        'ongoing': ongoing,
        'endDate': endDate,
        'benefits': benefits,
        ...extra,
      },
      'quote': {'pricePiastres': pricePiastres, 'paygPiastres': paygPiastres},
      'subscriberCount': subscribers,
    };
