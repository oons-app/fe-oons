import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/header.dart';
import 'package:oons/admin_v2/chrome/impersonation_banner.dart';
import 'package:oons/admin_v2/chrome/sidebar.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

class V2Shell extends ConsumerWidget {
  const V2Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeCodeProvider);
    final sess = ref.watch(staffSessionProvider);
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 880;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sess.isImpersonating)
          V2ImpersonationBanner(
            name: sess.impersonatingName ?? sess.impersonatingId ?? '',
            kind: sess.impersonatingKind ?? 'provider',
            lang: lang,
            onExit: () {
              ref.read(staffSessionProvider.notifier).clearImpersonation();
              context.go(V2Paths.providers);
            },
          ),
        V2Header(
          title: headerTitleFor(path, lang),
          subtitle: headerSubFor(path, lang),
          lang: lang,
        ),
        Expanded(child: child),
      ],
    );

    if (compact) {
      return Scaffold(
        backgroundColor: Ops.page,
        drawer: Drawer(child: V2Sidebar(lang: lang)),
        appBar: AppBar(
          backgroundColor: Ops.plum,
          foregroundColor: Ops.plumText,
          title: Text(t(V2Copy.backOffice, lang), style: const TextStyle(fontSize: 14)),
        ),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: Ops.page,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2Sidebar(lang: lang),
          Expanded(child: body),
        ],
      ),
    );
  }
}
