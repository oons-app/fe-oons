import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/bookings/bookings_screens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/client/client_tour.dart';
import 'package:oons/features/home/home_screen.dart';
import 'package:oons/features/pro/pro_services_screen.dart';
import 'package:oons/features/pro/pro_screens.dart';
import 'package:oons/features/pro/pro_tour.dart';
import 'package:oons/features/profile/profile_screen.dart';
import 'package:oons/l10n/copy.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    this.location,
    this.onTab,
    this.tabIndex,
  });
  final Widget child;
  final String? location;
  final ValueChanged<int>? onTab;
  final int? tabIndex;

  static const clientPaths = ['/home', '/bookings', '/profile'];
  static const proPaths = ['/pro/jobs', '/pro/services', '/pro/earnings', '/pro/account'];

  static List<String> pathsFor({required bool provider}) => provider ? proPaths : clientPaths;

  static int indexFor(String path, {required bool provider}) {
    final paths = pathsFor(provider: provider);
    for (var i = 0; i < paths.length; i++) {
      if (path == paths[i] || path.startsWith('${paths[i]}/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final provider = ref.watch(sessionProvider).isProvider;
    final tabs = ((provider ? t['proTabs'] : t['tabs']) as List).cast<String>();
    var path = location ?? '/home';
    if (location == null) {
      try {
        path = GoRouterState.of(context).uri.path;
      } catch (_) {
        path = '/home';
      }
    }
    final index = tabIndex ?? indexFor(path, provider: provider);
    return Scaffold(
      backgroundColor: provider ? T.bg : Client.bg,
      body: child,
      bottomNavigationBar: OonsTabBar(
        index: index.clamp(0, tabs.length - 1),
        labels: tabs,
        provider: provider,
        onTap: (i) => onTab != null ? onTab!(i) : null,
      ),
    );
  }
}

/// Tab chrome that switches locally. Does not call GoRouter — that was bouncing
/// every tap back to Home / onboard on Flutter web.
class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key, this.initialPath = '/home'});
  final String initialPath;

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = AppShell.indexFor(widget.initialPath, provider: false);
    clientShellTab.value = index;
    clientShellTab.addListener(_onExternalTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackTab(index));
  }

  @override
  void dispose() {
    clientShellTab.removeListener(_onExternalTab);
    super.dispose();
  }

  void _trackTab(int i) {
    final path = AppShell.clientPaths[i.clamp(0, AppShell.clientPaths.length - 1)];
    unawaited(AppAnalytics.logPageView(path));
  }

  void _onExternalTab() {
    final next = clientShellTab.value.clamp(0, AppShell.clientPaths.length - 1);
    if (next != index && mounted) {
      setState(() => index = next);
      _trackTab(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppShell.clientPaths[index],
      tabIndex: index,
      onTab: (i) {
        clientShellTab.value = i;
        setState(() => index = i);
        _trackTab(i);
      },
      child: IndexedStack(
        index: index,
        children: const [HomeScreen(), BookingsScreen(), ProfileScreen()],
      ),
    );
  }
}

class ProShell extends ConsumerStatefulWidget {
  const ProShell({super.key, this.initialPath = '/pro/jobs'});
  final String initialPath;

  @override
  ConsumerState<ProShell> createState() => _ProShellState();
}

class _ProShellState extends ConsumerState<ProShell> {
  late int index;

  @override
  void initState() {
    super.initState();
    index = AppShell.indexFor(widget.initialPath, provider: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackTab(index);
      if (!proTourDone() && mounted) {
        unawaited(showProTour(context, lang: langOf(ref)));
      }
    });
  }

  void _trackTab(int i) {
    final path = AppShell.proPaths[i.clamp(0, AppShell.proPaths.length - 1)];
    unawaited(AppAnalytics.logPageView(path));
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppShell.proPaths[index],
      tabIndex: index,
      onTab: (i) {
        setState(() => index = i);
        _trackTab(i);
      },
      child: IndexedStack(
        index: index,
        children: const [ProJobsScreen(), ProServicesScreen(), ProEarningsScreen(), ProAccountScreen()],
      ),
    );
  }
}
