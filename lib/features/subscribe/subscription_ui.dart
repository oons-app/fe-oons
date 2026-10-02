import 'package:flutter/material.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_copy.dart';

class VisitModeSwitch extends StatelessWidget {
  const VisitModeSwitch({
    super.key,
    required this.monthly,
    required this.savePct,
    required this.onOnce,
    required this.onMonthly,
    this.onceLabel = 'مرة واحدة',
    this.monthlyLabel = 'باقة شهرية',
  });
  final bool monthly;
  final int savePct;
  final VoidCallback onOnce;
  final VoidCallback onMonthly;
  final String onceLabel;
  final String monthlyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Client.ink), color: Client.card),
      child: Row(
        children: [
          Expanded(child: _half(onceLabel, !monthly, onOnce, border: true)),
          Expanded(
            child: _half(
              monthlyLabel,
              monthly,
              onMonthly,
              chip: savePct > 0 ? 'وفّري ${toArabicDigits(savePct)}٪' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _half(String label, bool on, VoidCallback tap, {bool border = false, String? chip}) {
    return InkWell(
      onTap: tap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Client.plum : Client.card,
          border: border ? const Border(left: BorderSide(color: Client.ink)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Client.bg : Client.ink))),
            if (chip != null) ...[
              const SizedBox(width: 7),
              Container(
                color: Client.olive,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(chip, style: const TextStyle(color: Client.bg, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// E1 plan box on a provider row: plum border, plumTint, leading/trailing icons.
class PlanListingBadge extends StatelessWidget {
  const PlanListingBadge({super.key, required this.count, required this.fromPiastres, required this.savePct, this.onTap});
  final int count;
  final int fromPiastres;
  final int savePct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(border: Border.all(color: Client.plum), color: Client.plumTint),
          child: Row(
            children: [
              const OnsIcon('retry', size: 17, color: Client.plum),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(CC.planBoxTitle(count), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum)),
                    const SizedBox(height: 1),
                    Text(CC.planBoxSub(egpText(fromPiastres), savePct), style: const TextStyle(fontSize: 11.5, color: Client.body)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const OnsIcon('advance', size: 16, color: Client.plum),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rectangle with a dashed 1px rule (prototype's "dashed" boxes).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.color = Client.plum, this.padding = const EdgeInsets.all(12), this.fill});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color),
      child: Container(color: fill, padding: padding, child: child),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0, gap = 3.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final e = d + dash > total ? total : d + dash;
        canvas.drawLine(a + dir * d, a + dir * e, paint);
        d += dash + gap;
      }
    }

    const o = 0.5;
    final w = size.width - o, h = size.height - o;
    line(const Offset(o, o), Offset(w, o));
    line(Offset(w, o), Offset(w, h));
    line(Offset(w, h), Offset(o, h));
    line(Offset(o, h), const Offset(o, o));
  }

  @override
  bool shouldRepaint(_DashedRectPainter o) => o.color != color;
}


/// Header for the subscription screens: 44px back target, title, optional sub-line.
class SubHeader extends StatelessWidget {
  const SubHeader({super.key, required this.title, this.subtitle, this.onBack});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink))),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'رجوع',
            excludeSemantics: true,
            onTap: onBack ?? () => Navigator.maybePop(context),
            child: InkWell(
              onTap: onBack ?? () => Navigator.maybePop(context),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: OnsIcon('back', size: 21, color: Client.ink)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Client.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Client.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain skeleton card used while plan data loads.
class SubSkeletonCard extends StatelessWidget {
  const SubSkeletonCard({super.key, this.height = 150});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: Client.sand2, border: Border.all(color: Client.line)),
      );
}

/// Square confirm dialog (no radius). Returns true when confirmed.
Future<bool> showSubConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Client.bg,
        shape: const RoundedRectangleBorder(side: BorderSide(color: Client.ink)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Client.ink)),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.6, color: Client.body)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(88, 44), shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel, style: const TextStyle(color: Client.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(88, 44),
              backgroundColor: Client.plum,
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Client.bg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
  return r == true;
}
