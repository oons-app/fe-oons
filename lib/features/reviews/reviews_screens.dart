import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/reviews.dart';
import 'package:oons/l10n/copy.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, this.providerId});
  final String? providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final t = Copy.of(lang)['reviews'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: providerId == null ? '${t['all']}' : '${t['for']}', onBack: () => context.pop()),
            Expanded(
              child: FutureBuilder<List<Review>>(
                future: ref.read(repoProvider).reviews(providerId: providerId),
                builder: (context, snap) {
                  final list = snap.data ?? const <Review>[];
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: Client.plum));
                  }
                  if (list.isEmpty) {
                    return Center(child: Text('${t['empty']}', style: const TextStyle(color: Client.muted)));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => ReviewCard(review: list[i], lang: lang, showPro: providerId == null),
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

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, required this.lang, this.showPro = false, this.onTap});
  final Review review;
  final String lang;
  final bool showPro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Face(id: review.providerId, ini: '', size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showPro ? review.providerName.of(lang) : review.author.of(lang),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        showPro
                            ? '${review.author.of(lang)} · ${review.area.of(lang)}'
                            : review.area.of(lang),
                        style: const TextStyle(fontSize: 11, color: Client.muted),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 2),
                      child: Glyph(GlyphKind.star, size: 12, color: i < review.stars ? Client.plum : Client.line, fill: i < review.stars),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(review.body.of(lang), style: const TextStyle(fontSize: 13, height: 1.5)),
            if (review.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRect(
                    child: SizedBox(width: 72, height: 72, child: MediaThumb(review.images[i])),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...review.tags.map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                    child: Text(tag.of(lang), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                Text(review.date.of(lang), style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Client.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
