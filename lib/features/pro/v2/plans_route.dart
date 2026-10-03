import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/subscribe/ar_eg.dart' show visitTypeForName;
import 'package:oons/features/subscribe/plan_wizard.dart';

/// `/pro/plans` — باقاتي for the signed-in provider, built from her live services.
class ProPlansRoute extends ConsumerWidget {
  const ProPlansRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).provider;
    if (me == null) return const Scaffold(body: SizedBox.shrink());
    final services = [
      for (final it in me.items)
        if (it.active && (it.approvalState.isEmpty || it.approvalState == 'approved'))
          PlanService(
            id: it.id,
            catalogItemId: it.catalogItemId ?? '',
            name: it.name.of('ar'),
            regularEgp: it.price ~/ 100,
            visitType: visitTypeForName(it.name.of('ar'), id: it.id),
          ),
    ];
    return PlanWizard(services: services, providerId: me.id);
  }
}
