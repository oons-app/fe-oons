import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/l10n/copy.dart';

/// Empty states (design system §06). Fixed four parts, in order:
///   1. a 22px grey icon in a 46px bordered box
///   2. a headline stating what happened as a fact
///   3. one or two lines on why, or what would change the result
///   4. one clear button, optionally a weaker secondary link
/// No illustrations, no emoji, no dead ends. Values inside (counts, names,
/// dates) come from the caller's data — never hardcoded.
enum EmptyTone { neutral, warn }

class OnsEmptyState extends StatelessWidget {
  const OnsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.onCta,
    this.alt,
    this.onAlt,
    this.tone = EmptyTone.neutral,
    this.busy = false,
  });

  final String icon;
  final String title;
  final String body;
  final String cta;
  final VoidCallback? onCta;
  final String? alt;
  final VoidCallback? onAlt;
  final EmptyTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final warn = tone == EmptyTone.warn;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: warn ? Client.warnTint : Client.sand2,
                  border: Border.all(color: warn ? Client.terracotta : Client.ink, width: Client.rule),
                ),
                child: OnsIcon(icon, size: 22, color: warn ? Client.terracotta : Client.muted2),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: Client.ink)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Client.muted)),
              const SizedBox(height: 22),
              ClientPrimaryButton(label: cta, onTap: busy ? null : onCta, enabled: !busy && onCta != null, trailing: false),
              if (alt != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: onAlt,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      alt!,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _fill(String s, Map<String, String> v) => v.entries.fold(s, (a, e) => a.replaceAll('{${e.key}}', e.value));

/// The eight states. Each builder takes real values and real callbacks.
class OnsEmpty {
  OnsEmpty._();

  static Map _c(String lang) => Copy.of(lang)['empty'] as Map;

  /// EMPTY-01 · step 1, nothing picked.
  static Widget nothingPicked({required String lang, bool cleaning = true, required VoidCallback onBrowse}) {
    final c = _c(lang);
    return OnsEmptyState(
      icon: 'plus',
      title: '${c['nothingPickedTitle']}',
      body: '${c['nothingPickedBody']}',
      cta: '${cleaning ? c['nothingPickedCta'] : c['nothingPickedCtaGeneric']}',
      onCta: onBrowse,
    );
  }

  /// EMPTY-02 · step 2, no availability. The next-open-day and wider-area
  /// counts are omitted from the copy when unknown rather than invented.
  static Widget noAvailability({
    required String lang,
    required String area,
    required String day,
    String? nextDayLabel,
    int? nextCount,
    int? widerCount,
    required VoidCallback onNext,
    VoidCallback? onWiden,
  }) {
    final c = _c(lang);
    final ar = lang == 'ar';
    var body = '${c['noSlotsBody']}';
    if (nextDayLabel != null && nextCount != null && nextCount > 0) {
      body += _fill('${c['noSlotsNext']}', {'when': nextDayLabel, 'n': digits(nextCount, ar: ar)});
    }
    if (widerCount != null && widerCount > 0) {
      body += _fill('${c['noSlotsWider']}', {'n': digits(widerCount, ar: ar)});
    }
    return OnsEmptyState(
      icon: 'clock',
      title: _fill('${c['noSlotsTitle']}', {'area': area, 'day': day}).replaceAll(RegExp(r'\s+'), ' ').trim(),
      body: body,
      cta: '${c['noSlotsCta']}',
      onCta: onNext,
      alt: onWiden == null ? null : '${c['noSlotsAlt']}',
      onAlt: onWiden,
    );
  }

  /// EMPTY-03 · step 2, no saved address.
  static Widget noAddress({required String lang, required VoidCallback onAdd}) {
    final c = _c(lang);
    return OnsEmptyState(icon: 'pin', title: '${c['noAddressTitle']}', body: '${c['noAddressBody']}', cta: '${c['noAddressCta']}', onCta: onAdd);
  }

  /// Past bookings, nothing yet.
  static Widget noPast({required String lang, required VoidCallback onBrowse}) {
    final c = _c(lang);
    return OnsEmptyState(
      icon: 'calendar',
      title: '${c['noPastTitle']}',
      body: '${c['noPastBody']}',
      cta: '${c['noPastCta']}',
      onCta: onBrowse,
    );
  }

  /// EMPTY-04 · bookings, nothing upcoming. Pass the real last visit (provider
  /// name + formatted date) to offer a repeat; otherwise only browse is offered.
  static Widget noUpcoming({
    required String lang,
    String? lastProvider,
    String? lastDate,
    VoidCallback? onRepeat,
    required VoidCallback onBrowse,
  }) {
    final c = _c(lang);
    final hasLast = lastProvider != null && lastDate != null && onRepeat != null;
    return OnsEmptyState(
      icon: 'calendar',
      title: '${c['noUpcomingTitle']}',
      body: hasLast ? _fill('${c['noUpcomingBodyLast']}', {'provider': lastProvider, 'date': lastDate}) : '${c['noUpcomingBodyNone']}',
      cta: hasLast ? '${c['noUpcomingCta']}' : '${c['noUpcomingBrowse']}',
      onCta: hasLast ? onRepeat : onBrowse,
      alt: hasLast ? '${c['noUpcomingBrowse']}' : null,
      onAlt: hasLast ? onBrowse : null,
    );
  }

  /// EMPTY-05 · search, no match. [nearest] must be a real service name.
  static Widget noMatch({
    required String lang,
    required String query,
    String? nearest,
    required VoidCallback onNearest,
    VoidCallback? onSuggest,
  }) {
    final c = _c(lang);
    return OnsEmptyState(
      icon: 'search',
      title: _fill('${c['noMatchTitle']}', {'query': query}),
      body: nearest == null ? '${c['noMatchBodyNone']}' : _fill('${c['noMatchBodyNearest']}', {'nearest': nearest}),
      cta: nearest == null ? '${c['noMatchCtaGeneric']}' : _fill('${c['noMatchCta']}', {'nearest': nearest}),
      onCta: onNearest,
      alt: onSuggest == null ? null : '${c['noMatchAlt']}',
      onAlt: onSuggest,
    );
  }

  /// EMPTY-06 · account, no ratings yet.
  static Widget noRatings({required String lang, required VoidCallback onPast}) {
    final c = _c(lang);
    return OnsEmptyState(icon: 'star', title: '${c['noRatingsTitle']}', body: '${c['noRatingsBody']}', cta: '${c['noRatingsCta']}', onCta: onPast);
  }

  /// EMPTY-07 · offline. Only honest if the selection really is persisted
  /// (book_draft.dart does this for the booking flow).
  static Widget offline({required String lang, required VoidCallback onRetry}) {
    final c = _c(lang);
    return OnsEmptyState(icon: 'offline', tone: EmptyTone.warn, title: '${c['offlineTitle']}', body: '${c['offlineBody']}', cta: '${c['offlineCta']}', onCta: onRetry);
  }

  /// EMPTY-08 · catalogue fetch failed.
  static Widget fetchFailed({required String lang, required VoidCallback onRetry, required VoidCallback onSupport}) {
    final c = _c(lang);
    return OnsEmptyState(
      icon: 'alert',
      tone: EmptyTone.warn,
      title: '${c['failedTitle']}',
      body: '${c['failedBody']}',
      cta: '${c['failedCta']}',
      onCta: onRetry,
      alt: '${c['failedAlt']}',
      onAlt: onSupport,
    );
  }
}
