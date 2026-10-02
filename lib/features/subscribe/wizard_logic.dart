import 'package:oons/features/subscribe/ar_eg.dart';

/// One of the provider's own cleaning services, as offered in the wizard.
///
/// [id] is the service item's OWN id (what the server stores in
/// `lines[].catalogItemId`); [catalogItemId] is the catalogue id it was created
/// from (stored as `lines[].itemId`). Edit-restore matches on either.
class PlanService {
  PlanService({
    required this.id,
    required this.name,
    required this.regularEgp,
    this.visitType = 'regular',
    this.catalogItemId = '',
  });
  final String id;
  final String name;
  final int regularEgp;
  final String visitType;
  final String catalogItemId;
}

/// A member of the provider's team, from `GET /pro/workers`.
class TeamMember {
  const TeamMember({required this.id, required this.name, this.rating, this.photoUrl});
  final String id;
  final String name;
  final double? rating;
  final String? photoUrl;

  static TeamMember? fromJson(Map<String, dynamic> w) {
    if (w['active'] == false) return null;
    final id = '${w['id'] ?? ''}';
    if (id.isEmpty) return null;
    final name = '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim();
    final r = (w['rating'] as num?)?.toDouble();
    final photo = '${w['photo'] ?? w['photoUrl'] ?? ''}'.trim();
    return TeamMember(id: id, name: name.isEmpty ? 'عضوة الفريق' : name, rating: r != null && r > 0 ? r : null, photoUrl: photo.isEmpty ? null : photo);
  }
}

const kMaxBenefits = 6;
const kMaxPerService = 12;
const kMaxPlanVisits = 12;
const kBenefitMaxLen = 60;

/// The whole wizard state as a plain object: every derived number and gate the
/// prototype computes in `renderVals`, with no widgets involved.
class PlanDraft {
  PlanDraft({required this.services, DateTime? now}) : start = defaultStartDate(now ?? DateTime.now());

  final List<PlanService> services;
  String? planId;

  /// Server status of the plan being edited ('' for a brand new plan).
  String status = '';
  String name = '';
  final Map<String, int> qty = {};

  /// What she typed per service (Latin digits). A missing key means "use the
  /// 10% suggestion", like `sp[v.k] === undefined` in the prototype.
  final Map<String, String> subRaw = {};
  final Set<int> days = {};
  String start;
  bool ongoing = true;
  String end = '';
  final List<String> benefits = [];
  String member = 'any';
  bool hasTeam = true;

  // --- identity of what is being edited ------------------------------------

  bool get isLive => status == 'published' || status == 'active';
  bool get isPaused => status == 'paused';

  /// Editing a plan customers can (or could) already see: a new version is
  /// created on save. Drafts being resumed are NOT editing.
  bool get editing => isLive || isPaused;

  // --- derived numbers ------------------------------------------------------

  int qtyOf(PlanService s) => qty[s.id] ?? 0;
  List<PlanService> get picked => services.where((s) => qtyOf(s) > 0).toList();
  int get totalQty => services.fold(0, (n, s) => n + qtyOf(s));
  int get ref => services.fold(0, (n, s) => n + qtyOf(s) * s.regularEgp);

  int unitOf(PlanService s) {
    final raw = subRaw[s.id];
    return raw != null ? priceFromRaw(raw) : defaultSubEgp(s.regularEgp);
  }

  int get price => services.fold(0, (n, s) => n + qtyOf(s) * unitOf(s));
  bool get allPriced => picked.every((s) => unitOf(s) > 0);
  int get save => ref - price;
  int get pct => savingPct(ref, price);
  bool get saves => save > 0 && price > 0;

  bool canInc(PlanService s) => qtyOf(s) < kMaxPerService && totalQty < kMaxPlanVisits;

  void setQty(PlanService s, int n) {
    var v = n.clamp(0, kMaxPerService);
    final others = totalQty - qtyOf(s);
    if (others + v > kMaxPlanVisits) v = kMaxPlanVisits - others;
    qty[s.id] = v < 0 ? 0 : v;
  }

  /// A quick chip is "selected" when every picked service sits exactly on that
  /// discount's suggestion.
  bool chipSelected(int pct) =>
      picked.isNotEmpty && picked.every((s) => unitOf(s) == defaultSubEgp(s.regularEgp, pct));

  void applyDiscount(int pct) {
    for (final s in services) {
      subRaw[s.id] = '${defaultSubEgp(s.regularEgp, pct)}';
    }
  }

  // --- gates ----------------------------------------------------------------

  bool get ok1 => totalQty > 0 && totalQty <= kMaxPlanVisits;
  bool get ok2 => price > 0 && allPriced;
  bool get endBad => !ongoing && (parseIso(end) == null || endBeforeStart(start, end));
  bool get ok3 => daysEnough(days.length, totalQty) && !endBad;
  bool get ready => ok1 && ok2 && ok3;

  bool okFor(int step) {
    switch (step) {
      case 1:
        return ok1;
      case 2:
        return ok2;
      case 3:
        return ok3;
      case 6:
        return ready;
      default:
        return true;
    }
  }

  /// First step that still needs her attention (used to resume a draft).
  int get firstIncompleteStep {
    if (!ok1) return 1;
    if (!ok2) return 2;
    if (!ok3) return 3;
    return 4;
  }

  // --- assignee -------------------------------------------------------------

  String get effectiveMember => hasTeam ? member : 'me';
  String get assigneeMode {
    final m = effectiveMember;
    return m == 'me' ? 'self' : m == 'any' ? 'any' : 'member';
  }

  String get assigneeId {
    final m = effectiveMember;
    return m == 'me' || m == 'any' ? '' : m;
  }

  // --- benefits -------------------------------------------------------------

  bool get benefitsFull => benefits.length >= kMaxBenefits;

  bool addBenefit(String raw) {
    final t = raw.trim();
    if (t.isEmpty || benefitsFull) return false;
    benefits.add(t.length > kBenefitMaxLen ? t.substring(0, kBenefitMaxLen) : t);
    return true;
  }

  // --- server round trip ----------------------------------------------------

  /// Request body for `POST /pro/plans`. The assignee is ALWAYS sent (the
  /// server replaces the whole document, so omitting it would drop the member).
  Map<String, dynamic> body({required String status, int? step, String nameFallback = ''}) => {
        if (planId != null) 'id': planId,
        'status': status,
        'name': name.trim().isEmpty ? nameFallback : name.trim(),
        'lines': [
          for (final s in picked)
            {
              'catalogItemId': s.id,
              if (s.catalogItemId.isNotEmpty) 'itemId': s.catalogItemId,
              'quantity': qtyOf(s),
              'visitType': s.visitType,
              'subPricePiastres': unitOf(s) * 100,
            }
        ],
        'weekdays': (days.toList()..sort()),
        'startDate': start,
        'endDate': ongoing ? '' : end,
        'ongoing': ongoing,
        'assigneeMode': assigneeMode,
        'assigneeId': assigneeId,
        'benefits': List<String>.from(benefits),
        if (step != null) 'step': step,
      };

  /// Fill the draft from a plan returned by `GET /pro/plans`.
  void restore(Map plan) {
    planId = '${plan['id']}';
    status = '${plan['status'] ?? ''}';
    name = '${plan['name'] ?? ''}';
    ongoing = plan['ongoing'] != false;
    final st = '${plan['startDate'] ?? ''}';
    if (parseIso(st) != null) start = st;
    end = '${plan['endDate'] ?? ''}';
    final mode = '${plan['assigneeMode'] ?? 'any'}';
    final aid = '${plan['assigneeId'] ?? ''}';
    member = mode == 'self' ? 'me' : (mode == 'member' && aid.isNotEmpty ? aid : 'any');
    days
      ..clear()
      ..addAll(((plan['weekdays'] as List?) ?? []).whereType<num>().map((n) => n.toInt()).where((i) => i >= 0 && i <= 6));
    benefits
      ..clear()
      ..addAll(((plan['benefits'] as List?) ?? []).map((b) => '$b').where((b) => b.trim().isNotEmpty));
    for (final raw in (plan['lines'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final own = '${raw['catalogItemId'] ?? ''}';
      final cat = '${raw['itemId'] ?? ''}';
      PlanService? svc;
      for (final s in services) {
        if ((own.isNotEmpty && (s.id == own || s.catalogItemId == own)) || (cat.isNotEmpty && (s.id == cat || s.catalogItemId == cat))) {
          svc = s;
          break;
        }
      }
      if (svc == null) continue;
      qty[svc.id] = (raw['quantity'] as num?)?.toInt() ?? 0;
      final sub = (raw['subPricePiastres'] as num?)?.toInt() ?? 0;
      if (sub > 0) subRaw[svc.id] = '${sub ~/ 100}';
    }
  }
}
