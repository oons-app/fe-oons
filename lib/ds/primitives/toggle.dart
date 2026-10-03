import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/tokens.dart';

/// Toggle chip: ink border; on = plum / cream, off = white / ink.
/// [mono] sets the label in IBM Plex Mono (hours, numbers).
class DsChip extends StatelessWidget {
  const DsChip({super.key, required this.label, required this.on, required this.onTap, this.mono = false, this.minWidth = 0});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final bool mono;
  final double minWidth;

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
        child: Container(
          constraints: BoxConstraints(minHeight: Ds.minTarget, minWidth: minWidth),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Ds.s3),
          decoration: BoxDecoration(color: on ? Ds.plum : Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w600, color: fg)
                : TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
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
