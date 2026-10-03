import 'package:flutter/material.dart';
import 'package:oons/ds/primitives/button.dart';
import 'package:oons/ds/primitives/card.dart';
import 'package:oons/ds/tokens.dart';

/// The only empty state: 46px surface square with a 22px grey icon → one line
/// saying the fact → one line saying why → one primary action (+ an optional
/// text link). No illustrations, no apology.
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.cta,
    this.onCta,
    this.link,
    this.onLink,
    this.busy = false,
    this.padding = const EdgeInsets.fromLTRB(Ds.gutter, Ds.s8, Ds.gutter, Ds.s8),
  });

  final String icon;
  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onCta;
  final String? link;
  final VoidCallback? onLink;
  final bool busy;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconTile(icon),
          const SizedBox(height: Ds.s4),
          Text(title, style: DsText.section),
          const SizedBox(height: Ds.s1 + 2),
          Text(body, style: DsText.body),
          if (cta != null && onCta != null) ...[
            const SizedBox(height: Ds.s5),
            DsButton(label: cta!, onTap: onCta, busy: busy),
          ],
          if (link != null && onLink != null) ...[
            const SizedBox(height: Ds.s1),
            DsTextLink(link!, onTap: onLink),
          ],
        ],
      ),
    );
  }
}
