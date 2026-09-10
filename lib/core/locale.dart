import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/locale_stub.dart' if (dart.library.html) 'package:oons/core/locale_web.dart';

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(_load()) {
    syncWebLocale(state.languageCode);
  }

  static Locale _load() {
    final box = Hive.box('prefs');
    final code = box.get('locale', defaultValue: 'ar') as String;
    return Locale(code);
  }

  String get code => state.languageCode;

  Future<void> toggle() async {
    final next = state.languageCode == 'ar' ? 'en' : 'ar';
    await set(next);
  }

  Future<void> set(String code) async {
    await Hive.box('prefs').put('locale', code);
    state = Locale(code);
    syncWebLocale(code);
  }
}

bool isAr(WidgetRef ref) => ref.watch(localeProvider).languageCode == 'ar';
String langOf(WidgetRef ref) => ref.watch(localeProvider).languageCode;
