import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/l10n/copy.dart';

/// الشروط والسياسات — all five documents on one page.
class ProLegalScreen extends ConsumerWidget {
  const ProLegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = pv2(ref);
    final profile = Copy.of(langOf(ref))['profile'] as Map;
    final docs = [
      ('terms', '${profile['terms']}'),
      ('privacy', '${profile['privacy']}'),
      ('cancellation', '${profile['cancellation']}'),
      ('provider', '${profile['providerTerms']}'),
      ('consents', '${profile['consentGuide']}'),
    ];
    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            DsBackHeader(crumb: t('tabAccount'), onBack: () => context.canPop() ? context.pop() : context.go('/pro/account')),
            const SizedBox(height: Ds.s3),
            Text(t('legalTitle'), style: DsText.subTitle),
            const SizedBox(height: Ds.s4),
            DsCard.rows(children: [
              for (final d in docs) DsListRow(label: d.$2, icon: 'info', onTap: () => openLegal(context, d.$1)),
            ]),
          ],
        ),
      ),
    );
  }
}
