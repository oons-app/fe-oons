import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/l10n/copy.dart';

/// Public booking page at `/p/:slug` — shareable provider link.
class PublicBookScreen extends ConsumerStatefulWidget {
  const PublicBookScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<PublicBookScreen> createState() => _PublicBookScreenState();
}

class _PublicBookScreenState extends ConsumerState<PublicBookScreen> {
  ProviderP? provider;
  List<Map<String, dynamic>> days = [];
  String? err;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(repoProvider);
      final p = await repo.publicProvider(widget.slug);
      final av = await repo.publicAvailability(widget.slug);
      if (mounted) {
        setState(() {
          provider = p;
          days = av;
          err = null;
          busy = false;
        });
        unawaited(AppAnalytics.publicProviderView(
          slug: widget.slug,
          providerName: p.name('en'),
          service: p.service,
        ));
        unawaited(AppAnalytics.logPageView(
          '/p/${widget.slug}',
          title: AppAnalytics.screenTitleForPath('/p/${widget.slug}', query: p.name('en')),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Prefer short API messages; strip Dio's long CORS essay for the UI.
          final raw = '$e';
          if (raw.contains('XMLHttpRequest') || raw.contains('CORS') || raw.contains('connection errored')) {
            err = langOf(ref) == 'ar'
                ? 'ما قدرناش نوصل للخادم من الرابط ده. جرّبي تحديث الصفحة.'
                : 'Could not reach the server from this link. Try refreshing.';
          } else {
            err = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
          }
          busy = false;
        });
      }
    }
  }

  void _book() {
    final p = provider;
    if (p == null) return;
    AppAnalytics.markBookingEntry('slug_page');
    AppAnalytics.markAcquisition('slug_page');
    final path = '/book/${p.id}';
    if (ref.read(sessionProvider).authed) {
      context.push(path);
      return;
    }
    Hive.box('prefs').put('pending_path', path);
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final pub = Copy.of(lang)['public'] as Map;
    final bar = Copy.of(lang)['ctaBar'] as Map;
    if (busy) {
      return const Scaffold(backgroundColor: Client.bg, body: Center(child: CircularProgressIndicator(color: Client.plum)));
    }
    if (provider == null) {
      return Scaffold(
        backgroundColor: Client.bg,
        body: SafeArea(
          child: ClientEmptyState(
            title: lang == 'ar' ? 'الرابط مش شغال' : 'Link not found',
            body: err ?? '${pub['missing']}',
            cta: lang == 'ar' ? 'الصفحة الرئيسية' : 'Go home',
            onCta: () => context.go('/home'),
          ),
        ),
      );
    }
    final p = provider!;
    final openSlots = days.expand((d) => (d['slots'] as List? ?? []).where((s) => s is Map && s['available'] == true)).length;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: lang == 'ar' ? 'احجزي مع' : 'Book with', onBack: () => context.canPop() ? context.pop() : context.go('/home')),
            Expanded(
              child: ListView(
                children: [
                  ClientProviderHero(
                    name: p.name(lang),
                    subtitle: '${p.specialty.of(lang)}${p.areas.isNotEmpty ? ' · ${areaName(p.areas.first, lang)}' : ''} · ${p.years} ${lang == 'ar' ? 'سنين' : 'yrs'}',
                    rating: p.rating,
                    reviewCount: p.reviewCount,
                    ini: p.initials.of(lang),
                    photo: p.photo,
                  ),
                  ClientTrustBanner(
                    text: lang == 'ar' ? 'متخصصة متأكدين منها — بطاقة، فيش، ومقابلة وش لوش.' : 'Vetted professional — ID, background check, in-person interview.',
                    link: lang == 'ar' ? 'أُنس ›' : 'Oons ›',
                    onTap: () => showClientVerifiedSheet(
                      context,
                      title: lang == 'ar' ? 'ONS TRUST' : 'ONS TRUST',
                      body: lang == 'ar'
                          ? 'كل متخصصة على أُنس متأكدين من هويتها وفيشها، واتقابلت وش لوش. فلوسك واقفة لحد ما الزيارة تخلص.'
                          : 'Every Oons professional is ID-verified, background-checked, and interviewed in person. Payment stays held until the visit ends.',
                      lang: lang,
                    ),
                  ),
                  if (p.bio != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Text(p.bio!.of(lang), style: const TextStyle(fontSize: 14, height: 1.5, color: Client.body)),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${pub['services']}'),
                        const SizedBox(height: 8),
                        ...p.items.map(
                          (it) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
                            child: Row(
                              children: [
                                Expanded(child: Text(it.name.of(lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Client.ink))),
                                Text('${it.duration} ${lang == 'ar' ? 'د' : 'min'} · ${money(it.price, lang)}', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.body)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClientKicker('${pub['slots']}'),
                        const SizedBox(height: 8),
                        Text('${pub['slotsHint']}'.replaceAll('{n}', '$openSlots'), style: const TextStyle(fontSize: 13, color: Client.muted, height: 1.45)),
                        const SizedBox(height: 12),
                        Text(
                          publicBookingUrl(p.slug ?? widget.slug),
                          style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Client.muted2),
                        ),
                        const SizedBox(height: 96),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ClientStickyBar(
              label: '${bar['from']}',
              price: money(p.priceFrom, lang),
              cta: '${pub['bookCta']}',
              note: lang == 'ar' ? 'هتسجلي دخول لو لسه مدخلتيش، وبعدين تكملي الحجز.' : 'Sign in if needed, then finish booking in the app.',
              onTap: _book,
            ),
          ],
        ),
      ),
    );
  }
}
