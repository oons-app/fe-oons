import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';

enum GlyphKind {
  home,
  bookings,
  wallet,
  profile,
  beauty,
  cleaning,
  chef,
  childcare,
  star,
  back,
  shield,
  pin,
  card,
  heart,
  globe,
  bell,
  trash,
  mark,
  menu,
}

/// Vector icons drawn in-canvas so they still show when the Material icon font
/// is overridden by Arabic/Archivo on Flutter web.
class Glyph extends StatelessWidget {
  const Glyph(this.kind, {super.key, this.size = 22, this.color = T.ink, this.fill = false});
  final GlyphKind kind;
  final double size;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(kind: kind, color: color, fill: fill),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.kind, required this.color, required this.fill});
  final GlyphKind kind;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.12).clamp(1.8, 2.4)
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square;
    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final p = fill ? solid : stroke;

    switch (kind) {
      case GlyphKind.home:
        final path = Path()
          ..moveTo(s * 0.12, s * 0.48)
          ..lineTo(s * 0.5, s * 0.14)
          ..lineTo(s * 0.88, s * 0.48)
          ..lineTo(s * 0.88, s * 0.88)
          ..lineTo(s * 0.12, s * 0.88)
          ..close();
        canvas.drawPath(path, p);
        canvas.drawRect(Rect.fromLTWH(s * 0.38, s * 0.56, s * 0.24, s * 0.32), p);
        break;
      case GlyphKind.bookings:
        canvas.drawRect(Rect.fromLTWH(s * 0.16, s * 0.28, s * 0.68, s * 0.58), p);
        canvas.drawLine(Offset(s * 0.16, s * 0.46), Offset(s * 0.84, s * 0.46), stroke);
        canvas.drawLine(Offset(s * 0.32, s * 0.14), Offset(s * 0.32, s * 0.34), stroke);
        canvas.drawLine(Offset(s * 0.68, s * 0.14), Offset(s * 0.68, s * 0.34), stroke);
        break;
      case GlyphKind.wallet:
        canvas.drawRect(Rect.fromLTWH(s * 0.12, s * 0.28, s * 0.76, s * 0.52), p);
        canvas.drawRect(Rect.fromLTWH(s * 0.52, s * 0.42, s * 0.36, s * 0.24), p);
        canvas.drawCircle(Offset(s * 0.7, s * 0.54), s * 0.05, solid);
        break;
      case GlyphKind.profile:
        canvas.drawCircle(Offset(s * 0.5, s * 0.32), s * 0.18, p);
        final body = Path()
          ..moveTo(s * 0.18, s * 0.88)
          ..quadraticBezierTo(s * 0.18, s * 0.56, s * 0.5, s * 0.56)
          ..quadraticBezierTo(s * 0.82, s * 0.56, s * 0.82, s * 0.88);
        canvas.drawPath(body, p);
        break;
      case GlyphKind.beauty:
        canvas.drawLine(Offset(s * 0.28, s * 0.18), Offset(s * 0.72, s * 0.82), stroke);
        canvas.drawLine(Offset(s * 0.72, s * 0.18), Offset(s * 0.28, s * 0.82), stroke);
        canvas.drawCircle(Offset(s * 0.24, s * 0.22), s * 0.1, p);
        canvas.drawCircle(Offset(s * 0.76, s * 0.22), s * 0.1, p);
        break;
      case GlyphKind.cleaning:
        canvas.drawLine(Offset(s * 0.5, s * 0.12), Offset(s * 0.5, s * 0.88), stroke);
        canvas.drawLine(Offset(s * 0.18, s * 0.5), Offset(s * 0.82, s * 0.5), stroke);
        canvas.drawLine(Offset(s * 0.26, s * 0.26), Offset(s * 0.74, s * 0.74), stroke);
        canvas.drawLine(Offset(s * 0.74, s * 0.26), Offset(s * 0.26, s * 0.74), stroke);
        break;
      case GlyphKind.chef:
        canvas.drawOval(Rect.fromLTWH(s * 0.18, s * 0.38, s * 0.64, s * 0.42), p);
        canvas.drawLine(Offset(s * 0.5, s * 0.16), Offset(s * 0.5, s * 0.42), stroke);
        canvas.drawLine(Offset(s * 0.34, s * 0.58), Offset(s * 0.66, s * 0.58), stroke);
        break;
      case GlyphKind.childcare:
        canvas.drawCircle(Offset(s * 0.5, s * 0.42), s * 0.22, p);
        canvas.drawCircle(Offset(s * 0.3, s * 0.24), s * 0.1, p);
        canvas.drawCircle(Offset(s * 0.7, s * 0.24), s * 0.1, p);
        canvas.drawRect(Rect.fromLTWH(s * 0.28, s * 0.66, s * 0.44, s * 0.2), p);
        break;
      case GlyphKind.star:
        final star = Path()
          ..moveTo(s * 0.5, s * 0.1)
          ..lineTo(s * 0.61, s * 0.38)
          ..lineTo(s * 0.9, s * 0.38)
          ..lineTo(s * 0.66, s * 0.56)
          ..lineTo(s * 0.76, s * 0.86)
          ..lineTo(s * 0.5, s * 0.68)
          ..lineTo(s * 0.24, s * 0.86)
          ..lineTo(s * 0.34, s * 0.56)
          ..lineTo(s * 0.1, s * 0.38)
          ..lineTo(s * 0.39, s * 0.38)
          ..close();
        canvas.drawPath(star, fill ? solid : stroke);
        break;
      case GlyphKind.back:
        canvas.drawLine(Offset(s * 0.62, s * 0.18), Offset(s * 0.28, s * 0.5), stroke);
        canvas.drawLine(Offset(s * 0.28, s * 0.5), Offset(s * 0.62, s * 0.82), stroke);
        break;
      case GlyphKind.shield:
        final shield = Path()
          ..moveTo(s * 0.5, s * 0.08)
          ..lineTo(s * 0.84, s * 0.22)
          ..lineTo(s * 0.84, s * 0.5)
          ..quadraticBezierTo(s * 0.84, s * 0.78, s * 0.5, s * 0.94)
          ..quadraticBezierTo(s * 0.16, s * 0.78, s * 0.16, s * 0.5)
          ..lineTo(s * 0.16, s * 0.22)
          ..close();
        canvas.drawPath(shield, p);
        canvas.drawLine(Offset(s * 0.34, s * 0.5), Offset(s * 0.46, s * 0.64), stroke);
        canvas.drawLine(Offset(s * 0.46, s * 0.64), Offset(s * 0.7, s * 0.36), stroke);
        break;
      case GlyphKind.pin:
        canvas.drawCircle(Offset(s * 0.5, s * 0.38), s * 0.22, p);
        canvas.drawCircle(Offset(s * 0.5, s * 0.38), s * 0.07, solid);
        canvas.drawLine(Offset(s * 0.5, s * 0.6), Offset(s * 0.5, s * 0.9), stroke);
        break;
      case GlyphKind.card:
        canvas.drawRect(Rect.fromLTWH(s * 0.1, s * 0.28, s * 0.8, s * 0.5), p);
        canvas.drawLine(Offset(s * 0.1, s * 0.44), Offset(s * 0.9, s * 0.44), stroke);
        canvas.drawLine(Offset(s * 0.2, s * 0.62), Offset(s * 0.48, s * 0.62), stroke);
        break;
      case GlyphKind.heart:
        final heart = Path()
          ..moveTo(s * 0.5, s * 0.82)
          ..cubicTo(s * 0.18, s * 0.6, s * 0.12, s * 0.36, s * 0.32, s * 0.24)
          ..cubicTo(s * 0.42, s * 0.16, s * 0.5, s * 0.28, s * 0.5, s * 0.36)
          ..cubicTo(s * 0.5, s * 0.28, s * 0.58, s * 0.16, s * 0.68, s * 0.24)
          ..cubicTo(s * 0.88, s * 0.36, s * 0.82, s * 0.6, s * 0.5, s * 0.82)
          ..close();
        canvas.drawPath(heart, p);
        break;
      case GlyphKind.globe:
        canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.34, p);
        canvas.drawOval(Rect.fromLTWH(s * 0.32, s * 0.16, s * 0.36, s * 0.68), p);
        canvas.drawLine(Offset(s * 0.16, s * 0.5), Offset(s * 0.84, s * 0.5), stroke);
        break;
      case GlyphKind.bell:
        final bell = Path()
          ..moveTo(s * 0.22, s * 0.58)
          ..lineTo(s * 0.22, s * 0.42)
          ..quadraticBezierTo(s * 0.22, s * 0.16, s * 0.5, s * 0.16)
          ..quadraticBezierTo(s * 0.78, s * 0.16, s * 0.78, s * 0.42)
          ..lineTo(s * 0.78, s * 0.58)
          ..lineTo(s * 0.88, s * 0.7)
          ..lineTo(s * 0.12, s * 0.7)
          ..close();
        canvas.drawPath(bell, p);
        canvas.drawArc(Rect.fromLTWH(s * 0.38, s * 0.7, s * 0.24, s * 0.16), 0, 3.14, false, stroke);
        break;
      case GlyphKind.trash:
        canvas.drawRect(Rect.fromLTWH(s * 0.24, s * 0.36, s * 0.52, s * 0.5), p);
        canvas.drawLine(Offset(s * 0.18, s * 0.36), Offset(s * 0.82, s * 0.36), stroke);
        canvas.drawLine(Offset(s * 0.38, s * 0.2), Offset(s * 0.62, s * 0.2), stroke);
        canvas.drawLine(Offset(s * 0.38, s * 0.2), Offset(s * 0.38, s * 0.36), stroke);
        canvas.drawLine(Offset(s * 0.62, s * 0.2), Offset(s * 0.62, s * 0.36), stroke);
        break;
      case GlyphKind.mark:
        final outer = Path()
          ..addRRect(RRect.fromLTRBAndCorners(
            s * 0.18,
            s * 0.08,
            s * 0.82,
            s * 0.92,
            topLeft: Radius.circular(s * 0.32),
            topRight: Radius.circular(s * 0.32),
          ));
        final inner = Path()
          ..addRRect(RRect.fromLTRBAndCorners(
            s * 0.365,
            s * 0.58,
            s * 0.635,
            s * 0.92,
            topLeft: Radius.circular(s * 0.135),
            topRight: Radius.circular(s * 0.135),
          ));
        canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), solid);
        break;
      case GlyphKind.menu:
        canvas.drawLine(Offset(s * 0.16, s * 0.30), Offset(s * 0.84, s * 0.30), stroke);
        canvas.drawLine(Offset(s * 0.16, s * 0.50), Offset(s * 0.84, s * 0.50), stroke);
        canvas.drawLine(Offset(s * 0.16, s * 0.70), Offset(s * 0.84, s * 0.70), stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.color != color || old.fill != fill || old.kind != kind;
}

GlyphKind tabGlyph(int i, {bool provider = false}) {
  final kinds = provider
      ? const [GlyphKind.bookings, GlyphKind.menu, GlyphKind.wallet, GlyphKind.profile]
      : const [GlyphKind.home, GlyphKind.bookings, GlyphKind.profile];
  return kinds[i.clamp(0, kinds.length - 1)];
}

GlyphKind serviceGlyph(String id) {
  switch (id) {
    case 'cleaning':
      return GlyphKind.cleaning;
    case 'chef':
      return GlyphKind.chef;
    case 'childcare':
      return GlyphKind.childcare;
    default:
      return GlyphKind.beauty;
  }
}
