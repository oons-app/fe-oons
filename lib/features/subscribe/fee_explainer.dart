import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_copy.dart';

/// The `؟` square next to a fee line. Visual size [size] (16/18/20 in the
/// prototype) inside a >=44px hit area. Each use site owns its own `open`.
class FeeTipButton extends StatelessWidget {
  const FeeTipButton({super.key, required this.open, required this.onTap, this.size = 16});

  final bool open;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      expanded: open,
      label: CC.feeTipLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: open ? Client.plum : Client.card,
                  border: Border.all(color: Client.plum, width: 1),
                ),
                child: Text(
                  '؟',
                  style: TextStyle(
                    fontSize: size * 0.62,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: open ? Client.bg : Client.plum,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The explainer panel. Short (S2/S4 footers) = title + one paragraph.
/// Long (S6, on the fee row) = title + the four reasons + the closing line.
class FeeTipPanel extends StatelessWidget {
  const FeeTipPanel({super.key, this.long = false});

  final bool long;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: long ? 12 : 10),
      decoration: BoxDecoration(
        color: Client.plumTint,
        border: Border.all(color: Client.ink, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CC.feeTipTitle,
            style: TextStyle(
              fontSize: long ? 13 : 12.5,
              fontWeight: FontWeight.w700,
              color: Client.plum,
            ),
          ),
          SizedBox(height: long ? 8 : 6),
          if (!long)
            Text(
              CC.feeShort,
              style: const TextStyle(fontSize: 11.5, height: 1.6, color: Client.body),
            )
          else ...[
            for (final r in CC.feeReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: OnsIcon('check', size: 14, color: Client.plum, strokeWidth: 2.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(fontSize: 12, height: 1.55, color: Client.body),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              CC.feeClosing,
              style: TextStyle(fontSize: 11, height: 1.5, color: Client.muted),
            ),
          ],
        ],
      ),
    );
  }
}
