import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

/// Button vocabulary from `Oons Ops Console v2.html`.
///
/// The prototype uses a small set of inline button styles — primary (plum),
/// ghost (sand outline), danger (terracotta outline), impersonate (warm fill),
/// plus two variants that sit on the dark plum bars. [V2Btn] is the single
/// widget for all of them so every screen stays consistent.
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
    final ({Color bg, Color fg, Color? border, FontWeight weight}) s = switch (kind) {
      V2BtnKind.primary => (bg: Ops.plum, fg: const Color(0xFFF6F0EF), border: null, weight: FontWeight.w600),
      V2BtnKind.ghost => (bg: Ops.card, fg: Ops.plumInk, border: Ops.borderStrong, weight: FontWeight.w500),
      V2BtnKind.danger => (bg: Ops.card, fg: Ops.terracottaInk, border: const Color(0xFFE3C9C0), weight: FontWeight.w600),
      V2BtnKind.imp => (bg: Ops.impBg, fg: Ops.terracottaInk, border: Ops.impBorder, weight: FontWeight.w600),
      V2BtnKind.light => (bg: Ops.plumTextSoft, fg: Ops.plum, border: null, weight: FontWeight.w700),
      V2BtnKind.darkGhost => (bg: Colors.transparent, fg: Ops.plumTextSoft, border: const Color(0x4DF1E8EE), weight: FontWeight.w500),
    };

    final (EdgeInsets pad, double fontSize) = switch (size) {
      V2BtnSize.md => (const EdgeInsets.symmetric(horizontal: 15, vertical: 9), 12.5),
      V2BtnSize.sm => (const EdgeInsets.symmetric(horizontal: 11, vertical: 6), 12.0),
      V2BtnSize.row => (const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 11.5),
    };
    final radius = size == V2BtnSize.row ? 8.0 : Ops.radiusBtn;
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: s.bg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: pad,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: s.border == null ? null : Border.all(color: s.border!),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: expand ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (leadingDot != null) ...[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: leadingDot, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                ],
                if (icon != null) ...[
                  Icon(icon, size: fontSize + 2, color: s.fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontSize: fontSize, fontWeight: s.weight, color: s.fg, fontFamily: Ops.sans)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
