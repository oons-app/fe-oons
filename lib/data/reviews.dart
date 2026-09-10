import 'package:intl/intl.dart';
import 'package:oons/core/format.dart';

class Review {
  const Review({
    required this.providerId,
    required this.providerName,
    required this.author,
    required this.area,
    required this.stars,
    required this.body,
    required this.date,
    required this.tags,
    this.images = const [],
  });
  final String providerId;
  final Loc providerName;
  final Loc author;
  final Loc area;
  final int stars;
  final Loc body;
  final Loc date;
  final List<Loc> tags;
  final List<String> images;

  factory Review.fromJson(Map j) {
    final areaId = '${j['area'] ?? ''}';
    final created = DateTime.tryParse('${j['createdAt'] ?? ''}');
    final tagStrs = ((j['tags'] as List?) ?? []).map((e) => '$e').toList();
    Loc body;
    if (j['body'] is Map) {
      body = Loc.fromJson(j['body']);
    } else if ('${j['body'] ?? ''}'.isNotEmpty) {
      body = Loc('${j['body']}', '${j['body']}');
    } else {
      body = Loc(tagStrs.join(' · '), tagStrs.join(' · '));
    }
    return Review(
      providerId: '${j['providerId']}',
      providerName: Loc.fromJson(j['providerName'] ?? {}),
      author: Loc.fromJson(j['author'] ?? {}),
      area: Loc(areaName(areaId, 'en'), areaName(areaId, 'ar')),
      stars: (j['stars'] as num?)?.toInt() ?? 0,
      body: body,
      date: Loc(
        created == null ? '' : DateFormat('d MMM yyyy', 'en').format(created.toLocal()),
        created == null ? '' : DateFormat('d MMM yyyy', 'ar').format(created.toLocal()),
      ),
      tags: tagStrs.map((s) => Loc(s, s)).toList(),
      images: ((j['images'] as List?) ?? []).map((e) => '$e').where((s) => s.isNotEmpty).toList(),
    );
  }
}

/// Live reviews only — never invent marketing placeholders.
List<Review> reviewsFor(String? _) => const [];
