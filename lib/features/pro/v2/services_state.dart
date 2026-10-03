import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/v2/services_model.dart';

/// What the services tab and the specialty page share, so they never load twice
/// and never disagree. Her services themselves live on the signed-in provider
/// (`sessionProvider`); this adds her specialty rows, the catalogue/commission
/// and the optimistic overrides that are in flight.
class ProServicesState {
  const ProServicesState({
    this.loaded = false,
    this.failed = false,
    this.categoryRows = const [],
    this.catalog = const {},
    this.commissionRate = 0.10,
    this.activeOverride = const {},
    this.priceOverride = const {},
  });

  final bool loaded;
  final bool failed;
  final List<Map<String, dynamic>> categoryRows;
  final Map<String, dynamic> catalog;
  final double commissionRate;

  /// service id → visibility she just chose (not yet confirmed by the server).
  final Map<String, bool> activeOverride;

  /// service id → price in piastres she just chose.
  final Map<String, int> priceOverride;

  ProServicesState copyWith({
    bool? loaded,
    bool? failed,
    List<Map<String, dynamic>>? categoryRows,
    Map<String, dynamic>? catalog,
    double? commissionRate,
    Map<String, bool>? activeOverride,
    Map<String, int>? priceOverride,
  }) =>
      ProServicesState(
        loaded: loaded ?? this.loaded,
        failed: failed ?? this.failed,
        categoryRows: categoryRows ?? this.categoryRows,
        catalog: catalog ?? this.catalog,
        commissionRate: commissionRate ?? this.commissionRate,
        activeOverride: activeOverride ?? this.activeOverride,
        priceOverride: priceOverride ?? this.priceOverride,
      );

  /// Specialties she can put services under (approved ones).
  List<Map<String, dynamic>> get approvedRows => categoryRows.where((r) => '${r['status']}' == 'active').toList();
}

class ProServicesController extends StateNotifier<ProServicesState> {
  ProServicesController(this._ref) : super(const ProServicesState());
  final Ref _ref;

  Future<void> load({bool quiet = false}) async {
    if (!quiet) state = state.copyWith(failed: false);
    try {
      final repo = _ref.read(repoProvider);
      final rows = await repo.proCategories();
      var catalog = <String, dynamic>{};
      try {
        catalog = await repo.proCatalog();
      } catch (_) {}
      state = state.copyWith(
        loaded: true,
        failed: false,
        categoryRows: rows,
        catalog: catalog,
        commissionRate: (catalog['commissionRate'] as num?)?.toDouble() ?? state.commissionRate,
      );
    } catch (_) {
      state = state.copyWith(loaded: true, failed: !state.loaded || state.categoryRows.isEmpty);
    }
  }

  void setActiveOverride(String id, bool? v) {
    final m = Map<String, bool>.of(state.activeOverride);
    v == null ? m.remove(id) : m[id] = v;
    state = state.copyWith(activeOverride: m);
  }

  void setPriceOverride(String id, int? piastres) {
    final m = Map<String, int>.of(state.priceOverride);
    piastres == null ? m.remove(id) : m[id] = piastres;
    state = state.copyWith(priceOverride: m);
  }

  void clearOverrides() => state = state.copyWith(activeOverride: const {}, priceOverride: const {});
}

final proServicesProvider = StateNotifierProvider<ProServicesController, ProServicesState>((ref) => ProServicesController(ref));

/// Her specialties grouped by category, with in-flight changes already applied.
final proGroupsProvider = Provider<List<ProCategoryGroup>>((ref) {
  final st = ref.watch(proServicesProvider);
  final me = ref.watch(sessionProvider).provider;
  final lang = ref.watch(localeProvider).languageCode;
  final items = [
    for (final it in me?.items ?? const <ServiceItem>[])
      st.activeOverride.containsKey(it.id) || st.priceOverride.containsKey(it.id)
          ? it.copyWith(active: st.activeOverride[it.id], price: st.priceOverride[it.id])
          : it,
  ];
  return groupSpecialties(categoryRows: st.categoryRows, items: items, primaryVertical: me?.service ?? '', lang: lang);
});

/// One specialty by category id (null when it is gone).
final proSpecialtyProvider = Provider.family<ProSpecialty?, String>((ref, categoryId) {
  for (final g in ref.watch(proGroupsProvider)) {
    for (final s in g.specialties) {
      if (s.categoryId == categoryId) return s;
    }
  }
  return null;
});
