import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/api.dart';
import 'package:oons/l10n/copy.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _cacheKey = 'app_update_config';

/// Native-only blocking gate. Web (lady / ops) always serves the latest
/// bundle, so it never reads this.
class ForceUpdateGate extends ConsumerStatefulWidget {
  const ForceUpdateGate({super.key});

  @override
  ConsumerState<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends ConsumerState<ForceUpdateGate> with WidgetsBindingObserver {
  Map<String, dynamic>? _cfg;
  int _build = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    _cfg = _readCache();
    unawaited(_boot());
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (!kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _boot() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _build = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}
    await _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    try {
      final data = await api.get('/public/app-config');
      if (!mounted) return;
      setState(() => _cfg = data);
      unawaited(Hive.box('prefs').put(_cacheKey, data));
    } catch (_) {
      // Fail open on first launch; keep the last successful config if we have one.
    }
  }

  Map<String, dynamic>? _readCache() {
    try {
      final v = Hive.box('prefs').get(_cacheKey);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  int get _minBuild {
    final cfg = _cfg;
    if (cfg == null) return 0;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return (cfg['iosMinBuild'] as num?)?.toInt() ?? 0;
      case TargetPlatform.android:
        return (cfg['androidMinBuild'] as num?)?.toInt() ?? 0;
      default:
        return 0;
    }
  }

  String get _storeUrl {
    final cfg = _cfg ?? const {};
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        final u = '${cfg['iosStoreUrl'] ?? ''}'.trim();
        return u.isEmpty ? 'https://apps.apple.com/eg/app/oons-app/id6811881656' : u;
      case TargetPlatform.android:
        final u = '${cfg['androidStoreUrl'] ?? ''}'.trim();
        return u.isEmpty ? 'https://play.google.com/store/apps/details?id=com.oons.oons' : u;
      default:
        return 'https://oons.app';
    }
  }

  bool get _blocked => !kIsWeb && _build > 0 && _minBuild > 0 && _build < _minBuild;

  @override
  Widget build(BuildContext context) {
    if (!_blocked) return const SizedBox.shrink();
    final lang = ref.watch(localeProvider).languageCode;
    final copy = Copy.of(lang)['forceUpdate'];
    final fallbackTitle = lang == 'ar' ? 'تحديث مطلوب' : 'Update required';
    final fallbackBody = lang == 'ar'
        ? 'هذا الإصدار من أنس لم يعد يعمل. ثبّتي الأحدث من المتجر للمتابعة.'
        : 'This version of Oons can no longer be used. Install the latest from the store to continue.';
    final fallbackCta = lang == 'ar' ? 'حدّثي أنس' : 'Update Oons';
    var title = fallbackTitle;
    var body = fallbackBody;
    var cta = fallbackCta;
    if (copy is Map) {
      title = '${copy['title'] ?? title}';
      body = '${copy['body'] ?? body}';
      cta = '${copy['cta'] ?? cta}';
    }
    final override = lang == 'ar' ? '${_cfg?['messageAr'] ?? ''}' : '${_cfg?['messageEn'] ?? ''}';
    if (override.trim().isNotEmpty) body = override.trim();

    return Positioned.fill(
      child: Material(
        color: T.bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandMark(size: 44),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: lang == 'ar' ? T.arabic : T.archivo,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: T.ink,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: lang == 'ar' ? T.arabic : T.archivo,
                    fontSize: 16,
                    height: 1.5,
                    color: T.body,
                  ),
                ),
                const Spacer(),
                InkButton(
                  label: cta,
                  onTap: () => unawaited(openExternal(_storeUrl)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
