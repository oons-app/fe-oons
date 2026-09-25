import 'package:flutter/material.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/system/empty_states.dart';
import 'package:oons/l10n/copy.dart';

String _fill(String s, Map<String, String> v) => v.entries.fold(s, (a, e) => a.replaceAll('{${e.key}}', e.value));

Map _coverageCopy(String lang) => Copy.of(lang)['coverage'] as Map? ?? const {};

List<String> coverageSuggestions({String? exclude, List<dynamic>? fromApi, int limit = 3}) {
  final fromServer = <String>[
    for (final raw in fromApi ?? const [])
      if (raw is Map && '${raw['slug'] ?? ''}'.trim().isNotEmpty) '${raw['slug']}'.trim().toLowerCase(),
  ];
  if (fromServer.isNotEmpty) return fromServer.take(limit).toList();
  return suggestedCoveredAreaIds(exclude: exclude, limit: limit);
}

String coverageAreaList(List<String> slugs, String lang) {
  final names = [for (final s in slugs) areaName(s, lang)].where((n) => n.trim().isNotEmpty).toList();
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (lang == 'ar') {
    if (names.length == 2) return '${names[0]} أو ${names[1]}';
    return '${names.sublist(0, names.length - 1).join('، ')} أو ${names.last}';
  }
  if (names.length == 2) return '${names[0]} or ${names[1]}';
  return '${names.sublist(0, names.length - 1).join(', ')}, or ${names.last}';
}

/// Home / address compact notice: this area has no bookable pros yet.
class UncoveredAreaBanner extends StatelessWidget {
  const UncoveredAreaBanner({
    super.key,
    required this.lang,
    required this.area,
    required this.suggested,
    this.onChangeArea,
    this.onPickSuggested,
  });

  final String lang;
  final String area;
  final List<String> suggested;
  final VoidCallback? onChangeArea;
  final ValueChanged<String>? onPickSuggested;

  @override
  Widget build(BuildContext context) {
    final c = _coverageCopy(lang);
    final areaLabel = areaName(area, lang);
    final suggestLabel = coverageAreaList(suggested, lang);
    final title = _fill('${c['title'] ?? ''}', {'area': areaLabel});
    final body = suggestLabel.isEmpty
        ? _fill('${c['bodyNone'] ?? ''}', {'area': areaLabel})
        : _fill('${c['body'] ?? ''}', {'area': areaLabel, 'areas': suggestLabel});
    final promise = _fill('${c['promise'] ?? ''}', {'area': areaLabel});
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Client.warnTint,
        border: Border.all(color: Client.ink, width: Client.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnsIcon('pin', size: 18, color: Client.terracotta),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: Client.ink)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Client.body)),
          const SizedBox(height: 6),
          Text(promise, style: const TextStyle(fontSize: 13, height: 1.4, color: Client.muted)),
          if (suggested.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slug in suggested)
                  InkWell(
                    onTap: onPickSuggested == null ? null : () => onPickSuggested!(slug),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                      child: Text(areaName(slug, lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.ink)),
                    ),
                  ),
              ],
            ),
          ],
          if (onChangeArea != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkWell(
                onTap: onChangeArea,
                child: Text(
                  '${c['cta']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Browse empty list when the chosen area has no bookable professionals.
class UncoveredAreaEmpty extends StatelessWidget {
  const UncoveredAreaEmpty({
    super.key,
    required this.lang,
    required this.area,
    required this.suggested,
    required this.onPickSuggested,
    this.onAnyArea,
  });

  final String lang;
  final String area;
  final List<String> suggested;
  final ValueChanged<String> onPickSuggested;
  final VoidCallback? onAnyArea;

  @override
  Widget build(BuildContext context) {
    final c = _coverageCopy(lang);
    final areaLabel = areaName(area, lang);
    final suggestLabel = coverageAreaList(suggested, lang);
    final body = suggestLabel.isEmpty
        ? _fill('${c['bodyNone'] ?? ''}', {'area': areaLabel})
        : _fill('${c['body'] ?? ''}\n${_fill('${c['promise'] ?? ''}', {'area': areaLabel})}', {
            'area': areaLabel,
            'areas': suggestLabel,
          });
    final ctaArea = suggested.isNotEmpty ? suggested.first : '';
    return OnsEmptyState(
      icon: 'pin',
      title: _fill('${c['title'] ?? ''}', {'area': areaLabel}),
      body: body,
      cta: suggested.isEmpty ? '${c['ctaAny']}' : _fill('${c['ctaArea'] ?? ''}', {'area': areaName(ctaArea, lang)}),
      onCta: suggested.isEmpty ? onAnyArea : () => onPickSuggested(ctaArea),
      alt: onAnyArea == null || suggested.isEmpty ? null : '${c['ctaAny']}',
      onAlt: onAnyArea,
    );
  }
}

/// Returns the suggested slug the client picked, `''` if they keep the current
/// area, or `null` if they dismissed the sheet.
Future<String?> showUncoveredAreaSheet(
  BuildContext context, {
  required String lang,
  required String area,
  List<String> suggested = const [],
}) {
  final c = _coverageCopy(lang);
  final areaLabel = areaName(area, lang);
  final suggestLabel = coverageAreaList(suggested, lang);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Client.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fill('${c['title'] ?? ''}', {'area': areaLabel}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink, height: 1.3)),
              const SizedBox(height: 10),
              Text(
                suggestLabel.isEmpty
                    ? _fill('${c['bodyNone'] ?? ''}', {'area': areaLabel})
                    : _fill('${c['body'] ?? ''}', {'area': areaLabel, 'areas': suggestLabel}),
                style: const TextStyle(fontSize: 14, height: 1.5, color: Client.body),
              ),
              const SizedBox(height: 8),
              Text(_fill('${c['promise'] ?? ''}', {'area': areaLabel}), style: const TextStyle(fontSize: 13.5, height: 1.45, color: Client.muted)),
              if (suggested.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slug in suggested)
                      InkWell(
                        onTap: () => Navigator.pop(ctx, slug),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: Client.plum, border: Border.all(color: Client.ink, width: Client.rule)),
                          child: Text(areaName(slug, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.bg)),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ClientPrimaryButton(label: '${c['cta']}', onTap: suggested.isEmpty ? () => Navigator.pop(ctx, '') : () => Navigator.pop(ctx, suggested.first)),
              const SizedBox(height: 8),
              ClientGhostButton(label: '${c['keep']}', onTap: () => Navigator.pop(ctx, '')),
            ],
          ),
        ),
      );
    },
  );
}
