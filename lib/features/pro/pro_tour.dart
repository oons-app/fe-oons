import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/features/pro/pro_chrome.dart';

const _kProTourDone = 'pro_tour_done_v1';

bool proTourDone() {
  try {
    return Hive.box('prefs').get(_kProTourDone) == true;
  } catch (_) {
    return false;
  }
}

Future<void> setProTourDone([bool done = true]) async {
  try {
    await Hive.box('prefs').put(_kProTourDone, done);
  } catch (_) {}
}

Future<void> resetProTour() => setProTourDone(false);

/// 4-step RTL tour over the provider bottom nav.
Future<void> showProTour(BuildContext context, {required String lang}) async {
  final steps = lang == 'ar'
      ? const [
          ('الزيارات', 'هنا هتشوفي الزيارات الجاية واللي فاتت. دوسي على الزيارة للعنوان والـ QR.'),
          ('خدماتي', 'هنا بتعدّلي الخدمات والمناطق والمواعيد — وتنظيف بالمتر والعاملات.'),
          ('الأرباح', 'متاح للسحب، والفلوس الواقفة ٤٨ ساعة، وطريقة التحويل.'),
          ('حسابي', 'الرقم القومي والمستندات والإشعارات وإعادة الجولة.'),
        ]
      : const [
          ('Visits', 'Upcoming and past visits. Tap a visit for address and QR.'),
          ('Services', 'Edit services, areas, hours — including cleaning packages.'),
          ('Earnings', 'Available balance, 48h hold, and payout method.'),
          ('Account', 'National ID, docs, notifications, and replay this tour.'),
        ];

  var i = 0;
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tour',
    barrierColor: const Color(0xCC241820),
    pageBuilder: (ctx, _, __) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final step = steps[i];
          return SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                child: Material(
                  color: Pro.ink,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(lang == 'ar' ? 'جولة سريعة' : 'Quick tour',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(step.$1, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(step.$2, style: const TextStyle(color: Color(0xFFEDE4EA), fontSize: 14, height: 1.45)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await setProTourDone(true);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text(lang == 'ar' ? 'تخطّي' : 'Skip', style: const TextStyle(color: Colors.white70)),
                            ),
                            const Spacer(),
                            Text('${i + 1}/${steps.length}', style: const TextStyle(color: Colors.white54, fontFamily: 'IBMPlexMono')),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () async {
                                if (i >= steps.length - 1) {
                                  await setProTourDone(true);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } else {
                                  setLocal(() => i++);
                                }
                              },
                              child: Text(
                                i >= steps.length - 1 ? (lang == 'ar' ? 'تم' : 'Done') : (lang == 'ar' ? 'التالي' : 'Next'),
                                style: const TextStyle(color: Color(0xFFC9B39B), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
