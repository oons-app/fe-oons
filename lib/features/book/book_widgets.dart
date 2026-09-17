import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';

class BookMonoKicker extends StatelessWidget {
  const BookMonoKicker(this.text, {super.key, this.color = Client.muted2});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: color),
    );
  }
}

class BookChip extends StatelessWidget {
  const BookChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: Client.ink, width: Client.rule),
            color: selected ? Client.plum : Client.card,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Client.bg : Client.ink),
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: child) : child;
  }
}

class BookStepperControl extends StatelessWidget {
  const BookStepperControl({
    super.key,
    required this.qty,
    required this.onDec,
    required this.onInc,
    this.min = 0,
    this.max = 99,
  });

  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final canDec = qty > min;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(
            label: '−',
            onTap: canDec ? onDec : null,
            fg: canDec ? Client.ink : const Color(0xFFC9C1BA),
            border: Border(left: BorderSide(color: Client.line, width: Client.rule)),
          ),
          SizedBox(
            width: 34,
            child: Text(
              digits(qty, ar: ar),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: T.mono, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _cell(
            label: '+',
            onTap: qty < max ? onInc : null,
            fg: Client.ink,
            bg: Client.sand2,
            border: Border(right: BorderSide(color: Client.line, width: Client.rule)),
          ),
        ],
      ),
    );
  }

  Widget _cell({required String label, required Color fg, VoidCallback? onTap, Color? bg, required Border border}) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, border: border),
          child: Text(label, style: TextStyle(fontFamily: T.mono, fontSize: 18, fontWeight: FontWeight.w500, color: fg)),
        ),
      ),
    );
  }
}

class BookPayIcon extends StatelessWidget {
  const BookPayIcon({super.key, required this.card});
  final bool card;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: card ? _CardIconPainter() : _WalletIconPainter(),
    );
  }
}

class _CardIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Client.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square;
    canvas.drawRect(const Rect.fromLTWH(2, 5, 20, 14), p);
    canvas.drawLine(const Offset(2, 9.5), const Offset(22, 9.5), p);
    canvas.drawLine(const Offset(5, 15), const Offset(9, 15), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Client.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square;
    canvas.drawRect(const Rect.fromLTWH(6, 2, 12, 20), p);
    canvas.drawLine(const Offset(10, 5), const Offset(14, 5), p);
    canvas.drawLine(const Offset(10.5, 18.5), const Offset(13.5, 18.5), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArabicDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final w = toWesternDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = w.length > 4 ? w.substring(0, 4) : w;
    return TextEditingValue(text: clipped, selection: TextSelection.collapsed(offset: clipped.length));
  }
}

String formatHoldClock(DateTime hold, String lang) {
  final local = hold.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  if (lang == 'ar') return toArabicDigits('$h:$m');
  return '$h:$m';
}

String bookVerticalLabel(String v, Map<String, String> bf) {
  switch (v) {
    case 'cleaning':
      return bf['catClean'] ?? v;
    case 'beauty':
      return bf['catBeauty'] ?? v;
    default:
      return v;
  }
}

String bookVerticalGlyph(String v) => v == 'beauty' ? '✂' : '⌂';

String heldSlotLine({
  required DateTime slot,
  required DateTime hold,
  required String lang,
  required Map<String, String> bf,
}) {
  final local = slot.toLocal();
  final day = weekdayLabel(local, lang);
  final d = digits(local.day, ar: lang == 'ar');
  final clock = formatClock(local, lang);
  final until = formatHoldClock(hold, lang);
  final slotBit = '$day $d · $clock';
  if (lang == 'ar') return '$slotBit ${bf['errHeld'] ?? 'محجوزة ليكي لـ'}$until كمان';
  return '$slotBit ${bf['errHeld'] ?? 'is held for you until'} $until';
}

Uri googleCalendarUri({
  required DateTime start,
  required int durationMin,
  required String title,
  required String location,
  String? details,
}) {
  final mins = durationMin < 1 ? 90 : durationMin;
  final end = start.toUtc().add(Duration(minutes: mins));
  String stamp(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(start)}/${stamp(end)}',
    'location': location,
    if (details != null && details.isNotEmpty) 'details': details,
  });
}

class BookCategoryTabs extends StatelessWidget {
  const BookCategoryTabs({
    super.key,
    required this.verticals,
    required this.active,
    required this.counts,
    required this.bf,
    required this.onSelect,
  });

  final List<String> verticals;
  final String active;
  final Map<String, int> counts;
  final Map<String, String> bf;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (verticals.length <= 1) return const SizedBox.shrink();
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: verticals.map((v) {
        final on = v == active;
        final n = counts[v] ?? 0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Semantics(
              button: true,
              selected: on,
              label: bookVerticalLabel(v, bf),
              child: InkWell(
                onTap: () => onSelect(v),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    color: on ? Client.plum : Client.card,
                    border: Border.all(color: Client.ink, width: Client.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(height: 4, color: on ? Client.terracotta : Colors.transparent),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${bookVerticalGlyph(v)}  ${bookVerticalLabel(v, bf)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: on ? Client.bg : Client.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pluralService(n, ar: ar),
                              style: TextStyle(fontSize: 11, color: on ? const Color(0xFFD9CBD4) : Client.muted2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class BookServiceRow extends StatelessWidget {
  const BookServiceRow({
    super.key,
    required this.name,
    required this.note,
    required this.price,
    required this.qty,
    required this.expanded,
    required this.onInc,
    required this.onDec,
    required this.onToggle,
    required this.includes,
    required this.excludes,
    required this.includesLabel,
    required this.excludesLabel,
    required this.detailsOpen,
    required this.detailsClose,
  });

  final String name;
  final String note;
  final String price;
  final int qty;
  final bool expanded;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onToggle;
  final List<String> includes;
  final List<String> excludes;
  final String includesLabel;
  final String excludesLabel;
  final String detailsOpen;
  final String detailsClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: qty > 0 ? Client.plumTint : Client.card,
        border: const Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BookStepperControl(qty: qty, onDec: onDec, onInc: onInc),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.3)),
                      if (note.isNotEmpty)
                        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Client.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(price, style: const TextStyle(fontFamily: T.mono, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Text(expanded ? '−' : '+', style: const TextStyle(fontFamily: T.mono, fontSize: 16, color: Client.muted)),
                    const SizedBox(width: 8),
                    Text(
                      expanded ? detailsClose : detailsOpen,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Client.plum),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (includes.isNotEmpty) ...[
                    Text(includesLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Client.oliveInk)),
                    const SizedBox(height: 6),
                    ...includes.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✓', style: TextStyle(fontSize: 16, height: 1.15, color: Client.olive)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e, style: const TextStyle(fontSize: 13, height: 1.35))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (excludes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(excludesLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Client.muted)),
                    const SizedBox(height: 6),
                    ...excludes.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(e, style: const TextStyle(fontSize: 13, height: 1.35, color: Client.muted)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BookEmptyCart extends StatelessWidget {
  const BookEmptyCart({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.45, color: Client.muted)),
        ],
      ),
    );
  }
}

enum BookField { services, area, slot, address }

class BookFieldFrame extends StatelessWidget {
  const BookFieldFrame({
    super.key,
    required this.invalid,
    required this.message,
    required this.child,
  });

  final bool invalid;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: invalid ? Client.warnTint : Colors.transparent,
        border: invalid ? Border.all(color: Client.terracotta, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invalid && (message ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('!', style: TextStyle(fontFamily: T.mono, fontSize: 16, fontWeight: FontWeight.w700, color: Client.terracotta)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w700, color: Client.terracotta),
                    ),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class BookErrorToast extends StatefulWidget {
  const BookErrorToast({super.key, required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  State<BookErrorToast> createState() => _BookErrorToastState();
}

class _BookErrorToastState extends State<BookErrorToast> {
  var _in = false;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
    _hold = Timer(const Duration(seconds: 4), _hide);
  }

  @override
  void didUpdateWidget(covariant BookErrorToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message == widget.message) return;
    _hold?.cancel();
    setState(() => _in = true);
    _hold = Timer(const Duration(seconds: 4), _hide);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _in = false);
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: AnimatedSlide(
        offset: _in ? Offset.zero : const Offset(0, 0.35),
        duration: const Duration(milliseconds: 220),
        curve: _in ? Curves.easeOut : Curves.easeIn,
        child: AnimatedOpacity(
          opacity: _in ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _hide,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Client.warnTint,
                    border: Border.all(color: Client.terracotta, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Text('!', style: TextStyle(fontFamily: T.mono, fontSize: 18, fontWeight: FontWeight.w700, color: Client.terracotta)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w700, color: Client.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookPayMethodTile extends StatelessWidget {
  const BookPayMethodTile({
    super.key,
    required this.selected,
    required this.card,
    required this.title,
    required this.note,
    required this.onTap,
  });

  final bool selected;
  final bool card;
  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Client.plum : Client.ink, width: selected ? 2 : Client.rule),
            color: selected ? Client.plumTint : Client.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
                child: BookPayIcon(card: card),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(note, style: const TextStyle(fontSize: 12, height: 1.35, color: Client.muted)),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  border: Border.all(color: Client.ink, width: Client.rule),
                  color: selected ? Client.plum : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
