import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

class V2Header extends StatelessWidget {
  const V2Header({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lang,
    this.trailing,
    this.onSearch,
    this.searchHint,
  });

  final String title;
  final String subtitle;
  final String lang;
  final List<Widget>? trailing;
  final ValueChanged<String>? onSearch;
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 22, 14),
      decoration: const BoxDecoration(
        color: Ops.page,
        border: Border(bottom: BorderSide(color: Ops.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Ops.ink)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Ops.muted, height: 1.35)),
                ],
              ],
            ),
          ),
          if (onSearch != null)
            SizedBox(
              width: 200,
              child: TextField(
                decoration: InputDecoration(hintText: searchHint ?? t(V2Copy.search, lang), isDense: true),
                onSubmitted: onSearch,
              ),
            ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () => context.go(V2Paths.live),
            icon: const Icon(Icons.circle, size: 8, color: Ops.green),
            label: Text(lang == 'ar' ? 'مباشر' : 'Live'),
          ),
          if (trailing != null) ...trailing!,
        ],
      ),
    );
  }
}

String headerTitleFor(String path, String lang) {
  for (final g in v2Nav) {
    for (final i in g.items) {
      if (path == i.path || path.startsWith('${i.path}/')) {
        return lang == 'ar' ? i.labelAr : i.labelEn;
      }
    }
  }
  if (path.startsWith(V2Paths.matrix)) return lang == 'ar' ? 'مصفوفة الصلاحيات' : 'Role matrix';
  if (path.startsWith(V2Paths.impersonate)) return lang == 'ar' ? 'عرض الحساب' : 'Impersonating';
  return lang == 'ar' ? 'لوحة التشغيل' : 'Ops console';
}

String headerSubFor(String path, String lang) {
  if (path == V2Paths.home) {
    return lang == 'ar' ? 'ما يحتاج انتباهك اليوم.' : 'What needs your attention today.';
  }
  if (path == V2Paths.live) {
    return lang == 'ar' ? 'زيارات على الأرض — تحديث كل ٣٠ ثانية.' : 'On-ground visits — refreshes every 30s.';
  }
  if (path == V2Paths.bookings) {
    return lang == 'ar' ? 'ابحث وصفِّ وسوِّ الدفعات.' : 'Search, filter, and settle payouts.';
  }
  return '';
}
