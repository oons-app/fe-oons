import 'package:flutter/foundation.dart';

/// Cross-tab navigation inside the provider shell: «زوّدي مناطق» on الزيارات jumps
/// to خدماتي → المناطق, and so on. The shell listens to [tab]; the services tab
/// listens to [servicesSeg].
class ProNav {
  ProNav._();

  static const visits = 0, services = 1, earnings = 2, account = 3;
  static const segServices = 0, segAreas = 1, segHours = 2;

  static final tab = ValueNotifier<int>(visits);
  static final servicesSeg = ValueNotifier<int>(segServices);

  static void goServices({int seg = segServices}) {
    servicesSeg.value = seg;
    tab.value = services;
  }

  static void goAccount() => tab.value = account;
}
