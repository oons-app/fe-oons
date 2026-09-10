import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oons/admin/theme.dart';

const chartPalette = [
  T.action,
  T.trust,
  T.warm,
  T.pending,
  T.childcare,
  T.chef,
  T.danger,
];

class ChartSlice {
  const ChartSlice({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;
}

class AdminBarChart extends StatelessWidget {
  const AdminBarChart({super.key, required this.slices, this.height = 180});
  final List<ChartSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _BarPainter(slices)),
    );
  }
}

class AdminLineChart extends StatelessWidget {
  const AdminLineChart({super.key, required this.slices, this.height = 180});
  final List<ChartSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LinePainter(slices)),
    );
  }
}

class AdminDonutChart extends StatelessWidget {
  const AdminDonutChart({super.key, required this.slices, this.size = 160});
  final List<ChartSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _DonutPainter(slices)),
        );
        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < slices.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: slices[i].color ?? chartPalette[i % chartPalette.length]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(slices[i].label, style: const TextStyle(fontSize: 12))),
                    Text('${slices[i].value.round()}', style: const TextStyle(fontFamily: T.mono, fontSize: 12)),
                  ],
                ),
              ),
          ],
        );
        if (constraints.maxWidth < size + 140) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chart,
              const SizedBox(height: 12),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 16),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.slices);
  final List<ChartSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final max = slices.fold<double>(0, (m, s) => math.max(m, s.value));
    if (max <= 0) return;
    const labelH = 22.0;
    const top = 8.0;
    final plotH = size.height - labelH - top;
    final gap = 8.0;
    final barW = math.max(8.0, (size.width - gap * (slices.length + 1)) / slices.length);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < slices.length; i++) {
      final h = (slices[i].value / max) * plotH;
      final x = gap + i * (barW + gap);
      final y = top + plotH - h;
      final paint = Paint()..color = slices[i].color ?? chartPalette[i % chartPalette.length];
      canvas.drawRect(Rect.fromLTWH(x, y, barW, h), paint);
      tp.text = TextSpan(
        text: slices[i].label,
        style: const TextStyle(fontFamily: T.mono, fontSize: 9, color: T.muted),
      );
      tp.layout(maxWidth: barW + gap);
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, size.height - labelH + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.slices != slices;
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.slices);
  final List<ChartSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.length < 2) return;
    final max = math.max(1.0, slices.fold<double>(0, (m, s) => math.max(m, s.value)));
    const padL = 4.0;
    const padR = 4.0;
    const padT = 10.0;
    const padB = 24.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    Offset pt(int i) {
      final x = padL + (slices.length == 1 ? w / 2 : i * w / (slices.length - 1));
      final y = padT + h - (slices[i].value / max) * h;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < slices.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(slices.length - 1).dx, padT + h)
      ..lineTo(pt(0).dx, padT + h)
      ..close();
    canvas.drawPath(fill, Paint()..color = T.plumTint.withValues(alpha: 0.7));
    canvas.drawPath(
      path,
      Paint()
        ..color = T.action
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = T.action;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < slices.length; i++) {
      canvas.drawCircle(pt(i), 3, dot);
      if (i == 0 || i == slices.length - 1 || i % 2 == 0) {
        tp.text = TextSpan(
          text: slices[i].label,
          style: const TextStyle(fontFamily: T.mono, fontSize: 9, color: T.muted),
        );
        tp.layout();
        tp.paint(canvas, Offset(pt(i).dx - tp.width / 2, size.height - 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.slices != slices;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);
  final List<ChartSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    var start = -math.pi / 2;
    final rect = Rect.fromCircle(center: c, radius: r - 4);
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = slices[i].color ?? chartPalette[i % chartPalette.length],
      );
      start += sweep;
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = T.surface);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}
