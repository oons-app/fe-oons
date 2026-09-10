import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/l10n/copy.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final rows = ref.watch(alertInboxProvider);
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p['notif']}', onBack: () => context.pop()),
            Expanded(
              child: rows.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Glyph(GlyphKind.bell, size: 28, color: Client.plum),
                        const SizedBox(height: 16),
                        Text('${p['notifBody']}', style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 12),
                        Text('${p['notifEmpty']}', style: const TextStyle(fontSize: 13, height: 1.45, color: Client.muted)),
                      ],
                    )
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final a = rows[i];
                        final loc = a.localized(lang, provider: ref.read(sessionProvider).isProvider);
                        return InkWell(
                          onTap: () => openAlertVisit(context, ref, a.bookingId),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Glyph(GlyphKind.bell, size: 18, color: Client.plum),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(loc.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(loc.$2, style: const TextStyle(fontSize: 13, height: 1.35, color: Client.muted)),
                                      if (a.at != null) ...[
                                        const SizedBox(height: 6),
                                        Text(_when(a.at!, lang), style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Client.muted)),
                                      ],
                                    ],
                                  ),
                                ),
                                if (a.bookingId != null && a.bookingId!.isNotEmpty)
                                  Icon(Icons.arrow_forward, size: 16, color: Client.muted, textDirection: Directionality.of(context)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at, String lang) {
  final t = at.toLocal();
  if (lang == 'ar') {
    return DateFormat('d MMM · h:mm a', 'ar').format(t).replaceAll('AM', 'ص').replaceAll('PM', 'م');
  }
  return DateFormat('d MMM · h:mm a').format(t);
}
