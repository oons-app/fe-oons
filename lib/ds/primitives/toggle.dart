import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/tokens.dart';

/// Toggle chip: ink border; on = plum / cream, off = white / ink.
/// [mono] sets the label in IBM Plex Mono (hours, numbers).
class DsChip extends StatelessWidget {
  const DsChip({super.key, required this.label, required this.on, required this.onTap, this.mono = false, this.minWidth = 0, this.compact = false});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final bool mono;
  final double minWidth;

  /// Tighter side padding, for rows of chips that must share one line.
  final bool compact;

  TextStyle _labelStyle(Color fg) => mono
      ? TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w600, color: fg)
      : TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg);

  @override
  Widget build(BuildContext context) {
    final fg = on ? Ds.cream : Ds.ink;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        // DecoratedBox + Center(widthFactor: 1): the chip is as wide as its label.
        // (A Container with `alignment` would stretch to the whole row inside a Wrap.)
        child: DecoratedBox(
          decoration: BoxDecoration(color: on ? Ds.plum : Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: Ds.minTarget, minWidth: minWidth),
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 2 : Ds.s3),
                child: compact
                    // In a tight row the label shrinks to fit rather than being cut («خميـ…»).
                    ? FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: _labelStyle(fg)))
                    : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _labelStyle(fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square 44×24 switch: ink border, square knob; on = plum track. The tap area
/// is padded to 44px tall. Always give it a [label] for screen readers.
class DsSwitch extends StatelessWidget {
  const DsSwitch({super.key, required this.on, required this.onChanged, required this.label});
  final bool on;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      label: label,
      enabled: onChanged != null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!on),
        child: SizedBox(
          width: 56,
          height: Ds.minTarget,
          child: Center(
            child: AnimatedContainer(
              duration: Ds.dState,
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              alignment: on ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              decoration: BoxDecoration(color: on ? Ds.plum : Ds.surface, border: Border.all(color: Ds.ink, width: Ds.rule)),
              child: Container(width: 16, height: 16, color: on ? Ds.cream : Ds.white, foregroundDecoration: on ? null : BoxDecoration(border: Border.all(color: Ds.ink, width: Ds.rule))),
            ),
          ),
        ),
      ),
    );
  }
}
