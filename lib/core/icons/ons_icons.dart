import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';

/// Oons icon set. One geometry: 24×24 grid, 20×20 live area, 2px stroke
/// (2.4px on tablet), square caps, miter joins, no fills, no rounding.
/// Path data is copied verbatim from the design system (section 04) — do not
/// retype or "improve" it. Colour is always the surrounding text colour.
const Map<String, String> kOnsIconPaths = {
  'close': 'M5 5 19 19 M19 5 5 19',
  'search': 'M4 4h11v11H4z M15 15 21 21',
  'bell': 'M6 18h12 M7 18V10a5 5 0 0 1 10 0v8 M10 21h4',
  'camera': 'M3 7h4l1.5-2h7L17 7h4v13H3z M12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  'plus': 'M12 4v16 M4 12h16',
  'minus': 'M4 12h16',
  'advance': 'M4 12h14 M13 7l5 5-5 5',
  'back': 'M20 12H6 M11 7l-5 5 5 5',
  'check': 'M4 12.5 9.5 18 20 6',
  'shield': 'M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z',
  'shieldCheck': 'M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z M8.5 12l2.5 2.5L16 9.5',
  'phone': 'M5 3h5l2 5-3 2a12 12 0 0 0 5 5l2-3 5 2v5h-3A15 15 0 0 1 3 6z',
  'message': 'M3 4h18v13H8l-5 4z',
  'calendar': 'M3 6h18v15H3z M3 11h18 M8 3v5 M16 3v5',
  'clock': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 7v5.5l4 2.5',
  'retry': 'M21 6v6h-6 M19.5 12a7.5 7.5 0 1 1-2.2-5.3L21 10',
  'pin': 'M12 21s7-6 7-11a7 7 0 1 0-14 0c0 5 7 11 7 11z M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  'card': 'M2 5h20v14H2z M2 10h20 M5 15h4',
  'wallet': 'M6 2h12v20H6z M10 5h4 M10 18.5h3',
  'clean': 'M9 2h6v6H9z M7 8h10l1 14H6z M12 12v6',
  'beauty': 'M7 3 17 17 M17 3 7 17 M6.5 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z M17.5 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'user': 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2',
  'alert': 'M12 3 2 21h20z M12 10v5 M12 18h.01',
  'info': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M12 11v6 M12 7.5h.01',
  'list': 'M3 4h18v17H3z M3 9h18 M7 13h10 M7 17h6',
  'home': 'M3 11 12 3l9 8 M6 10v11h12V10',
  'edit': 'M4 20h4L20 8l-4-4L4 16z M14 6l4 4',
  'star': 'M12 3 15 9.5 22 10.4l-5 4.7 1.3 6.9L12 18.7 5.7 22 7 15.1l-5-4.7L9 9.5z',
  'offline':
      'M2 2 22 22 M5 12.5a10 10 0 0 1 4-2.4 M2 8.5a15 15 0 0 1 5-3 M12 19h.01 M8.5 15.5a5 5 0 0 1 2-1.2 M15 10.3a10 10 0 0 1 4 2.2 M13 6a15 15 0 0 1 9 2.5',
};

const Map<String, String> _labelsAr = {
  'close': 'إغلاق', 'search': 'بحث', 'bell': 'تنبيهات', 'camera': 'كاميرا', 'plus': 'زيادة',
  'minus': 'نقصان', 'advance': 'تقدّم', 'back': 'رجوع', 'check': 'تم', 'shield': 'أمان',
  'shieldCheck': 'موثّقة', 'phone': 'اتصال', 'message': 'رسالة', 'calendar': 'تقويم',
  'clock': 'وقت', 'retry': 'إعادة المحاولة', 'pin': 'الموقع', 'card': 'بطاقة', 'wallet': 'محفظة',
  'clean': 'تنظيف', 'beauty': 'تجميل', 'user': 'الحساب', 'alert': 'تنبيه', 'info': 'شرح',
  'list': 'الحجوزات', 'home': 'الرئيسية', 'edit': 'تعديل', 'star': 'تقييم', 'offline': 'لا يوجد اتصال',
};

const Map<String, String> _labelsEn = {
  'close': 'Close', 'search': 'Search', 'bell': 'Notifications', 'camera': 'Camera', 'plus': 'Add',
  'minus': 'Remove', 'advance': 'Next', 'back': 'Back', 'check': 'Done', 'shield': 'Safety',
  'shieldCheck': 'Verified', 'phone': 'Call', 'message': 'Message', 'calendar': 'Calendar',
  'clock': 'Time', 'retry': 'Retry', 'pin': 'Location', 'card': 'Card', 'wallet': 'Wallet',
  'clean': 'Cleaning', 'beauty': 'Beauty', 'user': 'Account', 'alert': 'Alert', 'info': 'Info',
  'list': 'Bookings', 'home': 'Home', 'edit': 'Edit', 'star': 'Rating', 'offline': 'Offline',
};

String onsIconLabel(String name, {required bool ar}) => (ar ? _labelsAr : _labelsEn)[name] ?? name;

/// The only icons allowed without a visible text label (brief: eight places —
/// close, search, notifications+badge, tech-mode camera, add FAB, advance on a
/// board card, stepper −/+, back in a titled header). Each still needs an
/// accessible name.
const Set<String> kIconOnlyAllowed = {
  'close', 'search', 'bell', 'camera', 'plus', 'minus', 'advance', 'back',
};

/// Arrow-like icons that mirror with the locale (never a blanket flip).
const Set<String> kOnsIconMirrorsInRtl = {'advance', 'back'};

final Map<String, Path> _pathCache = {};

Path onsIconPath(String name) {
  final cached = _pathCache[name];
  if (cached != null) return cached;
  final d = kOnsIconPaths[name];
  if (d == null) throw ArgumentError('Unknown Oons icon "$name"');
  return _pathCache[name] = parseOnsSvgPath(d);
}

final RegExp _tok = RegExp(r'([A-Za-z])|(-?(?:\d+\.?\d*|\.\d+))');

/// Parses the small SVG path subset the icon set uses (M L H V A C S Z, absolute
/// and relative, implicit repeats) into a Flutter [Path] on the 24×24 grid.
Path parseOnsSvgPath(String d) {
  final t = _tok.allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
  var lastCtrlX = 0.0, lastCtrlY = 0.0;
  var prevCubic = false;
  String? cmd;
  bool isNum(int k) => k < t.length && !RegExp(r'[A-Za-z]').hasMatch(t[k]);
  double n() => double.parse(t[i++]);

  while (i < t.length) {
    if (!isNum(i)) cmd = t[i++];
    if (cmd == null) break;
    final rel = cmd == cmd.toLowerCase();
    final wasCubic = prevCubic;
    prevCubic = false;
    switch (cmd.toUpperCase()) {
      case 'Z':
        path.close();
        cx = sx;
        cy = sy;
      case 'M':
        var first = true;
        do {
          final x = n(), y = n();
          cx = rel ? cx + x : x;
          cy = rel ? cy + y : y;
          if (first) {
            path.moveTo(cx, cy);
            sx = cx;
            sy = cy;
            first = false;
          } else {
            path.lineTo(cx, cy);
          }
        } while (isNum(i));
      case 'L':
        do {
          final x = n(), y = n();
          cx = rel ? cx + x : x;
          cy = rel ? cy + y : y;
          path.lineTo(cx, cy);
        } while (isNum(i));
      case 'H':
        do {
          final x = n();
          cx = rel ? cx + x : x;
          path.lineTo(cx, cy);
        } while (isNum(i));
      case 'V':
        do {
          final y = n();
          cy = rel ? cy + y : y;
          path.lineTo(cx, cy);
        } while (isNum(i));
      case 'C':
        do {
          final x1 = n(), y1 = n(), x2 = n(), y2 = n(), x = n(), y = n();
          final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
          path.cubicTo(ox + x1, oy + y1, ox + x2, oy + y2, ox + x, oy + y);
          lastCtrlX = ox + x2;
          lastCtrlY = oy + y2;
          cx = ox + x;
          cy = oy + y;
          prevCubic = true;
        } while (isNum(i));
      case 'S':
        var chained = wasCubic;
        do {
          final x2 = n(), y2 = n(), x = n(), y = n();
          final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
          final x1 = chained ? 2 * cx - lastCtrlX : cx;
          final y1 = chained ? 2 * cy - lastCtrlY : cy;
          path.cubicTo(x1, y1, ox + x2, oy + y2, ox + x, oy + y);
          lastCtrlX = ox + x2;
          lastCtrlY = oy + y2;
          cx = ox + x;
          cy = oy + y;
          chained = true;
          prevCubic = true;
        } while (isNum(i));
      case 'A':
        do {
          final rx = n(), ry = n(), rot = n(), large = n(), sweep = n(), x = n(), y = n();
          cx = rel ? cx + x : x;
          cy = rel ? cy + y : y;
          path.arcToPoint(
            Offset(cx, cy),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large != 0,
            clockwise: sweep != 0,
          );
        } while (isNum(i));
      default:
        throw FormatException('Unsupported path command $cmd in "$d"');
    }
  }
  return path;
}

class _OnsIconPainter extends CustomPainter {
  _OnsIconPainter(this.name, this.color, this.stroke, this.mirror);
  final String name;
  final Color color;
  final double stroke;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    if (mirror) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      onsIconPath(name),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..strokeMiterLimit = 10,
    );
  }

  @override
  bool shouldRepaint(_OnsIconPainter o) =>
      o.name != name || o.color != color || o.stroke != stroke || o.mirror != mirror;
}

/// A bare icon. Prefer [OnsIconLabel] (icon + visible word); use this directly
/// only next to text that already names it, and pass no [semanticLabel] then.
class OnsIcon extends StatelessWidget {
  const OnsIcon(this.name, {super.key, this.size = 24, this.color, this.strokeWidth, this.semanticLabel});

  final String name;
  final double size;
  final Color? color;

  /// Stroke on the 24-unit grid. Defaults to 2, or 2.4 on tablet widths.
  final double? strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(kOnsIconPaths.containsKey(name), 'Unknown Oons icon "$name"');
    final tablet = (MediaQuery.maybeSizeOf(context)?.shortestSide ?? 0) >= 600;
    final stroke = strokeWidth ?? (tablet ? 2.4 : 2.0);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final paint = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OnsIconPainter(
          name,
          color ?? DefaultTextStyle.of(context).style.color ?? T.ink,
          stroke,
          rtl && kOnsIconMirrorsInRtl.contains(name),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: paint));
  }
}

/// Icon-only control content. Only [kIconOnlyAllowed] names may be used, and an
/// accessible name is mandatory ("no visible label" ≠ "no accessible name").
class OnsIconOnly extends StatelessWidget {
  OnsIconOnly(this.name, {super.key, required this.semanticLabel, this.size = 24, this.color})
      : assert(kIconOnlyAllowed.contains(name), '"$name" may not be used without a visible label');

  final String name;
  final String semanticLabel;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      OnsIcon(name, size: size, color: color, semanticLabel: semanticLabel);
}

/// Icon + visible word — the default. The word is the accessible name, so the
/// icon is hidden from semantics.
class OnsIconLabel extends StatelessWidget {
  const OnsIconLabel(this.name, this.label, {super.key, this.size = 20, this.color, this.style, this.gap = 8});

  final String name;
  final String label;
  final double size;
  final Color? color;
  final TextStyle? style;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? style?.color ?? DefaultTextStyle.of(context).style.color ?? T.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OnsIcon(name, size: size, color: c),
        SizedBox(width: gap),
        Flexible(child: Text(label, style: (style ?? const TextStyle()).copyWith(color: c))),
      ],
    );
  }
}
