import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/subscribe/ar_eg.dart';
import 'package:oons/features/subscribe/draft_saver.dart';
import 'package:oons/features/subscribe/visit_ops.dart';
import 'package:oons/features/subscribe/wizard_logic.dart';

PlanService svcR() => PlanService(id: 'r', name: 'تنظيف عادي', regularEgp: 500);
PlanService svcD() => PlanService(id: 'd', name: 'تنظيف عميق', regularEgp: 1250, visitType: 'deep');
PlanService svcX() => PlanService(id: 'x', name: 'تنظيف عادي + مطبخ عميق', regularEgp: 1600);

PlanDraft draft({Map<String, int> qty = const {'r': 3, 'd': 1}}) {
  final d = PlanDraft(services: [svcR(), svcD(), svcX()], now: DateTime(2026, 10, 2));
  qty.forEach((k, v) => d.qty[k] = v);
  return d;
}

void main() {
  group('pricing', () {
    test('defaultSubEgp rounds half-up to 10 EGP', () {
      expect(defaultSubEgp(500), 450);
      expect(defaultSubEgp(1250), 1130); // 1125 -> 112.5 -> 113
      expect(defaultSubEgp(1600), 1440);
      expect(defaultSubEgp(500, 5), 480); // 475 -> 47.5 -> 48
      expect(defaultSubEgp(500, 15), 430); // 425 -> 42.5 -> 43
      expect(defaultSubEgp(1050), 950); // 945 -> 94.5 -> 95
      expect(defaultSubEgp(0), 0);
    });

    test('monthly / reference / saving / pct', () {
      final d = draft();
      d.subRaw['r'] = '450';
      d.subRaw['d'] = '1150';
      expect(d.ref, 2750); // 3*500 + 1250
      expect(d.price, 2500); // 3*450 + 1150
      expect(d.save, 250);
      expect(d.pct, 9); // round(250/2750*100)
      expect(d.saves, isTrue);
      expect(monthlyEgp([(qty: 3, sub: 450), (qty: 1, sub: 1150)]), 2500);
      expect(referenceEgp([(qty: 3, regular: 500), (qty: 1, regular: 1250)]), 2750);
      expect(savingPct(0, 0), 0);
      expect(savingPct(2750, 2500), 9);
      expect(arGrouped(2500), '٢٬٥٠٠');
      expect(arGrouped(2750), '٢٬٧٥٠');
    });

    test('per visit and net', () {
      expect(perVisitEgp(2500, 4), 625);
      expect(perVisitEgp(0, 0), isNull);
      expect(netEgp(2500), 2250);
      expect(netEgp(1800), 1620);
    });

    test('no-save copy covers every branch', () {
      expect(noSaveText(allPriced: false, price: 100, save: 10), contains('اكتبي سعر كل خدمة'));
      expect(noSaveText(allPriced: true, price: 0, save: 10), contains('اكتبي سعر الاشتراك'));
      expect(noSaveText(allPriced: true, price: 500, save: 0), contains('نفس الحجز بالزيارة'));
      expect(noSaveText(allPriced: true, price: 600, save: -100), 'السعر ده أعلى من الحجز بالزيارة بـ ١٠٠ ج.م.');
    });

    test('price note', () {
      expect(priceNote(500, 0), 'اكتبي السعر');
      expect(priceNote(500, 450), 'أقل ١٠٪');
      expect(priceNote(500, 600), 'أعلى من العادي');
      expect(priceNote(500, 500), 'نفس العادي');
    });
  });

  group('quick chips', () {
    test('default state selects the 10% chip', () {
      final d = draft();
      expect(d.chipSelected(10), isTrue);
      expect(d.chipSelected(5), isFalse);
      expect(d.chipSelected(15), isFalse);
    });

    test('applying a discount moves the selection and sets every row', () {
      final d = draft();
      d.applyDiscount(5);
      expect(d.unitOf(svcR()), 480);
      expect(d.unitOf(svcD()), defaultSubEgp(1250, 5));
      expect(d.chipSelected(5), isTrue);
      expect(d.chipSelected(10), isFalse);
      d.applyDiscount(15);
      expect(d.chipSelected(15), isTrue);
    });

    test('any manual edit deselects all chips; nothing picked selects none', () {
      final d = draft();
      d.subRaw['r'] = '460';
      expect(d.chipSelected(5), isFalse);
      expect(d.chipSelected(10), isFalse);
      expect(d.chipSelected(15), isFalse);
      final empty = draft(qty: const {});
      expect(empty.chipSelected(10), isFalse);
    });
  });

  group('plurals', () {
    test('visits', () {
      expect(visitsPhrase(1), 'زيارة واحدة');
      expect(visitsPhrase(2), 'زيارتين');
      expect(visitsPhrase(3), '٣ زيارات');
      expect(visitsPhrase(10), '١٠ زيارات');
      expect(visitsPhrase(11), '١١ زيارة');
      expect(visitsPhrase(12), '١٢ زيارة');
    });
    test('features', () {
      expect(featuresPhrase(1), 'ميزة واحدة');
      expect(featuresPhrase(2), 'ميزتين');
      expect(featuresPhrase(3), '٣ مميزات');
      expect(featuresPhrase(6), '٦ مميزات');
    });
    test('plans', () {
      expect(plansPhrase(1), 'باقة واحدة');
      expect(plansPhrase(2), 'باقتين');
      expect(plansPhrase(3), '٣ باقات');
      expect(plansPhrase(10), '١٠ باقات');
      expect(plansPhrase(11), '١١ باقة');
    });
  });

  group('weekday fit text', () {
    test('no days', () => expect(fitLine(0, 4), 'اختاري يوم واحد على الأقل'));
    const ok = '✓ العميلة هتختار يوم وفترة لكل زيارة من الأيام دي — الصبح من ٩ أو بعد الضهر من ٢';
    test('enough, one day for four visits', () => expect(fitLine(1, 4), ok));
    test('enough, extra days are fine — the customer chooses', () => expect(fitLine(3, 4), ok));
    test('not enough days for the visits', () => expect(fitLine(1, 5), 'الأيام دي مش كفاية لـ ٥ زيارات — زوّدي أيام عشان العميلة تلاقي مكان لكل زيارة'));
    test('not enough, eleven plus', () => expect(fitLine(2, 11), 'الأيام دي مش كفاية لـ ١١ زيارة — زوّدي أيام عشان العميلة تلاقي مكان لكل زيارة'));
    test('daysEnough', () {
      expect(daysEnough(0, 0), isFalse);
      expect(daysEnough(1, 4), isTrue);
      expect(daysEnough(1, 5), isFalse);
      expect(daysEnough(2, 8), isTrue);
    });
    test('days line', () {
      expect(daysLine({3}), 'التلات');
      expect(daysLine({3, 0}), 'السبت والتلات');
      expect(daysLine({}), '—');
    });
    test('plan weekday maps Saturday to 0 and Friday to 6', () {
      expect(planWeekday(DateTime(2026, 10, 10)), 0); // Saturday
      expect(planWeekday(DateTime(2026, 10, 9)), 6); // Friday
      expect(planWeekday(DateTime(2026, 10, 11)), 1); // Sunday
    });
  });

  group('digits', () {
    test('Arabic-Indic and Latin normalise to Latin', () {
      expect(normalizeDigits('٤٥٠'), '450');
      expect(normalizeDigits('450'), '450');
      expect(normalizeDigits('٤5٠'), '450');
      expect(normalizeDigits('۱۲۳'), '123');
      expect(normalizeDigits('4a5.0 ج'), '450');
    });
    test('typing 0 stays 0 and counts as no price', () {
      expect(normalizeDigits('0'), '0');
      expect(normalizeDigits('٠'), '0');
      expect(priceFromRaw('0'), 0);
      expect(priceFromRaw(''), 0);
      final d = draft();
      d.subRaw['r'] = normalizeDigits('٠');
      expect(d.unitOf(svcR()), 0);
      expect(d.ok2, isFalse);
    });
    test('length is capped', () {
      expect(normalizeDigits('1234567890'), '12345');
      expect(normalizeDigits('1234567890', maxLen: 3), '123');
    });
    test('formatter shows Arabic-Indic digits and keeps the caret', () {
      const f = ArDigitsFormatter();
      final out = f.formatEditUpdate(
        const TextEditingValue(text: '٤٥', selection: TextSelection.collapsed(offset: 1)),
        const TextEditingValue(text: '٤7٥', selection: TextSelection.collapsed(offset: 2)),
      );
      expect(out.text, '٤٧٥');
      expect(out.selection.baseOffset, 2);
      final junk = f.formatEditUpdate(
        const TextEditingValue(text: '٤٥'),
        const TextEditingValue(text: '٤x٥', selection: TextSelection.collapsed(offset: 3)),
      );
      expect(junk.text, '٤٥');
      expect(junk.selection.baseOffset, 2);
      final capped = f.formatEditUpdate(
        const TextEditingValue(text: '١٢٣٤٥'),
        const TextEditingValue(text: '١٢٣٤٥٦', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(capped.text, '١٢٣٤٥');
    });
  });

  group('dates', () {
    test('default start is computed: today + 7', () {
      expect(defaultStartDate(DateTime(2026, 10, 2, 15, 30)), '2026-10-09');
      expect(defaultStartDate(DateTime(2026, 12, 28)), '2027-01-04');
      expect(draft().start, '2026-10-09');
    });
    test('nice date line', () {
      expect(niceDate('2026-10-10'), 'السبت، ١٠ أكتوبر ٢٠٢٦');
      expect(niceDate('2026-01-01'), 'الخميس، ١ يناير ٢٠٢٦');
      expect(niceDate(''), '—');
      expect(shortDate('2026-10-10'), '٢٠٢٦/١٠/١٠');
    });
    test('end must be strictly after start', () {
      expect(endBeforeStart('2026-10-10', '2026-10-10'), isTrue);
      expect(endBeforeStart('2026-10-10', '2026-10-09'), isTrue);
      expect(endBeforeStart('2026-10-10', '2026-10-11'), isFalse);
      expect(endBeforeStart('2026-10-10', ''), isFalse);
      // ISO strings with different month widths must not be string-compared.
      expect(endBeforeStart('2026-09-30', '2026-10-01'), isFalse);
    });
    test('end line copy', () {
      expect(endNiceLine('2026-10-10', ''), 'اختاري تاريخ النهاية');
      expect(endNiceLine('2026-10-10', '2026-10-01'), 'لازم يكون بعد تاريخ البداية');
      expect(endNiceLine('2026-10-10', '2026-11-01'), 'الأحد، ١ نوفمبر ٢٠٢٦');
    });
    test('ongoing and ended lines', () {
      expect(endLine(ongoing: true, end: ''), 'مستمرة من غير نهاية');
      expect(endLine(ongoing: false, end: ''), 'من غير تاريخ نهاية');
      expect(endLine(ongoing: false, end: '2026-11-01'), 'لحد الأحد، ١ نوفمبر ٢٠٢٦');
    });
    test('disabled step-3 label', () {
      expect(step3DisabledLabel(hasDays: false), 'اختاري يوم الزيارة');
      expect(step3DisabledLabel(hasDays: true), 'حددي تاريخ النهاية');
    });
  });

  group('step gating', () {
    test('ok1 needs at least one visit and at most twelve', () {
      final d = draft(qty: const {});
      expect(d.ok1, isFalse);
      d.setQty(svcR(), 1);
      expect(d.ok1, isTrue);
      d.setQty(svcR(), 12);
      expect(d.totalQty, 12);
      expect(d.canInc(svcR()), isFalse);
      d.setQty(svcD(), 3); // total would be 15: clamped to the cap
      expect(d.totalQty, 12);
      expect(d.qtyOf(svcD()), 0);
    });
    test('ok2 needs every picked service priced', () {
      final d = draft();
      expect(d.ok2, isTrue);
      d.subRaw['d'] = '';
      expect(d.allPriced, isFalse);
      expect(d.ok2, isFalse);
      d.subRaw['d'] = '1000';
      expect(d.ok2, isTrue);
      // an un-picked service with no price does not block
      d.subRaw['x'] = '';
      expect(d.ok2, isTrue);
    });
    test('ok3 needs a day, and an end after start when not ongoing', () {
      final d = draft();
      expect(d.ok3, isFalse);
      d.days.add(3);
      expect(d.ok3, isTrue);
      d.ongoing = false;
      expect(d.ok3, isFalse); // no end date yet
      d.end = '2026-10-01';
      expect(d.endBad, isTrue);
      expect(d.ok3, isFalse);
      d.end = '2026-12-01';
      expect(d.ok3, isTrue);
      d.ongoing = true;
      d.end = '';
      expect(d.ok3, isTrue);
    });
    test('ready and per-step gates', () {
      final d = draft();
      d.days.add(0);
      expect(d.ready, isTrue);
      expect(d.okFor(4), isTrue);
      expect(d.okFor(5), isTrue);
      expect(d.okFor(6), isTrue);
      d.days.clear();
      expect(d.okFor(6), isFalse);
      expect(d.firstIncompleteStep, 3);
    });
    test('publish label', () {
      expect(publishLabel(editing: false), 'انشري الباقة');
      expect(publishLabel(editing: true), 'احفظي ونشري التعديل');
    });
  });

  group('benefits', () {
    test('add trims, caps length and stops at six', () {
      final d = draft();
      expect(d.addBenefit('   '), isFalse);
      expect(d.addBenefit('  نفس المنظّفة  '), isTrue);
      expect(d.benefits.single, 'نفس المنظّفة');
      expect(d.addBenefit('ا' * 80), isTrue);
      expect(d.benefits.last.length, kBenefitMaxLen);
      for (var i = 0; i < 4; i++) {
        expect(d.addBenefit('ميزة $i'), isTrue);
      }
      expect(d.benefits.length, 6);
      expect(d.benefitsFull, isTrue);
      expect(d.addBenefit('زيادة'), isFalse);
    });
  });

  group('request body and restore', () {
    test('body always carries the assignee, and no end date when ongoing', () {
      final d = draft();
      d.days.addAll({3, 0});
      d.member = 'w42';
      d.end = '2026-12-01';
      final b = d.body(status: 'draft');
      expect(b['assigneeMode'], 'member');
      expect(b['assigneeId'], 'w42');
      expect(b['endDate'], '');
      expect(b['ongoing'], true);
      expect(b['weekdays'], [0, 3]);
      expect((b['lines'] as List).length, 2);
      expect((b['lines'] as List).first['subPricePiastres'], 45000);
      d.member = 'any';
      expect(d.body(status: 'draft')['assigneeMode'], 'any');
      expect(d.body(status: 'draft')['assigneeId'], '');
      d.hasTeam = false;
      d.member = 'w42';
      expect(d.body(status: 'draft')['assigneeMode'], 'self');
      d.ongoing = false;
      expect(d.body(status: 'draft')['endDate'], '2026-12-01');
      expect(draft(qty: const {}).body(status: 'draft', nameFallback: 'باقة')['name'], 'باقة');
    });

    test('restore matches lines by the item own id or the catalogue id', () {
      final d = PlanDraft(services: [
        PlanService(id: 'item-1', catalogItemId: 'cat-regular', name: 'تنظيف عادي', regularEgp: 500),
        PlanService(id: 'item-2', catalogItemId: 'cat-deep', name: 'تنظيف مميز', regularEgp: 1250, visitType: 'deep'),
      ], now: DateTime(2026, 10, 2));
      d.restore({
        'id': 'p1',
        'status': 'published',
        'name': 'نضافة شاملة',
        'assigneeMode': 'member',
        'assigneeId': 'w9',
        'weekdays': [0, 3],
        'startDate': '2026-10-20',
        'ongoing': false,
        'endDate': '2027-01-01',
        'benefits': ['أ', 'ب'],
        'lines': [
          {'catalogItemId': 'item-1', 'itemId': 'cat-regular', 'quantity': 2, 'subPricePiastres': 45000},
          {'catalogItemId': 'item-2', 'quantity': 1, 'subPricePiastres': 115000},
        ],
      });
      expect(d.planId, 'p1');
      expect(d.editing, isTrue);
      expect(d.qty['item-1'], 2);
      expect(d.qty['item-2'], 1);
      expect(d.unitOf(d.services[0]), 450);
      expect(d.unitOf(d.services[1]), 1150);
      expect(d.member, 'w9');
      expect(d.days, {0, 3});
      expect(d.start, '2026-10-20');
      expect(d.ongoing, isFalse);
      expect(d.end, '2027-01-01');
      expect(d.benefits, ['أ', 'ب']);
      // line saved against the catalogue id only
      final d2 = PlanDraft(services: [PlanService(id: 'item-1', catalogItemId: 'cat-regular', name: 'ع', regularEgp: 500)], now: DateTime(2026, 10, 2));
      d2.restore({'id': 'p2', 'status': 'draft', 'lines': [{'itemId': 'cat-regular', 'quantity': 3}]});
      expect(d2.qty['item-1'], 3);
      expect(d2.editing, isFalse);
    });

    test('visit type follows the server rule', () {
      expect(visitTypeForName('تنظيف مميز'), 'deep');
      expect(visitTypeForName('تنظيف عميق'), 'deep');
      expect(visitTypeForName('تنظيف عادي + مطبخ عميق'), 'regular');
      expect(visitTypeForName('تنظيف عادي'), 'regular');
      expect(visitTypeForName('أي حاجة', id: 'cleaning_deep'), 'deep');
      expect(visitTypeForName('تنظيف مميز', declared: 'regular'), 'regular');
    });
  });

  group('status copy', () {
    test('plan status chips', () {
      expect(planStatusLabel('published'), 'متاحة');
      expect(planStatusLabel('active'), 'متاحة');
      expect(planStatusLabel('paused'), 'متوقّفة');
      expect(planStatusLabel('draft'), 'مسودة');
      expect(planStatusLabel('archived'), 'مؤرشفة');
    });
    test('visit type tags and subscriber statuses', () {
      expect(visitTypeLabel('deep'), 'تنظيف مميز');
      expect(visitTypeLabel('regular'), 'صيانة · تنظيف عادي');
      expect(subscriberStatusLabel('active'), 'نشطة');
      expect(subscriberStatusLabel('at_risk'), 'معرّضة للإلغاء');
      expect(subscriberStatusLabel('paused'), 'متوقّفة');
      expect(usedOfMinimum(2, 4), '٢ / ٤');
    });
  });

  group('week model', () {
    test('reads the contract shape and the older one', () {
      final a = WeekData.from({
        'capacityPerDay': 3,
        'days': [
          {'date': '2026-10-02', 'count': 2}
        ],
        'visits': [
          {'id': 'v1', 'date': '2026-10-02', 'time': '10:00', 'firstName': 'منى', 'area': 'الزمالك', 'type': 'deep', 'status': 'confirmed'},
          {'id': 'v2', 'date': '2026-10-02', 'time': '12:00', 'firstName': 'سلمى', 'area': 'مصر الجديدة', 'type': 'regular', 'status': 'pending'},
        ],
      });
      expect(a.capacity, 3);
      expect(a.visits[0].type, 'deep');
      expect(a.visits[0].confirmed, isTrue);
      expect(a.visits[1].confirmed, isFalse);
      final b = WeekData.from({
        'capacity': 5,
        'days': [
          {'date': '2026-10-02', 'count': 1, 'capacity': 5}
        ],
        'visits': [
          {'id': 'v3', 'date': '2026-10-02', 'time': '10:00', 'firstName': 'منى', 'visitType': 'deep', 'confirmed': true, 'status': 'booked'}
        ],
      });
      expect(b.capacity, 5);
      expect(b.visits.single.type, 'deep');
      expect(b.visits.single.confirmed, isTrue);
      expect(WeekData.from({'days': []}).capacity, 4);
    });

    test('subscriber row', () {
      final r = SubscriberRow.from({'id': 's1', 'firstName': 'منى', 'planTitle': 'نضافة شاملة', 'used': 1, 'minimum': 4, 'status': 'active'});
      expect(r.firstName, 'منى');
      expect(r.planTitle, 'نضافة شاملة');
      final old = SubscriberRow.from({'id': 's2', 'name': 'سلمى أحمد', 'status': 'active', 'atRisk': true, 'plan': [
        {'name': {'ar': 'تنظيف عادي'}, 'quantity': 4}
      ]});
      expect(old.firstName, 'سلمى');
      expect(old.status, 'at_risk');
      expect(old.planTitle, '٤ تنظيف عادي');
    });
  });

  group('DraftSaver', () {
    test('serialises sends and coalesces edits made while one is in flight', () async {
      var inFlight = 0, maxInFlight = 0, sends = 0;
      String? planId;
      final ids = <String?>[];
      late DraftSaver saver;
      saver = DraftSaver(
        delay: const Duration(milliseconds: 10),
        send: () async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          ids.add(planId);
          sends++;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          planId ??= 'p1';
          inFlight--;
        },
      );
      saver.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 25)); // first send now in flight
      saver.schedule();
      saver.schedule();
      saver.schedule();
      await saver.flush();
      expect(maxInFlight, 1);
      expect(sends, 2); // first + ONE coalesced follow-up
      expect(ids, [null, 'p1']); // the second send already knows the id
      saver.dispose();
    });

    test('failure is remembered, reported and retried by flush', () async {
      var fail = true;
      final states = <DraftSaveState>[];
      final saver = DraftSaver(
        delay: const Duration(milliseconds: 5),
        onState: states.add,
        send: () async {
          if (fail) throw StateError('boom');
        },
      );
      saver.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(saver.lastError, isNotNull);
      expect(states.last, DraftSaveState.failed);
      fail = false;
      await saver.flush();
      expect(saver.lastError, isNull);
      expect(states.last, DraftSaveState.saved);
      saver.dispose();
    });
  });
}
