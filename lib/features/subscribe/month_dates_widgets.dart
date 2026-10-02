import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/plan_calendar.dart';

// Presentational pieces of S4 (month dates). Colours/metrics follow
// cleaning_template.html lines 709-825; only `Client` tokens (+ the few
// prototype greys that have no token, kept private here).

const _pastFg = Color(0xFFC9C1BA);
const _tabIdleFg = Color(0xFF7E7570);
const _errFg = Color(0xFF7A3F2C);

TextStyle _mono(double size, FontWeight w, Color c, {TextDecoration? deco, double? height}) =>
    TextStyle(fontFamily: T.mono, fontSize: size, fontWeight: w, color: c, decoration: deco, height: height);

// ── Tabs: كل أسبوع / أختار كل زيارة ─────────────────────────────────────────

class ScheduleModeTabs extends StatelessWidget {
  const ScheduleModeTabs({super.key, required this.weekly, required this.onWeekly, required this.onCustom});
  final bool weekly;
  final VoidCallback onWeekly, onCustom;

  @override
  Widget build(BuildContext context) {
    Widget tab(Key key, String label, bool on, VoidCallback tap, {bool divider = false}) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              key: key,
              onTap: tap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: on ? Client.plum : Client.sand2,
                  border: divider ? const Border(left: BorderSide(color: Client.ink, width: Client.rule)) : null,
                ),
                child: Column(
                  children: [
                    Container(height: 4, color: on ? Client.terracotta : Colors.transparent),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 9, 6, 10),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Client.bg : _tabIdleFg),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
      decoration: const BoxDecoration(color: Client.sand2, border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tab(const Key('tab-weekly'), 'كل أسبوع', weekly, onWeekly, divider: true),
            tab(const Key('tab-custom'), 'أختار كل زيارة', !weekly, onCustom),
          ],
        ),
      ),
    );
  }
}

// ── Message lines ───────────────────────────────────────────────────────────

/// Blocking message: terracotta (rejected tap, server error).
class ScheduleErrorLine extends StatelessWidget {
  const ScheduleErrorLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: Client.warnTint, border: Border.all(color: Client.terracotta, width: Client.rule)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: OnsIcon('alert', size: 16, color: Client.defer)),
              const SizedBox(width: 9),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5, color: _errFg))),
            ],
          ),
        ),
      );
}

/// Informational message: plum tint + olive text (time fallback, auto-shift,
/// hold renewed). Never error-styled.
class ScheduleInfoLine extends StatelessWidget {
  const ScheduleInfoLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: Client.plumTint, border: Border.all(color: Client.line, width: Client.rule)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: OnsIcon('info', size: 16, color: Client.oliveInk)),
              const SizedBox(width: 9),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5, color: Client.oliveInk))),
            ],
          ),
        ),
      );
}

// ── Calendar grid ───────────────────────────────────────────────────────────

const kDowLabels = ['سبت', 'حد', 'اتنين', 'تلات', 'أربع', 'خميس', 'جمعة'];

class ScheduleGrid extends StatelessWidget {
  const ScheduleGrid({
    super.key,
    required this.cells,
    required this.types,
    required this.onTap,
  });
  final List<CalCell> cells;

  /// Per-visit type ('deep'|'regular'), by visit index.
  final List<String> types;
  final void Function(CalCell cell) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 6 ? 0 : 3, bottom: 3),
                  child: Text(
                    kDowLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: i == 6 ? Client.terracotta : Client.muted),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 3),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 6 ? 0 : 3),
                      child: _CalCellView(
                        cell: cells[r * 7 + i],
                        deep: cells[r * 7 + i].visitIndex != null &&
                            cells[r * 7 + i].visitIndex! < types.length &&
                            types[cells[r * 7 + i].visitIndex!] == 'deep',
                        onTap: onTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CalCellView extends StatelessWidget {
  const _CalCellView({required this.cell, required this.deep, required this.onTap});
  final CalCell cell;
  final bool deep;
  final void Function(CalCell) onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Client.card, fg = Client.ink, border = Client.line;
    var weight = FontWeight.w500;
    TextDecoration? deco;
    switch (cell.kind) {
      case CellKind.visit:
        bg = deep ? Client.plum : Client.plumTint;
        fg = deep ? Client.bg : Client.plum;
        border = Client.plum;
        weight = FontWeight.w700;
      case CellKind.past:
      case CellKind.closed:
      case CellKind.unbookable:
        bg = Colors.transparent;
        fg = _pastFg;
        border = Colors.transparent;
      case CellKind.off:
        bg = Client.sand;
        fg = Client.muted2;
      case CellKind.full:
        bg = Client.sand;
        fg = Client.muted2;
        deco = TextDecoration.lineThrough;
      case CellKind.outOfCycle:
        bg = Client.bg;
        fg = Client.muted2;
      case CellKind.inCycle:
        break;
    }
    final k = cell.date;
    final key = dateKey(k);
    final status = switch (cell.kind) {
      CellKind.visit => 'زيارة ${arDigits(cell.visitIndex! + 1)}',
      CellKind.off => 'إجازتها',
      CellKind.full => 'محجوز بالكامل',
      CellKind.closed => 'مش من أيام الباقة',
      CellKind.past || CellKind.unbookable => 'مش متاح',
      _ => 'متاح',
    };
    return Semantics(
      button: cell.tappable,
      selected: cell.editing,
      label: '${dLabel(k)} · $status',
      excludeSemantics: true,
      child: InkWell(
        key: Key('cell-$key'),
        onTap: () => onTap(cell),
        child: Container(
          height: 44,
          decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: Client.rule)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(arDigits(k.day), style: _mono(13, weight, fg, deco: deco)),
              if (cell.kind == CellKind.visit)
                Positioned(left: 2, top: 1, child: Text(arDigits(cell.visitIndex! + 1), style: _mono(8.5, FontWeight.w600, fg))),
              if (cell.isToday) Positioned(bottom: 2, child: Container(width: 12, height: 2, color: Client.terracotta)),
              if (cell.editing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(decoration: BoxDecoration(border: Border.all(color: Client.terracotta, width: 2))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleLegend extends StatelessWidget {
  const ScheduleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color bg, Color? border, String label, {bool strike = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 11, height: 11, decoration: BoxDecoration(color: bg, border: border == null ? null : Border.all(color: border, width: 1))),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 10.5, color: Client.muted, decoration: strike ? TextDecoration.lineThrough : null)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(Client.plum, null, 'مميز'),
        item(Client.plumTint, Client.plum, 'عادي'),
        item(Client.sand, Client.line, 'إجازتها (الجمعة)'),
        item(Client.sand, Client.line, 'محجوز بالكامل', strike: true),
      ],
    );
  }
}

// ── Visit list ──────────────────────────────────────────────────────────────

class ScheduleVisitList extends StatelessWidget {
  const ScheduleVisitList({
    super.key,
    required this.visits,
    required this.types,
    required this.activeIndex,
    required this.interactive,
    required this.onSelect,
    this.highlightActive = false,
  });
  final List<PlanVisit> visits;
  final List<String> types;
  final int activeIndex;
  final bool interactive;

  /// Ring the active row even when rows are not tappable (reschedule screen).
  final bool highlightActive;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink, width: Client.rule))),
      child: Column(
        children: [
          for (var i = 0; i < visits.length; i++)
            _VisitRow(
              key: Key('visit-row-$i'),
              index: i,
              visit: visits[i],
              deep: i < types.length && types[i] == 'deep',
              on: (interactive || highlightActive) && i == activeIndex,
              interactive: interactive,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({super.key, required this.index, required this.visit, required this.deep, required this.on, required this.interactive, required this.onTap});
  final int index;
  final PlanVisit visit;
  final bool deep, on, interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tagBg = deep ? Client.plum : Client.card;
    final tagFg = deep ? Client.bg : Client.ink;
    final tagBorder = deep ? Client.plum : Client.ink;
    final typeLabel = deep ? 'مميز' : 'عادي';
    return Semantics(
      button: interactive,
      selected: on,
      label: 'زيارة ${arDigits(index + 1)} · ${dLabel(visit.date)} · ${periodLabel(visit.time)} · $typeLabel',
      excludeSemantics: true,
      child: InkWell(
        onTap: interactive ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: on ? Client.plumTint : Client.bg,
            border: const Border(bottom: BorderSide(color: Client.line, width: Client.rule)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: deep ? Client.plum : Client.plumTint, border: Border.all(color: Client.plum, width: 1)),
                      child: Text(arDigits(index + 1), style: _mono(10.5, FontWeight.w600, deep ? Client.bg : Client.plum)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dLabel(visit.date), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Client.ink)),
                          if (visit.shifted) const Text(kMsgShifted, style: TextStyle(fontSize: 10.5, color: Client.defer)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(periodShort(visit.time), style: _mono(12, FontWeight.w500, Client.body)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: tagBg, border: Border.all(color: tagBorder, width: 1)),
                      child: Text(typeLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: tagFg)),
                    ),
                  ],
                ),
              ),
              if (on) Positioned(right: 0, top: 0, bottom: 0, child: Container(width: 3, color: Client.terracotta)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time chips ──────────────────────────────────────────────────────────────

class ScheduleTimeChips extends StatelessWidget {
  const ScheduleTimeChips({super.key, required this.chips, required this.onPick});
  final List<TimeChip> chips;
  final void Function(String time) onPick;

  @override
  Widget build(BuildContext context) {
    // A day has two periods (morning / afternoon): two wide chips, not a grid of hours.
    final cols = chips.length <= 2 ? 2 : 3;
    final rows = <Widget>[];
    for (var i = 0; i < chips.length; i += cols) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
        child: Row(
          children: [
            for (var j = 0; j < cols; j++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: j == cols - 1 ? 0 : 6),
                  child: i + j < chips.length ? _Chip(chip: chips[i + j], onPick: onPick) : const SizedBox(height: 52),
                ),
              ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip, required this.onPick});
  final TimeChip chip;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final off = !chip.enabled;
    final bg = off ? Client.sand : chip.selected ? Client.plum : Client.card;
    final fg = off ? Client.muted2 : chip.selected ? Client.bg : Client.ink;
    final border = off ? Client.line : Client.ink;
    return MouseRegion(
      cursor: off ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: Semantics(
        button: true,
        enabled: !off,
        selected: chip.selected,
        label: '${chip.label} · ${chip.note}',
        excludeSemantics: true,
        child: InkWell(
          key: Key('chip-${chip.time}'),
          onTap: off ? null : () => onPick(chip.time),
          child: Container(
            height: 52,
            decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: Client.rule)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(chip.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mono(12.5, FontWeight.w600, fg)),
                Opacity(opacity: .85, child: Text(chip.note, style: TextStyle(fontSize: 9.5, color: fg, height: 1.2))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cream section label in the prototype's mono kicker style.
class ScheduleKicker extends StatelessWidget {
  const ScheduleKicker(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.1, color: Client.muted2));
}

/// Sticky-bar CTA: 54px, disabled = sand fill + faint text.
class ScheduleCta extends StatelessWidget {
  const ScheduleCta({super.key, required this.label, required this.enabled, required this.onTap, this.busy = false});
  final String label;
  final bool enabled, busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? Client.plum : Client.line;
    final fg = enabled ? Client.bg : Client.muted2;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: InkWell(
          key: const Key('schedule-cta'),
          onTap: enabled && !busy ? onTap : null,
          child: Container(
            height: 54,
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg))),
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else
                  OnsIcon('advance', size: 20, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Template header: back arrow (mirrors in RTL), 18px title, 11.5px subtitle,
/// 1px ink rule under it.
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({super.key, required this.title, this.subtitle, required this.onBack});
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 14, 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
      child: Row(
        children: [
          InkWell(
            key: const Key('schedule-back'),
            onTap: onBack,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: OnsIconOnly('back', semanticLabel: 'رجوع', size: 21, color: Client.ink)),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Client.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Client.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
