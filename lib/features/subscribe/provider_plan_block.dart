import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/subscribe/customer_api.dart';
import 'package:oons/features/subscribe/customer_copy.dart';
import 'package:oons/features/subscribe/plan_models.dart';

/// S1 info block on the provider profile: «عندها N باقات شهرية» plus the
/// description line with the best monthly saving (loaded from the plan list;
/// without it the line keeps only the sentence that needs no number).
class ProviderPlanInfoBlock extends ConsumerStatefulWidget {
  const ProviderPlanInfoBlock({super.key, required this.providerId, required this.count, this.fallbackPct = 0});

  final String providerId;
  final int count;
  final int fallbackPct;

  @override
  ConsumerState<ProviderPlanInfoBlock> createState() => _ProviderPlanInfoBlockState();
}

class _ProviderPlanInfoBlockState extends ConsumerState<ProviderPlanInfoBlock> {
  List<PlanData>? plans;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(customerSubApiProvider).get('/providers/${widget.providerId}/plans');
      if (!mounted) return;
      setState(() => plans = PlanData.listFrom(r['plans']));
    } catch (_) {
      // The block still renders from the badge data on the profile.
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = plans;
    final n = list != null && list.isNotEmpty ? list.length : widget.count;
    final save = list == null ? 0 : maxSavePiastres(list);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(border: Border.all(color: Client.ink), color: Client.plumTint),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: OnsIcon('retry', size: 20, color: Client.plum),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CC.s1BlockTitle(n), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  save > 0 ? CC.s1BlockBodyFull(egpText(save)) : '${CC.s1BlockBody}.',
                  style: const TextStyle(fontSize: 12.5, height: 1.55, color: Client.body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
