import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/header.dart';
import 'package:oons/admin_v2/chrome/impersonation_banner.dart';
import 'package:oons/admin_v2/chrome/sidebar.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

class V2Shell extends ConsumerStatefulWidget {
  const V2Shell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<V2Shell> createState() => _V2ShellState();
}

class _V2ShellState extends ConsumerState<V2Shell> {
  String _lastPath = '';

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final sess = ref.watch(staffSessionProvider);
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 880;

    // Reset header search + extras whenever the route changes.
    if (path != _lastPath) {
      _lastPath = path;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(v2QueryProvider.notifier).state = '';
        ref.read(v2HeaderConfigProvider.notifier).state = const V2HeaderConfig();
      });
    }

    final query = ref.watch(v2QueryProvider);
    final headerCfg = ref.watch(v2HeaderConfigProvider);

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
          query: query,
          onSearch: (v) => ref.read(v2QueryProvider.notifier).state = v,
          newLabel: headerCfg.newLabel,
          onNewRecord: headerCfg.onNewRecord,
          liveCount: headerCfg.liveCount,
        ),
        Expanded(child: widget.child),
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
