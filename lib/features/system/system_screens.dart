import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/l10n/copy.dart';

class SystemScreen extends ConsumerWidget {
  const SystemScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final s = Copy.of(lang)['sys'] as Map;
    final map = {
      'empty': ['emptyTitle', 'emptyBody', Client.line],
      'error': ['errorTitle', 'errorBody', T.danger],
      'offline': ['offlineTitle', 'offlineBody', Client.terracotta],
      'payfail': ['payfailTitle', 'payfailBody', T.danger],
      'notfound': ['notfoundTitle', 'notfoundBody', Client.line],
    }[kind] ??
        ['errorTitle', 'errorBody', T.danger];
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.sand),
                alignment: AlignmentDirectional.topStart,
                child: Container(width: 44, height: 44, color: map[2] as Color),
              ),
              const SizedBox(height: 22),
              ClientKicker(kind.toUpperCase()),
              const SizedBox(height: 8),
              Text('${s[map[0]]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Client.ink)),
              const SizedBox(height: 12),
              Text('${s[map[1]]}', style: const TextStyle(fontSize: 15, height: 1.5, color: Client.body)),
              const Spacer(),
              ClientPrimaryButton(
                label: '${s['tryAgain']}',
                onTap: () => context.go('/home'),
              ),
              const SizedBox(height: 8),
              ClientGhostButton(
                label: '${s['support']}',
                onTap: () => context.go('/me/help'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
