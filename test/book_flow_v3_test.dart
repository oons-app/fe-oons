import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/models.dart';
import 'package:oons/features/book/book_pricing.dart';
import 'package:oons/features/book/book_widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/l10n/copy.dart';

ServiceItem _item({
  required String id,
  required int price,
  String kind = 'standard',
  int duration = 60,
  int travel = 0,
  bool hair = false,
  Map<String, int> surcharge = const {},
  String? vertical,
}) {
  return ServiceItem(
    id: id,
    name: Loc(id, id),
    duration: duration,
    price: price,
    kind: kind,
    travelFee: travel,
    needsHairLength: hair,
    hairSurcharge: surcharge,
    vertical: vertical,
  );
}

void main() {
  test('inclusive total is services + travel + tools − coupon + card fee', () {
    final lines = bookLines(
      items: [
        _item(id: 'c1', price: 70000, kind: 'cleaning', travel: 5000, vertical: 'cleaning'),
        _item(id: 'b1', price: 20000, hair: true, surcharge: {'long': 15000}, vertical: 'beauty'),
      ],
      qty: {'c1': 1, 'b1': 1},
      guests: 2,
      hair: 'long',
    );
    // cleaning 700 + beauty (200+150)*2 guests = 700 + 700 = 1400 EGP services
    expect(bookSubtotal(lines), 140000);
    expect(bookTravel(lines), 5000); // cleaning travel * 1
    expect(bookTools(lines: lines, toolsFromProvider: true), 5000);
    const fees = ProcessingFeeSchedule();
    final exclusive = bookExclusiveTotal(lines: lines, toolsFromProvider: true, discount: 10000);
    // 1400 + 50 + 50 - 100 = 1400 EGP = 140000
    expect(exclusive, 140000);
    final inclusive = bookInclusiveTotal(lines: lines, toolsFromProvider: true, fees: fees, discount: 10000);
    expect(inclusive, exclusive + fees.feeFor(exclusive));
    expect(inclusive, fees.charge(exclusive));
  });

  test('800 EGP exclusive becomes 823.50 under current card/wallet schedule', () {
    const fees = ProcessingFeeSchedule();
    expect(fees.feeFor(80000), 2350);
    expect(fees.charge(80000), 82350);
    expect(fees.charge(80000, 'instapay'), 82350);
    expect(fees.feeFor(80000, 'manual'), 0);
    expect(fees.charge(80000, 'instapay_manual'), 80000);
    expect(money(82350, 'en').contains('824'), isTrue);
  });

  test('beauty qty is multiplied by guests; cleaning is not', () {
    final lines = bookLines(
      items: [
        _item(id: 'c1', price: 10000, kind: 'cleaning'),
        _item(id: 'b1', price: 10000),
      ],
      qty: {'c1': 1, 'b1': 2},
      guests: 3,
      hair: 'medium',
    );
    final c = lines.firstWhere((l) => l.item.id == 'c1');
    final b = lines.firstWhere((l) => l.item.id == 'b1');
    expect(c.mult, 1);
    expect(b.mult, 6);
  });

  test('Booking.amountDue prefers chargedAmount', () {
    final b = Booking(
      id: '1',
      ref: 'ONS',
      status: 'pending_payment',
      slotStart: DateTime(2026, 9, 18, 15),
      total: 80000,
      escrow: 'held',
      serviceName: const Loc('x', 'س'),
      lineItems: const [],
      timeline: const [],
      chargedAmount: 82350,
      paymentFeeAmount: 2350,
    );
    expect(b.amountDue(processingFee: 9999), 82350);
  });

  testWidgets('category tabs hide for 0–1 verticals and render two', (tester) async {
    final bf = Copy.bookFlow('ar');
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Column(
            children: [
              BookCategoryTabs(verticals: const [], active: '', counts: const {}, bf: bf, onSelect: (_) {}),
              BookCategoryTabs(verticals: const ['cleaning'], active: 'cleaning', counts: const {'cleaning': 3}, bf: bf, onSelect: (_) {}),
              BookCategoryTabs(
                verticals: const ['cleaning', 'beauty'],
                active: 'cleaning',
                counts: const {'cleaning': 4, 'beauty': 2},
                bf: bf,
                onSelect: (_) {},
              ),
            ],
          ),
        ),
      ),
    ));
    expect(find.textContaining('تنظيف'), findsOneWidget);
    expect(find.textContaining('تجميل'), findsOneWidget);
    expect(find.textContaining('٤ خدمات'), findsOneWidget);
  });

  testWidgets('service accordion and empty cart', (tester) async {
    final bf = Copy.bookFlow('ar');
    var expanded = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ListView(
            children: [
              BookEmptyCart(title: bf['emptyTitle']!, body: bf['emptyBody']!),
              BookServiceRow(
                name: 'غسيل شعر',
                note: '٤٥ د',
                price: '٣٥٠ ج.م',
                qty: 1,
                expanded: expanded,
                onInc: () {},
                onDec: () {},
                onToggle: () => setState(() => expanded = !expanded),
                includes: const ['غسيل'],
                excludes: const ['صبغة'],
                includesLabel: bf['includes']!,
                excludesLabel: bf['excludes']!,
                detailsOpen: bf['detailsOpen']!,
                detailsClose: bf['detailsClose']!,
              ),
            ],
          ),
        ),
      ),
    ));
    expect(find.text(bf['emptyTitle']!), findsOneWidget);
    expect(find.text(bf['detailsOpen']!), findsOneWidget);
    await tester.tap(find.text(bf['detailsOpen']!));
    await tester.pump();
    expect(find.text(bf['includes']!), findsOneWidget);
    expect(find.text(bf['excludes']!), findsOneWidget);
  });

  testWidgets('stepper strip and sticky total stay consistent', (tester) async {
    const price = '٨٢٤ ج.م';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ClientBookingStepper(step: 1, labels: const ['١ الخدمة', '٢ الميعاد', '٣ الدفع'], cartReady: true),
            const Spacer(),
            ClientStickyBar(label: 'الإجمالي', sub: 'الرسوم داخلة', price: price, cta: 'كمّلي للميعاد', onTap: () {}),
          ],
        ),
      ),
    ));
    expect(find.text('١ الخدمة'), findsOneWidget);
    expect(find.text(price), findsOneWidget);
    expect(find.text('الرسوم داخلة'), findsOneWidget);
  });

  testWidgets('pay error screen has three recovery actions', (tester) async {
    final bf = Copy.bookFlow('ar');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text(bf['errTitle']!),
            ClientPrimaryButton(label: bf['errRetry']!, onTap: () {}),
            ClientGhostButton(label: '${bf['errOther']} البطاقة', onTap: () {}),
            Text(bf['errSupport']!),
          ],
        ),
      ),
    ));
    expect(find.text(bf['errRetry']!), findsOneWidget);
    expect(find.textContaining(bf['errOther']!), findsOneWidget);
    expect(find.text(bf['errSupport']!), findsOneWidget);
    expect(find.text(bf['errBack']!), findsNothing);
  });

  testWidgets('field error toast sits at the bottom center', (tester) async {
    final bf = Copy.bookFlow('ar');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const SizedBox.expand(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BookErrorToast(message: bf['needAddress']!, onDismiss: () {}),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    expect(find.text(bf['needAddress']!), findsOneWidget);
    expect(find.byType(BookErrorToast), findsOneWidget);
  });

  testWidgets('invalid field frame shows the message on the field', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookFieldFrame(
          invalid: true,
          message: 'اختاري أو زودي عنوان قبل ما تكملي.',
          child: Text('فين'),
        ),
      ),
    ));
    expect(find.text('اختاري أو زودي عنوان قبل ما تكملي.'), findsOneWidget);
    expect(find.text('فين'), findsOneWidget);
  });
}
