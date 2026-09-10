import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/app/router.dart';
import 'package:oons/core/alert_toast_banner.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/l10n/app_localizations.dart';

class OonsApp extends ConsumerStatefulWidget {
  const OonsApp({super.key});
  @override
  ConsumerState<OonsApp> createState() => _OonsAppState();
}

class _OonsAppState extends ConsumerState<OonsApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    unawaited(_syncConnectivity());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      _applyConnectivity(r);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionProvider).authed) {
        ref.read(pushControllerProvider).start();
        unawaited(ref.read(sessionProvider.notifier).syncLocale());
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _syncConnectivity() async {
    try {
      _applyConnectivity(await Connectivity().checkConnectivity());
    } catch (_) {
      // Keep last known state if the plugin fails.
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    final online = results.any((e) => e != ConnectivityResult.none);
    ref.read(sessionProvider.notifier).setOnline(online);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    final toast = ref.watch(alertToastProvider);
    final online = ref.watch(sessionProvider).online;
    ref.listen(sessionProvider, (prev, next) {
      if (next.authed && (prev == null || prev.token != next.token)) {
        ref.read(pushControllerProvider).start();
        unawaited(ref.read(sessionProvider.notifier).syncLocale());
      }
      if (!next.authed) {
        ref.read(pushControllerProvider).stop();
      }
    });
    ref.listen(localeProvider, (prev, next) {
      if (ref.read(sessionProvider).authed) {
        unawaited(ref.read(sessionProvider.notifier).syncLocale());
      }
    });
    return MaterialApp.router(
      title: 'oons',
      debugShowCheckedModeBanner: false,
      theme: sanctuaryTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return PhoneCanvas(
          child: Builder(
            builder: (context) {
              final reduce = MediaQuery.disableAnimationsOf(context);
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(disableAnimations: reduce),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                      fontFamily: locale.languageCode == 'ar' ? T.arabic : T.archivo,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (!online)
                        ColoredBox(
                          color: const Color(0xFFF6E7E1),
                          child: SafeArea(
                            bottom: false,
                            child: const OfflineBanner(),
                          ),
                        ),
                      Expanded(
                        child: MediaQuery(
                          data: mq.copyWith(
                            disableAnimations: reduce,
                            padding: online ? mq.padding : mq.padding.copyWith(top: 0),
                            viewPadding: online ? mq.viewPadding : mq.viewPadding.copyWith(top: 0),
                          ),
                          child: Stack(
                            children: [
                              child ?? const SizedBox.shrink(),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, anim) {
                                    final slide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(anim);
                                    return FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(position: slide, child: child),
                                    );
                                  },
                                  child: toast == null
                                      ? const SizedBox.shrink(key: ValueKey('toast-empty'))
                                      : AlertToastBanner(
                                          key: ValueKey('toast-${toast.title}-${toast.body}'),
                                          toast: toast,
                                          onDismiss: () => ref.read(alertToastProvider.notifier).state = null,
                                          onOpen: () {
                                            final dest = toast.bookingId;
                                            ref.read(alertToastProvider.notifier).state = null;
                                            if (dest == null || dest.isEmpty) return;
                                            final path = ref.read(sessionProvider).isProvider ? '/pro/job/$dest' : '/visit/$dest';
                                            router.push(path);
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      routerConfig: router,
    );
  }
}

bool onboarded() => Hive.box('prefs').get('onboarded', defaultValue: false) == true;
