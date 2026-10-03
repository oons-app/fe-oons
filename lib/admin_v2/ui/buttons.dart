import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

/// The console's buttons, in the design system's shapes: primary (plum),
/// ghost (white + ink border), danger (terracotta-light), impersonate (same
/// family), plus two variants for the plum bars. Square, 1px border, ≥44px
/// (38 / 32 for compact and table-row actions). One widget for all of them.
enum V2BtnKind { primary, ghost, danger, imp, light, darkGhost }

enum V2BtnSize { md, sm, row }

class V2Btn extends StatelessWidget {
  const V2Btn({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = V2BtnKind.ghost,
    this.size = V2BtnSize.md,
    this.icon,
    this.leadingDot,
    this.expand = false,
  });

  const V2Btn.primary(String label, {Key? key, VoidCallback? onPressed, V2BtnSize size = V2BtnSize.md, IconData? icon, bool expand = false})
      : this(key: key, label: label, onPressed: onPressed, kind: V2BtnKind.primary, size: size, icon: icon, expand: expand);
  const V2Btn.ghost(String label, {Key? key, VoidCallback? onPressed, V2BtnSize size = V2BtnSize.md, IconData? icon, bool expand = false})
      : this(key: key, label: label, onPressed: onPressed, kind: V2BtnKind.ghost, size: size, icon: icon, expand: expand);
  const V2Btn.danger(String label, {Key? key, VoidCallback? onPressed, V2BtnSize size = V2BtnSize.md, IconData? icon, bool expand = false})
      : this(key: key, label: label, onPressed: onPressed, kind: V2BtnKind.danger, size: size, icon: icon, expand: expand);
  const V2Btn.imp(String label, {Key? key, VoidCallback? onPressed, V2BtnSize size = V2BtnSize.md, bool expand = false})
      : this(key: key, label: label, onPressed: onPressed, kind: V2BtnKind.imp, size: size, expand: expand);

  final String label;
  final VoidCallback? onPressed;
  final V2BtnKind kind;
  final V2BtnSize size;
  final IconData? icon;
  final Color? leadingDot;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, Color border, FontWeight weight}) s = switch (kind) {
      V2BtnKind.primary => (bg: Ops.plum, fg: Ops.plumText, border: Ops.plum, weight: FontWeight.w700),
      V2BtnKind.ghost => (bg: Ops.card, fg: Ops.ink, border: Ops.border, weight: FontWeight.w600),
      V2BtnKind.danger => (bg: Ops.terracottaTint, fg: Ops.terracottaInk, border: Ops.terracotta, weight: FontWeight.w700),
      V2BtnKind.imp => (bg: Ops.impBg, fg: Ops.terracottaInk, border: Ops.impBorder, weight: FontWeight.w700),
      V2BtnKind.light => (bg: Ops.plumText, fg: Ops.plum, border: Ops.plumText, weight: FontWeight.w700),
      V2BtnKind.darkGhost => (bg: Colors.transparent, fg: Ops.plumText, border: Ops.plumMuted, weight: FontWeight.w600),
    };

    // 44px targets; table-row actions are the one pointer-only exception (32px).
    final (EdgeInsets pad, double fontSize, double minH) = switch (size) {
      V2BtnSize.md => (const EdgeInsets.symmetric(horizontal: 18, vertical: 9), 13.5, Ops.minTarget),
      V2BtnSize.sm => (const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 12.5, 38.0),
      V2BtnSize.row => (const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 11.5, 32.0),
    };
    final disabled = onPressed == null;

    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Material(
          color: s.bg,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              constraints: BoxConstraints(minHeight: minH),
              padding: pad,
              decoration: BoxDecoration(border: Border.all(color: s.border, width: Ops.rule)),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: expand ? MainAxisAlignment.center : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leadingDot != null) ...[
                    Container(width: 8, height: 8, color: leadingDot),
                    const SizedBox(width: 7),
                  ],
                  if (icon != null) ...[
                    Icon(icon, size: fontSize + 2, color: s.fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: s.weight, color: s.fg, height: 1.2))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
