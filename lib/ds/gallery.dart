import 'package:flutter/material.dart';
import 'package:oons/ds/ds.dart';

/// Living style guide: every token and every primitive, rendered for real.
/// Open it at `/ds` (debug and profile builds). If a component is not here,
/// it is not part of the design system.
class DsGalleryScreen extends StatefulWidget {
  const DsGalleryScreen({super.key});
  @override
  State<DsGalleryScreen> createState() => _DsGalleryScreenState();
}

class _DsGalleryScreenState extends State<DsGalleryScreen> {
  int seg = 0;
  bool chip = true;
  bool sw = true;
  int nav = 0;

  static const _swatches = <(String, Color, Color)>[
    ('cream', Ds.cream, Ds.ink),
    ('surface', Ds.surface, Ds.ink),
    ('white', Ds.white, Ds.ink),
    ('ink', Ds.ink, Ds.cream),
    ('plum', Ds.plum, Ds.cream),
    ('plumLight', Ds.plumLight, Ds.plum),
    ('olive', Ds.olive, Ds.cream),
    ('terracotta', Ds.terracotta, Ds.cream),
    ('terracottaBg', Ds.terracottaBg, Ds.terracottaText),
    ('divider', Ds.divider, Ds.ink),
    ('textBody', Ds.textBody, Ds.cream),
    ('textMuted', Ds.textMuted, Ds.cream),
    ('textFaint', Ds.textFaint, Ds.ink),
  ];

  Widget _title(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, Ds.s8, 0, Ds.s3), child: DsSectionHeader(t));

  @override
  Widget build(BuildContext context) {
    final ar = dsIsAr(context);
    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Ds.gutter, vertical: Ds.s4),
          children: [
            Text('Ons Design System', style: DsText.screenTitle),
            const SizedBox(height: Ds.s1),
            Text('Tokens and components — v2', style: DsText.meta),
            _title('Colour'),
            Wrap(spacing: Ds.s2, runSpacing: Ds.s2, children: [
              for (final s in _swatches)
                Container(
                  width: 104,
                  height: 64,
                  padding: const EdgeInsets.all(Ds.s2),
                  decoration: BoxDecoration(color: s.$2, border: Border.all(color: Ds.ink, width: Ds.rule)),
                  alignment: AlignmentDirectional.bottomStart,
                  child: Text(s.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.$3)),
                ),
            ]),
            _title('Type'),
            DsCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('عنوان الشاشة ٣٠', style: DsText.screenTitle),
              Text('عنوان صفحة فرعية ٢٦', style: DsText.subTitle),
              Text('عنوان قسم', style: DsText.section),
              Text('اسم العنصر', style: DsText.itemName),
              Text('نص عادي لوصف الحاجة بجملة قصيرة.', style: DsText.body),
              Text('معلومة تانوية', style: DsText.meta),
              Text(DsFormat.price(1200, ar: ar), style: DsText.num(size: 20, weight: FontWeight.w600)),
            ])),
            _title('Buttons'),
            DsButton(label: ar ? 'احفظي' : 'Save', onTap: () {}),
            const SizedBox(height: Ds.s2),
            DsButton(label: ar ? 'زر ثانوي' : 'Secondary', kind: DsButtonKind.secondary, onTap: () {}, icon: 'plus'),
            const SizedBox(height: Ds.s2),
            DsButton(label: ar ? 'احذفي' : 'Delete', kind: DsButtonKind.danger, onTap: () {}, compact: true),
            const SizedBox(height: Ds.s2),
            DsButton(label: ar ? 'بنحفظ…' : 'Saving…', onTap: () {}, busy: true),
            const SizedBox(height: Ds.s2),
            DsButton(label: ar ? 'مقفول' : 'Disabled', onTap: null),
            Align(alignment: AlignmentDirectional.centerStart, child: DsTextLink(ar ? 'رابط نصي' : 'Text link', onTap: () {})),
            _title('Segmented · chip · switch'),
            DsSegmented(labels: ar ? const ['الخدمات', 'المناطق', 'المواعيد'] : const ['Services', 'Areas', 'Hours'], index: seg, onChanged: (i) => setState(() => seg = i)),
            const SizedBox(height: Ds.s3),
            Wrap(spacing: Ds.s2, runSpacing: Ds.s2, children: [
              DsChip(label: ar ? 'مدينتي' : 'Madinaty', on: chip, onTap: () => setState(() => chip = !chip)),
              DsChip(label: ar ? 'الرحاب' : 'Rehab', on: !chip, onTap: () => setState(() => chip = !chip)),
              DsChip(label: DsFormat.time('09:00', ar: ar), on: true, mono: true, onTap: () {}),
              DsChip(label: DsFormat.time('10:00', ar: ar), on: false, mono: true, onTap: () {}),
            ]),
            const SizedBox(height: Ds.s3),
            DsCard.rows(children: [
              DsListRow(label: ar ? 'متاحة للحجز' : 'Available', trailing: DsSwitch(on: sw, label: ar ? 'متاحة للحجز' : 'Available', onChanged: (v) => setState(() => sw = v)), showChevron: false, background: sw ? null : Ds.terracottaBg),
            ]),
            _title('Badges'),
            Wrap(spacing: Ds.s2, runSpacing: Ds.s2, children: [
              DsStatusBadge(ar ? 'خلصت' : 'Done', tone: DsTone.olive),
              DsStatusBadge(ar ? 'اتلغت' : 'Cancelled'),
              DsStatusBadge(ar ? 'قيد المراجعة' : 'In review', tone: DsTone.attention),
              DsTag(ar ? 'باقة' : 'Plan'),
            ]),
            _title('Cards and rows'),
            DsStatStrip(items: [
              DsStat(label: ar ? 'النهارده' : 'Today', value: DsFormat.digits(2, ar: ar)),
              DsStat(label: ar ? 'الأسبوع ده' : 'This week', value: DsFormat.digits(5, ar: ar)),
              DsStat(label: ar ? 'متوقّع ج.م' : 'Expected', value: DsFormat.amount(4600, ar: ar), accent: true),
            ]),
            const SizedBox(height: Ds.s3),
            DsCard.rows(children: [
              DsListRow(label: ar ? 'الباقات الشهرية' : 'Monthly plans', icon: 'card', value: DsFormat.digits(2, ar: ar), onTap: () {}),
              DsListRow(label: ar ? 'بياناتي وأوراقي' : 'My details', icon: 'shieldCheck', value: ar ? 'مكتملة' : 'Complete', valueColor: Ds.oliveText, onTap: () {}),
              DsListRow(label: ar ? 'احذفي حسابي' : 'Delete account', icon: 'alert', danger: true, onTap: () {}),
            ]),
            const SizedBox(height: Ds.s3),
            Row(children: [
              const DsIconTile('clean'),
              const SizedBox(width: Ds.s3),
              Expanded(child: Text(ar ? 'التنظيف المنزلي' : 'Home cleaning', style: DsText.itemName)),
            ]),
            const SizedBox(height: Ds.s3),
            const DsMeter(value: 0.62),
            _title('Section header'),
            DsSectionHeader(ar ? 'الخدمات' : 'Services', actionLabel: ar ? 'تعديل كل الأسعار' : 'Edit all prices', onAction: () {}),
            _title('Sheet · toast · empty'),
            DsButton(label: ar ? 'افتحي شيت' : 'Open sheet', kind: DsButtonKind.secondary, compact: true, onTap: () => showDsSheet<void>(context, title: ar ? 'عنوان الشيت' : 'Sheet title', builder: (_) => Text(ar ? 'محتوى الشيت.' : 'Sheet body.', style: DsText.body))),
            const SizedBox(height: Ds.s2),
            DsButton(label: ar ? 'اعرضي توست' : 'Show toast', kind: DsButtonKind.secondary, compact: true, onTap: () => DsToast.show(context, ar ? 'اتحفظ' : 'Saved')),
            DsCard(padding: EdgeInsets.zero, child: DsEmptyState(icon: 'calendar', title: ar ? 'مفيش زيارات في اليوم ده' : 'No visits today', body: ar ? 'الحجوزات الجديدة هتظهر هنا.' : 'New bookings show up here.', cta: ar ? 'زوّدي مناطق' : 'Add areas', onCta: () {}, link: ar ? 'أو زوّدي ساعات' : 'Or add hours', onLink: () {})),
            _title('Back header · field · skeleton'),
            DsBackHeader(crumb: ar ? 'خدماتي · التنظيف المنزلي' : 'Services · Cleaning', onBack: () {}),
            const SizedBox(height: Ds.s3),
            DsField(label: ar ? 'رقم إنستاباي' : 'InstaPay number', hint: '01XXXXXXXXX', mono: true, ltr: true, keyboardType: TextInputType.number),
            const SizedBox(height: Ds.s3),
            const DsSkeletonRows(rows: 2),
            _title('Bottom navigation'),
            DsBottomNav(
              items: [
                DsNavItem(label: ar ? 'الزيارات' : 'Visits', icon: 'calendar'),
                DsNavItem(label: ar ? 'خدماتي' : 'Services', icon: 'list'),
                DsNavItem(label: ar ? 'الأرباح' : 'Earnings', icon: 'wallet'),
                DsNavItem(label: ar ? 'حسابي' : 'Account', icon: 'user'),
              ],
              index: nav,
              onTap: (i) => setState(() => nav = i),
            ),
            const SizedBox(height: Ds.s8),
          ],
        ),
      ),
    );
  }
}
