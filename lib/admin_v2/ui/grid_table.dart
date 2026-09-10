import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

/// A column in [V2GridTable]. Give it either a [fixed] pixel width or a [flex]
/// factor (matches the prototype's `146px 1.05fr .95fr …` grid tracks).
class V2Col {
  const V2Col(this.label, {this.fixed, this.flex = 1, this.align = TextAlign.start});
  final String label;
  final double? fixed;
  final double flex;
  final TextAlign align;

  double get minWidth => fixed ?? (flex * 140).roundToDouble();
}

class V2GridRow {
  const V2GridRow({
    required this.cells,
    this.actions = const [],
    this.onTap,
    this.selectable = false,
    this.selected = false,
    this.onToggleSelect,
  });
  final List<Widget> cells;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool selectable;
  final bool selected;
  final VoidCallback? onToggleSelect;
}

/// CSS-grid style data table from `Oons Ops Console v2.html` — sticky-feel
/// header, sand row dividers, hover tint, an always-visible action column and
/// horizontal scroll below a sensible min width.
class V2GridTable extends StatelessWidget {
  const V2GridTable({
    super.key,
    required this.columns,
    required this.rows,
    this.dense = false,
    this.actionsWidth = 190,
    this.bulkMode = false,
    this.emptyText,
    this.loading = false,
    this.skeletonRows = 6,
  });

  final List<V2Col> columns;
  final List<V2GridRow> rows;
  final bool dense;
  final double actionsWidth;
  final bool bulkMode;
  final String? emptyText;

  /// When true and there are no [rows] yet, render shimmer skeleton rows
  /// instead of the empty-state text.
  final bool loading;
  final int skeletonRows;

  static const _checkW = 34.0;
  static const _gap = 11.0;

  double get _minWidth {
    var w = (bulkMode ? _checkW + _gap : 0) + actionsWidth + _gap + 30;
    for (final c in columns) {
      w += c.minWidth + _gap;
    }
    return w;
  }

  List<Widget> _track(List<Widget> cells) {
    final out = <Widget>[];
    if (bulkMode) {
      out.add(SizedBox(width: _checkW, child: cells.isNotEmpty ? cells.first : const SizedBox()));
      out.add(const SizedBox(width: _gap));
    }
    final start = bulkMode ? 1 : 0;
    for (var i = 0; i < columns.length; i++) {
      final c = columns[i];
      final cell = (start + i) < cells.length ? cells[start + i] : const SizedBox();
      out.add(c.fixed != null
          ? SizedBox(width: c.fixed, child: cell)
          : Expanded(flex: (c.flex * 100).round(), child: cell));
      out.add(const SizedBox(width: _gap));
    }
    out.add(SizedBox(width: actionsWidth, child: cells.length > (start + columns.length) ? cells.last : const SizedBox()));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth < _minWidth ? _minWidth : box.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Ops.headBg,
                      border: Border(bottom: BorderSide(color: Ops.border)),
                    ),
                    child: Row(
                      children: _track([
                        if (bulkMode) const SizedBox(),
                        for (final c in columns)
                          Text(c.label,
                              textAlign: c.align,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Ops.greyInk)),
                        const SizedBox(),
                      ]),
                    ),
                  ),
                  if (rows.isEmpty && loading)
                    for (var i = 0; i < skeletonRows; i++)
                      _SkeletonRow(key: ValueKey('v2-skeleton-$i'), track: _track, dense: dense, bulkMode: bulkMode, seed: i)
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                      child: Center(
                        child: Text(emptyText ?? 'Nothing here yet',
                            style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      ),
                    )
                  else
                    for (final r in rows) _V2Row(row: r, dense: dense, track: _track, bulkMode: bulkMode),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _V2Row extends StatefulWidget {
  const _V2Row({required this.row, required this.dense, required this.track, required this.bulkMode});
  final V2GridRow row;
  final bool dense;
  final bool bulkMode;
  final List<Widget> Function(List<Widget> cells) track;

  @override
  State<_V2Row> createState() => _V2RowState();
}

class _V2RowState extends State<_V2Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: r.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: r.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: widget.dense ? 9 : 12),
          decoration: BoxDecoration(
            color: _hover ? Ops.rowHover : Colors.transparent,
            border: const Border(bottom: BorderSide(color: Ops.rowBorder)),
          ),
          child: Row(
            children: widget.track([
              if (widget.bulkMode)
                _Check(selected: r.selected, onTap: r.onToggleSelect),
              ...r.cells,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < r.actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    r.actions[i],
                  ],
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A shimmering placeholder row shown while the first page loads.
class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow({super.key, required this.track, required this.dense, required this.bulkMode, required this.seed});
  final List<Widget> Function(List<Widget> cells) track;
  final bool dense;
  final bool bulkMode;
  final int seed;

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double widthFactor) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: widthFactor,
        child: Container(
          height: 11,
          decoration: BoxDecoration(color: Ops.rowBorder, borderRadius: BorderRadius.circular(4)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Deterministic pseudo-random widths so rows don't look identical.
    final widths = [0.7, 0.55, 0.62, 0.4, 0.5, 0.45, 0.6];
    double w(int i) => widths[(i + widget.seed) % widths.length];
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: widget.dense ? 12 : 15),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.rowBorder))),
        child: Row(
          children: widget.track([
            if (widget.bulkMode) _bar(0.5),
            for (var i = 0; i < 6; i++) _bar(w(i)),
            const SizedBox(),
          ]),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, this.onTap});
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 17,
        height: 17,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: selected ? Ops.plum : Ops.cardAlt,
          border: Border.all(color: selected ? Ops.plum : const Color(0xFFC9BBA9)),
        ),
        child: selected ? const Icon(Icons.check, size: 11, color: Color(0xFFF6F0EF)) : null,
      ),
    );
  }
}
