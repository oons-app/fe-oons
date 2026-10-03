import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/tokens.dart';

/// White card, 1px ink border, no radius, no shadow. Rows inside a card are
/// separated by [DsCard.rows] / [DsListRow.divider], never by extra cards.
class DsCard extends StatelessWidget {
  const DsCard({super.key, required this.child, this.padding = const EdgeInsets.all(Ds.s4), this.color, this.border, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? border;
  final VoidCallback? onTap;

  /// A card whose children are full-bleed rows divided by hairlines.
  static Widget rows({Key? key, required List<Widget> children, Color? color, Color? border}) => DecoratedBox(
        key: key,
        decoration: Ds.card(color: color, border: border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : Ds.dividerSide)),
                child: children[i],
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final box = Container(width: double.infinity, padding: padding, decoration: Ds.card(color: color, border: border), child: child);
    if (onTap == null) return box;
    return InkWell(onTap: onTap, child: box);
  }
}

/// icon · label · value · chevron. 56px tall, full-width tap target.
class DsListRow extends StatelessWidget {
  const DsListRow({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.valueColor,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
    this.trailing,
    this.background,
    this.subtitle,
  });

  final String label;
  final String? icon;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;
  final Widget? trailing;
  final Color? background;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? Ds.terracottaText : Ds.ink;
    final row = Container(
      constraints: const BoxConstraints(minHeight: Ds.rowHeight),
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: Ds.s4, vertical: Ds.s2),
      child: Row(
        children: [
          if (icon != null) ...[OnsIcon(icon!, size: 20, color: danger ? Ds.terracottaText : Ds.plum), const SizedBox(width: Ds.s3)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: DsText.meta)),
              ],
            ),
          ),
          if (value != null && value!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Ds.s2),
              child: Text(value!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? Ds.textMuted)),
            ),
          if (trailing != null) trailing!,
          if (onTap != null && showChevron) OnsIcon('advance', size: 18, color: Ds.textFaint),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: [label, if (value != null) value!].join(' · '),
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Section title with an optional action link or a meta line on the far side.
class DsSectionHeader extends StatelessWidget {
  const DsSectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.meta, this.padding = EdgeInsets.zero});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? meta;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: DsText.section)),
          if (meta != null) Text(meta!, style: DsText.meta),
          if (actionLabel != null && onAction != null) _Link(actionLabel!, onAction!),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Ds.minTarget),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Ds.plum, decoration: TextDecoration.underline, decorationColor: Ds.plum)),
            ),
          ),
        ),
      );
}

class DsStat {
  const DsStat({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;

  /// The last cell of a strip is usually plum-light.
  final bool accent;
}

/// One bordered strip of stat cells (value in mono, label under it).
class DsStatStrip extends StatelessWidget {
  const DsStatStrip({super.key, required this.items});
  final List<DsStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Ds.card(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  label: '${items[i].label} ${items[i].value}',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Ds.s3, horizontal: Ds.s2),
                    decoration: BoxDecoration(
                      color: items[i].accent ? Ds.plumLight : Ds.white,
                      border: BorderDirectional(start: i == 0 ? BorderSide.none : Ds.dividerSide),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(items[i].value, style: DsText.num(size: 22, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(items[i].label, style: DsText.meta, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Determinate bar: ink border, plum fill. Pass null for "unknown" and no
/// number is implied.
class DsMeter extends StatelessWidget {
  const DsMeter({super.key, required this.value, this.height = 10});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(widthFactor: v, heightFactor: 1, child: const ColoredBox(color: Ds.plum)),
    );
  }
}

/// 46px surface square holding a 22px grey icon (specialty / category tiles).
class DsIconTile extends StatelessWidget {
  const DsIconTile(this.icon, {super.key, this.size = 46, this.color = Ds.textMuted});
  final String icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: Ds.surface,
        child: OnsIcon(icon, size: 22, color: color),
      );
}

/// The mono kicker used for tiny caps labels.
class DsKicker extends StatelessWidget {
  const DsKicker(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: Ds.textMuted));
}
