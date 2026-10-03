import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/ds/tokens.dart';

enum DsButtonKind { primary, secondary, danger }

/// True when the surrounding locale is Arabic.
bool dsIsAr(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode != 'en';

/// The one button. 54px (46px compact), square, label + optional trailing icon
/// pushed to the far end. A spinner replaces the icon while [busy]; a busy or
/// disabled button never fires twice.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = DsButtonKind.primary,
    this.icon,
    this.compact = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final DsButtonKind kind;

  /// Trailing icon (an Ons icon name). Primary defaults to `advance`; pass `''` for none.
  final String? icon;
  final bool compact;
  final bool busy;

  bool get _enabled => onTap != null && !busy;

  @override
  Widget build(BuildContext context) {
    final primary = kind == DsButtonKind.primary;
    final danger = kind == DsButtonKind.danger;
    final bg = !_enabled && primary
        ? Ds.divider
        : primary
            ? Ds.plum
            : danger
                ? Ds.terracottaBg
                : Ds.white;
    final fg = !_enabled && primary
        ? Ds.textFaint
        : primary
            ? Ds.cream
            : danger
                ? Ds.terracottaText
                : Ds.ink;
    final border = primary ? null : Border.all(color: danger ? Ds.terracotta : Ds.ink, width: Ds.rule);
    // icon == '' means "no icon" (a primary button otherwise shows `advance`).
    final trailing = busy ? null : (icon == null ? (primary ? 'advance' : null) : (icon!.isEmpty ? null : icon));
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: _enabled ? onTap : null,
          hoverColor: primary ? Ds.plumPressed : Ds.surface,
          child: Container(
            height: compact ? Ds.buttonHeightCompact : Ds.buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: Ds.s4),
            decoration: BoxDecoration(border: border),
            child: Row(
              children: [
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsText.button.copyWith(color: fg))),
                if (busy)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else if (trailing != null)
                  OnsIcon(trailing, size: 20, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Underlined 1px link. Never the only way to do something important.
class DsTextLink extends StatelessWidget {
  const DsTextLink(this.label, {super.key, required this.onTap, this.danger = false, this.small = false});
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = danger ? Ds.terracottaText : Ds.plum;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Ds.minTarget),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 12.5 : 14,
                fontWeight: FontWeight.w600,
                color: c,
                decoration: TextDecoration.underline,
                decorationColor: c,
                decorationThickness: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
