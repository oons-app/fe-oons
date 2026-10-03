import 'package:flutter/material.dart';
import 'package:oons/ds/tokens.dart';

/// Bordered row of cells; the selected cell is plum with cream text. Cells are
/// divided by hairlines and each is at least 44px tall.
class DsSegmented extends StatelessWidget {
  const DsSegmented({super.key, required this.labels, required this.index, required this.onChanged, this.height = Ds.minTarget});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Ds.card(),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    height: height,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: Ds.s2),
                    decoration: BoxDecoration(
                      color: i == index ? Ds.plum : Ds.white,
                      border: BorderDirectional(start: i == 0 ? BorderSide.none : Ds.dividerSide),
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? Ds.cream : Ds.ink),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
