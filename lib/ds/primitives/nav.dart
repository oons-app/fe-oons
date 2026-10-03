import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/ds/tokens.dart';

class DsNavItem {
  const DsNavItem({required this.label, required this.icon});
  final String label;
  final String icon;
}

/// Bottom navigation: icon + label, a 3px plum bar on top of the active tab.
class DsBottomNav extends StatelessWidget {
  const DsBottomNav({super.key, required this.items, required this.index, required this.onTap});
  final List<DsNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(color: Ds.cream, border: Border(top: BorderSide(color: Ds.divider, width: Ds.rule))),
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: items[i].label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onTap(i),
                  child: SizedBox(
                    height: 62,
                    child: Column(
                      children: [
                        Container(height: 3, color: i == index ? Ds.plum : Colors.transparent),
                        const Spacer(),
                        OnsIcon(items[i].icon, size: 22, color: i == index ? Ds.plum : Ds.textMuted),
                        const SizedBox(height: 3),
                        Text(items[i].label, style: TextStyle(fontSize: 11.5, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? Ds.plum : Ds.textMuted)),
                        const Spacer(),
                      ],
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
