import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/ds/primitives/button.dart';
import 'package:oons/ds/tokens.dart';

/// 40px bordered back square + breadcrumb («خدماتي · التنظيف المنزلي»).
class DsBackHeader extends StatelessWidget {
  const DsBackHeader({super.key, required this.crumb, required this.onBack});
  final String crumb;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ar = dsIsAr(context);
    return Row(
      children: [
        Semantics(
          button: true,
          label: ar ? 'رجوع' : 'Back',
          excludeSemantics: true,
          child: InkWell(
            onTap: onBack,
            // 40px square drawn inside a 44px target.
            child: SizedBox(
              width: Ds.minTarget,
              height: Ds.minTarget,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
                  child: OnsIconOnly('back', semanticLabel: ar ? 'رجوع' : 'Back', size: 20, color: Ds.ink),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Ds.s3),
        Expanded(child: Text(crumb, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsText.meta.copyWith(fontSize: 13, color: Ds.textMuted, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// A surface block that pulses while content loads; shaped like what it stands for.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton({super.key, this.height = 16, this.width});
  final double height;
  final double? width;
  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        color: Color.lerp(Ds.surface, Ds.divider, reduce ? 0 : _c.value * 0.6),
      ),
    );
  }
}

/// Skeleton for a list of card rows (name + meta line) so lists never show a
/// full-screen spinner.
class DsSkeletonRows extends StatelessWidget {
  const DsSkeletonRows({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Ds.card(),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Container(
              padding: const EdgeInsets.all(Ds.s4),
              decoration: BoxDecoration(border: Border(top: i == 0 ? BorderSide.none : Ds.dividerSide)),
              child: const Row(
                children: [
                  DsSkeleton(height: 46, width: 46),
                  SizedBox(width: Ds.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [DsSkeleton(height: 14, width: 140), SizedBox(height: 8), DsSkeleton(height: 11, width: 90)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
