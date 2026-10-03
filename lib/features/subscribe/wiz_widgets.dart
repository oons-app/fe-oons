import 'package:flutter/material.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/subscribe/ar_eg.dart';

/// Provider-subscription building blocks (Wiz palette only, no radius, no
/// shadow, no gradient, 44px touch targets).

TextStyle ws(double size, {FontWeight w = FontWeight.w400, Color c = Wiz.ink, bool mono = false, double? h, TextDecoration? deco}) => TextStyle(
      fontFamily: mono ? Wiz.mono : Wiz.text,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      decoration: deco,
    );

/// Primary CTA: 54px, plum, grey when disabled.
class WizPrimaryButton extends StatelessWidget {
  const WizPrimaryButton({super.key, required this.label, required this.onTap, this.enabled = true, this.busy = false, this.background = Wiz.plum});
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool busy;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy && onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      child: Material(
        color: on ? background : Wiz.disabled,
        child: InkWell(
          onTap: on ? onTap : null,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : ExcludeSemantics(child: Text(label, textAlign: TextAlign.center, style: ws(15, w: FontWeight.w700, c: on ? Colors.white : Wiz.muted))),
          ),
        ),
      ),
    );
  }
}

/// White button with a gold 1.5px rule (the published screen's secondary).
class WizGoldOutlineButton extends StatelessWidget {
  const WizGoldOutlineButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Wiz.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Wiz.gold, width: 1.5)),
            child: Text(label, style: ws(15, w: FontWeight.w700, c: Wiz.goldInk)),
          ),
        ),
      );
}

/// A tappable label with a guaranteed 44x44 hit area.
class WizTextAction extends StatelessWidget {
  const WizTextAction({super.key, required this.label, required this.onTap, this.color = Wiz.plum, this.size = 13, this.weight = FontWeight.w700});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(alignment: Alignment.center, widthFactor: 1, child: Text(label, style: ws(size, w: weight, c: color))),
          ),
        ),
      );
}

/// Visual of any size with a 44px minimum hit area.
class Tap44 extends StatelessWidget {
  const Tap44({super.key, required this.onTap, required this.child, this.semanticLabel});
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final w = InkWell(
      onTap: onTap,
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44, minWidth: 44), child: Center(widthFactor: 1, child: child)),
    );
    return semanticLabel == null ? w : Semantics(button: true, label: semanticLabel, child: w);
  }
}

/// Solid-bordered card.
class WizCard extends StatelessWidget {
  const WizCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = Wiz.surface, this.borderColor = Wiz.border, this.borderWidth = 1});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, border: Border.all(color: borderColor, width: borderWidth)),
        child: child,
      );
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.width);
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    const dash = 5.0, gap = 3.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final e = (d + dash).clamp(0, total).toDouble();
        canvas.drawLine(a + dir * d, a + dir * e, p);
        d += dash + gap;
      }
    }

    final r = Rect.fromLTWH(width / 2, width / 2, size.width - width, size.height - width);
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedPainter o) => o.color != color || o.width != width;
}

/// Card with a dashed 1px rule.
class WizDashed extends StatelessWidget {
  const WizDashed({super.key, required this.child, this.color = Wiz.border, this.padding = const EdgeInsets.all(12), this.background});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Color? background;
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedPainter(color, 1),
        child: Container(color: background, padding: padding, child: child),
      );
}

/// Dashed square placeholder (member photo / avatar).
class WizAvatar extends StatelessWidget {
  const WizAvatar({super.key, this.size = 40, this.label = '', this.imageUrl, this.gold = false});
  final double size;
  final String label;
  final String? imageUrl;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '' : String.fromCharCodes([label.trim().runes.first]);
    final inner = imageUrl != null
        ? Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
        : Text(gold ? '∗' : initial, style: ws(size * 0.38, w: FontWeight.w700, c: gold ? Wiz.goldNote : Wiz.plum));
    return gold
        ? Container(width: size, height: size, alignment: Alignment.center, color: Wiz.goldTint, child: inner)
        : SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _DashedPainter(Wiz.faint, 1), child: Container(alignment: Alignment.center, color: Wiz.plumTint, child: inner)),
          );
  }
}

/// Radio indicator: 22px, 6px plum ring when selected.
class WizRadio extends StatelessWidget {
  const WizRadio({super.key, required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? Wiz.plum : Wiz.faint, width: selected ? 6 : 1.5),
        ),
      );
}

/// Plan status chip: متاحة / متوقّفة / مسودة / مؤرشفة.
class WizStatusChip extends StatelessWidget {
  const WizStatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final live = status == 'published' || status == 'active';
    final paused = status == 'paused';
    return DsStatusBadge(planStatusLabel(status), tone: live ? DsTone.olive : paused ? DsTone.attention : DsTone.neutral);
  }
}

/// Fact headline + why + one clear button (the Oons empty-state pattern in the
/// provider palette).
class WizEmptyState extends StatelessWidget {
  const WizEmptyState({super.key, required this.icon, required this.title, required this.body, this.cta, this.onCta});
  final Widget icon;
  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onCta;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: Wiz.chip, border: Border.all(color: Wiz.border)), child: icon),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: ws(18, w: FontWeight.w700, h: 1.3)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: ws(13.5, c: Wiz.soft, h: 1.5)),
              if (cta != null) ...[const SizedBox(height: 22), SizedBox(width: double.infinity, child: WizPrimaryButton(label: cta!, onTap: onCta))],
            ]),
          ),
        ),
      );
}

/// Error block with a retry button.
class WizErrorState extends StatelessWidget {
  const WizErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => WizEmptyState(
        icon: const Icon(Icons.error_outline, size: 22, color: Wiz.danger),
        title: 'حصلت مشكلة',
        body: message,
        cta: 'جرّبي تاني',
        onCta: onRetry,
      );
}

/// Confirm dialog in the provider palette. Returns true when confirmed.
Future<bool?> showWizConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  String cancel = 'لأ، سيبيها',
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: Wiz.surface,
        shape: const RoundedRectangleBorder(),
        title: Text(title, style: ws(17, w: FontWeight.w700)),
        content: Text(body, style: ws(14, c: Wiz.body, h: 1.6)),
        actions: [
          WizTextAction(label: cancel, color: Wiz.soft, onTap: () => Navigator.pop(ctx, false)),
          WizTextAction(label: confirm, color: danger ? Wiz.danger : Wiz.plum, onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    ),
  );
}
