import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/plan_models.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// Visit tag as in the prototype: اتعملت / جاية / اتخطّتيها (+ states it does not draw).
enum VisitTag { done, next, skipped, needsDate, forfeited, cancelled }

VisitTag visitTagFor(String status) {
  switch (status) {
    case 'done':
    case 'completed':
      return VisitTag.done;
    case 'skipped':
      return VisitTag.skipped;
    case 'needs_date':
      return VisitTag.needsDate;
    case 'forfeited':
      return VisitTag.forfeited;
    case 'cancelled':
    case 'released':
      return VisitTag.cancelled;
    default:
      return VisitTag.next; // booked | scheduled | confirmed | held
  }
}

String visitTagLabel(VisitTag t) => switch (t) {
      VisitTag.done => 'اتعملت',
      VisitTag.next => 'جاية',
      VisitTag.skipped => 'اتخطّتيها',
      VisitTag.needsDate => 'محتاجة يوم',
      VisitTag.forfeited => 'ضاعت',
      VisitTag.cancelled => 'اتلغت',
    };

/// Statuses the skip button accepts (server: booked | scheduled | confirmed).
bool isUpcomingStatus(String s) => s == 'booked' || s == 'scheduled' || s == 'confirmed';

class MyVisit {
  const MyVisit({
    required this.id,
    required this.status,
    required this.type,
    required this.typeName,
    required this.date,
    required this.time,
    required this.timeLabel,
    required this.isMakeup,
    required this.makeupReason,
    required this.canSkip,
    required this.canReschedule,
    required this.canPlace,
  });

  final String id;
  final String status;
  final String type;
  final String typeName;
  final DateTime? date;
  final String time;
  final String timeLabel;
  final bool isMakeup;
  final String makeupReason;
  final bool canSkip;
  final bool canReschedule;
  final bool canPlace;

  VisitTag get tag => visitTagFor(status);
  bool get upcoming => isUpcomingStatus(status);

  /// `السبت ٣ أكتوبر · ١١ ص`, or a plain note when the visit has no date yet.
  String get when {
    final d = date;
    if (d == null) return 'لسه من غير ميعاد';
    final t = timeLabel.isNotEmpty ? timeLabel : (time.isNotEmpty ? slotLabelAr(time) : '');
    return t.isEmpty ? dateLabelAr(d) : '${dateLabelAr(d)} · $t';
  }

  /// Type line, with the make-up suffix on replacement visits.
  String get typeLine {
    if (!isMakeup) return typeName;
    return '$typeName · ${makeupReason == 'provider_cancelled' ? 'بدل اللي اتلغت' : 'بدل اللي اتخطّت'}';
  }
}

class MyPlan {
  const MyPlan({
    required this.id,
    required this.status,
    required this.title,
    required this.providerName,
    required this.visits,
    required this.used,
    required this.minimum,
    required this.cycleStart,
    required this.cycleEnd,
    required this.cycleId,
    required this.makeupDeadline,
    required this.paused,
    required this.pauseScheduled,
    required this.cyclePaid,
    this.receiptWaiting = false,
  });

  final String id;
  final String status;
  final String title;
  final String providerName;
  final List<MyVisit> visits;
  final int used;
  final int minimum;
  final DateTime? cycleStart;
  final DateTime? cycleEnd;
  final String cycleId;
  final DateTime? makeupDeadline;
  final bool paused;
  final bool pauseScheduled;
  final bool cyclePaid;

  /// She already uploaded the InstaPay screenshot. Ops still has to confirm it.
  final bool receiptWaiting;

  /// First upcoming (booked) visit by date.
  MyVisit? get nextVisit {
    final up = visits.where((v) => v.upcoming && v.date != null).toList()..sort((a, b) => a.date!.compareTo(b.date!));
    return up.isEmpty ? null : up.first;
  }

  MyVisit? get pendingMakeup {
    for (final v in visits) {
      if (v.status == 'needs_date') return v;
    }
    return null;
  }

  /// Upcoming visit that can be skipped (server rules decide the final answer).
  MyVisit? get skippable {
    final n = nextVisit;
    if (n != null && n.canSkip) return n;
    for (final v in visits) {
      if (v.upcoming && v.canSkip) return v;
    }
    return n;
  }

  /// `N من M زيارات اتعملت الدورة دي`
  String get usedLabel => '${toArabicDigits_(used)} من ${toArabicDigits_(minimum)} زيارات اتعملت الدورة دي';

  /// `الدورة: ١ أكتوبر لحد ٣٠ أكتوبر`
  String get cycleLong {
    if (cycleStart == null || cycleEnd == null) return '';
    return 'الدورة: ${dateShortAr(cycleStart!)} لحد ${dateShortAr(cycleEnd!)}';
  }

  factory MyPlan.fromResponse(Map<String, dynamic> r) {
    final sub = r['subscription'] is Map ? Map<String, dynamic>.from(r['subscription'] as Map) : <String, dynamic>{};
    final cycle = r['cycle'] is Map ? Map<String, dynamic>.from(r['cycle'] as Map) : <String, dynamic>{};
    final snap = sub['planSnapshot'] is Map ? Map<String, dynamic>.from(sub['planSnapshot'] as Map) : <String, dynamic>{};
    final lines = [
      for (final l in (snap['lines'] as List? ?? const []))
        if (l is Map) PlanLine.fromJson(l),
    ];
    String nameFor(String type, String catalogId) {
      for (final l in lines) {
        if (catalogId.isNotEmpty && l.catalogItemId == catalogId) return l.fullName;
      }
      for (final l in lines) {
        if ((type == 'deep') == l.deep) return l.fullName;
      }
      return type == 'deep' ? 'تنظيف مميز' : 'تنظيف عادي';
    }

    final raw = (r['visits'] as List?) ?? (sub['visits'] as List?) ?? const [];
    final visits = <MyVisit>[
      for (final v in raw)
        if (v is Map)
          MyVisit(
            id: '${v['id'] ?? ''}',
            status: '${v['status'] ?? ''}',
            type: '${v['type'] ?? v['visitType'] ?? ''}',
            typeName: nameFor('${v['type'] ?? v['visitType'] ?? ''}', '${v['catalogItemId'] ?? ''}'),
            date: parseYmd(v['date']),
            time: '${v['time'] ?? ''}',
            timeLabel: '${v['timeLabel'] ?? ''}',
            isMakeup: v['isMakeup'] == true,
            makeupReason: '${v['makeupReason'] ?? ''}',
            canSkip: v['canSkip'] == true,
            canReschedule: v['canReschedule'] == true,
            canPlace: v['canPlace'] == true,
          ),
    ];
    // Regular visits first (server order), make-ups after them.
    final ordered = [...visits.where((v) => !v.isMakeup), ...visits.where((v) => v.isMakeup)];
    final planned = ordered.where((v) => !v.isMakeup).length;
    final title = '${sub['title'] ?? ''}'.isNotEmpty ? '${sub['title']}' : planTitleFor(lines);
    return MyPlan(
      id: '${sub['id'] ?? ''}',
      status: '${sub['status'] ?? ''}',
      title: title,
      providerName: '${sub['providerName'] ?? ''}',
      visits: ordered,
      used: sub['used'] != null ? _i(sub['used']) : ordered.where((v) => v.tag == VisitTag.done && !v.isMakeup).length,
      minimum: sub['minimum'] != null ? _i(sub['minimum']) : planned,
      cycleStart: parseYmd(cycle['startsOn']),
      cycleEnd: parseYmd(cycle['endsOn']),
      cycleId: '${cycle['id'] ?? ''}',
      makeupDeadline: parseYmd(sub['makeupDeadline']),
      paused: sub['status'] == 'paused',
      pauseScheduled: sub['pauseScheduled'] == true,
      cyclePaid: '${cycle['status'] ?? 'paid'}' == 'paid',
      receiptWaiting: '${sub['paymentReceiptUrl'] ?? ''}'.trim().isNotEmpty && '${sub['status'] ?? ''}' == 'pending_payment',
    );
  }
}

String toArabicDigits_(int n) => arNum(n);
