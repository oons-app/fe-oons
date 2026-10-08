import 'package:flutter/material.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/plan_models.dart';

/// The plan card shared by E2 (booking step 1) and S2 (plans). Straight from
/// the prototype: 4px top rule, optional recommended line, generated title,
/// per-line chips, struck pay-per-visit price, prominent subscription price,
/// olive save block (hidden when saving <= 0), and a select button.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
    this.buttonLabel = CC.startPlan,
    this.onButton,
  });

  final PlanData plan;
  final bool selected;
  final VoidCallback onTap;
  final String buttonLabel;

  /// Defaults to [onTap].
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    final border = selected ? Client.plum : Client.ink;
    final benefits = [for (final line in plan.includedBenefits) if (!isCleaningSuppliesBenefit(line)) line];
    return Semantics(
      container: true,
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          color: selected ? Client.plumTint : Client.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 4, color: selected ? Client.terracotta : Colors.transparent),
                  if (plan.recommended)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 7, 12, 0),
                      child: Text(
                        CC.recommended,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Client.terracotta),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.35),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [for (final l in plan.ordered) _chip(l)],
                        ),
                        if (benefits.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final line in benefits)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(line, style: const TextStyle(fontSize: 12.5, height: 1.45, color: Client.body)),
                            ),
                        ],
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.only(top: 9),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.line))),
                          child: _prices(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _button(),
          ],
        ),
      ),
    );
  }

  Widget _chip(PlanLine l) {
    final deep = l.deep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: deep ? Client.plum : Client.card,
        border: Border.all(color: deep ? Client.plum : Client.ink),
      ),
      child: Text(
        '${toArabicDigits(l.quantity)} × ${l.fullName}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deep ? Client.bg : Client.ink),
      ),
    );
  }

  Widget _prices() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(CC.paygLabel, style: TextStyle(fontSize: 10.5, color: Client.muted2)),
              Text(
                egpText(plan.paygPiastres),
                key: const ValueKey('plan-payg'),
                style: const TextStyle(
                  fontFamily: T.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Client.muted2,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(CC.subLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Client.plum)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: egpText(plan.pricePiastres),
                      style: const TextStyle(fontFamily: T.mono, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(
                      text: CC.perMonth,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Client.muted),
                    ),
                  ],
                ),
                key: const ValueKey('plan-sub'),
              ),
            ],
          ),
        ),
        if (plan.showSave) ...[
          const SizedBox(width: 10),
          Container(
            key: const ValueKey('plan-save'),
            color: Client.olive,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              CC.saveBlock(egpText(plan.savePiastres)),
              style: const TextStyle(color: Client.bg, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _button() {
    return Material(
      color: selected ? Client.plum : Client.card,
      child: InkWell(
        onTap: onButton ?? onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Client.ink))),
          child: Text(
            buttonLabel,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? Client.bg : Client.plum),
          ),
        ),
      ),
    );
  }
}
