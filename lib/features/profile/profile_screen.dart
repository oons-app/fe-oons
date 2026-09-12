import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/client/client_tour.dart';
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
    });
  }

  int _profilePct(UserMe? user) {
    if (user == null) return 0;
    var score = 20;
    if (user.addresses.isNotEmpty) score += 20;
    final hasReach = user.addresses.any((a) => a.reachNotes.of('en').trim().isNotEmpty || a.reachNotes.of('ar').trim().isNotEmpty);
    if (hasReach) score += 15;
    if (user.hasPhoto) score += 15;
    if (user.hasNationalId) score += 15;
    if (user.hasIdPhoto) score += 15;
    return score.clamp(0, 100);
  }

  String _promptBody(UserMe? user, Map p, String lang) {
    if (user == null) return '${p['identityPromptBody']}';
    if (!user.identityComplete) return '${p['identityPromptBody']}';
    return lang == 'ar'
        ? 'زودي علامة مميزة على عنوان البيت — بيقلّل تأخير الوصول لنص.'
        : 'Add a landmark on your home address — cuts arrival delays in half.';
  }

  VoidCallback _promptAction(UserMe? user, BuildContext context) {
    if (user == null || !user.identityComplete) {
      return () => context.push('/me/identity');
    }
    return () => context.push('/me/addresses');
  }

  String _promptCta(UserMe? user, Map p, String lang) {
    if (user == null || !user.identityComplete) return '${p['identityPromptCta']}';
    return lang == 'ar' ? 'كمّلي دلوقتي' : 'Finish now';
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final p = t['profile'] as Map;
    final user = ref.watch(sessionProvider).user;
    final pct = _profilePct(user);
    final ini = user?.initials.of(lang) ?? (lang == 'ar' ? 'ن أ' : 'N A');
    final menu = <({String icon, String label, String meta, VoidCallback onTap, bool danger})>[
      (icon: '▣', label: '${p['identity']}', meta: user?.identityComplete == true ? (lang == 'ar' ? 'مكتمل' : 'Done') : (lang == 'ar' ? 'مطلوب' : 'Needed'), onTap: () => context.push('/me/identity'), danger: false),
      (icon: '★', label: '${p['reviews']}', meta: lang == 'ar' ? 'اقري التقييمات' : 'Read them', onTap: () => context.push('/reviews'), danger: false),
      (icon: '◉', label: '${p['addresses']}', meta: '${user?.addresses.length ?? 0}', onTap: () => context.push('/me/addresses'), danger: false),
      (icon: '✎', label: '${p['instructions']}', meta: '${user?.instructions.length ?? 0}', onTap: () => context.push('/me/instructions'), danger: false),
      (icon: '▣', label: '${p['pay']}', meta: lang == 'ar' ? 'بطاقة، محفظة موبايل' : 'Card, Mobile Wallet', onTap: () => context.push('/me/pay'), danger: false),
      (icon: '♡', label: '${p['saved']}', meta: '${user?.savedIds.length ?? 0}', onTap: () => context.push('/me/saved'), danger: false),
      (icon: '◎', label: '${p['notif']}', meta: lang == 'ar' ? 'رسائل + إشعارات' : 'SMS + push', onTap: () => context.push('/me/notif'), danger: false),
      (icon: '⛨', label: '${p['help']}', meta: '24/7', onTap: () => context.push('/me/help'), danger: false),
      (icon: '¶', label: '${p['terms']}', meta: '', onTap: () => openLegal(context, 'terms'), danger: false),
      (icon: '◌', label: '${p['privacy']}', meta: '', onTap: () => openLegal(context, 'privacy'), danger: false),
      (icon: '↺', label: '${p['cancellation']}', meta: '', onTap: () => openLegal(context, 'cancellation'), danger: false),
      (icon: '◎', label: '${(Copy.of(lang)['tour'] as Map)['replay']}', meta: '', onTap: () async {
        await replayClientTour();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'ar' ? 'هتتشاف الجولة على الرئيسية.' : 'Tour will show on Home.')));
        }
      }, danger: false),
      (icon: '✕', label: '${p['delete']}', meta: '', onTap: () => _confirmDelete(context, ref, p), danger: true),
    ];
    return Scaffold(
      backgroundColor: Client.bg,
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/me/identity'),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
                    clipBehavior: Clip.hardEdge,
                    child: user?.hasPhoto == true
                        ? MediaThumb(user!.photo!)
                        : Text(ini, style: const TextStyle(fontFamily: T.mono, fontSize: 15, fontWeight: FontWeight.w600, color: Client.ink)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name(lang) ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Ltr(child: Text('+20 ${user?.phone ?? ''}', style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Client.muted2))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: Client.olive, width: Client.rule)),
                            child: Text(
                              lang == 'ar' ? 'متأكد ✓' : 'Verified ✓',
                              style: const TextStyle(fontFamily: T.mono, fontSize: 9, fontWeight: FontWeight.w500, color: Client.oliveInk),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (pct < 100)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          lang == 'ar' ? 'ملفك كامل $pct٪' : 'Profile $pct% complete',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.ink),
                        ),
                        const Spacer(),
                        Text(
                          lang == 'ar' ? 'خطوات فاضلة' : 'Steps left',
                          style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Client.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FractionallySizedBox(
                          widthFactor: pct / 100,
                          child: Container(color: Client.plum),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _promptBody(user, p, lang),
                      style: const TextStyle(fontSize: 12.5, height: 1.6, color: Client.body),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Client.plum,
                      child: InkWell(
                        onTap: _promptAction(user, context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text(_promptCta(user, p, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.bg)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...menu.map(
            (m) => ClientMenuRow(icon: m.icon, label: m.label, meta: m.meta, onTap: m.onTap, danger: m.danger),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                ClientGhostButton(
                  label: lang == 'ar' ? '${p['langCtaEn']}' : '${p['langCtaAr']}',
                  onTap: () => ref.read(localeProvider.notifier).toggle(),
                ),
                const SizedBox(height: 10),
                ClientGhostButton(
                  label: '${p['signOut']}',
                  onTap: () => ref.read(sessionProvider.notifier).signOut(),
                ),
                const SizedBox(height: 14),
                Text(
                  lang == 'ar' ? 'النسخة ٢.٠ · أُنس مصر' : 'Version 2.0 · Oons Egypt',
                  style: const TextStyle(fontSize: 11.5, color: Client.muted2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Map p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Client.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('${p['delete']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${p['deleteBody']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('${p['keep']}')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('${p['delete']}', style: const TextStyle(color: T.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final lang = langOf(ref);
      try {
        await ref.read(sessionProvider.notifier).deleteAccount();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      }
    }
  }
}

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final user = ref.watch(sessionProvider).user;
    final addrs = user?.addresses ?? [];
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p['addresses']}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                children: [
                  ...addrs.map((a) {
                  return InkWell(
                    onTap: () => context.push('/me/addresses/edit', extra: a),
                    onLongPress: () async {
                      try {
                        await ref.read(sessionProvider.notifier).patchMe(defaultAddressId: a.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                          lang == 'ar' ? 'بقى العنوان الأساسي.' : 'Set as default.',
                        )));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                      }
                    },
                    child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
                    child: Row(
                      children: [
                        Glyph(a.isDefault ? GlyphKind.home : GlyphKind.pin, color: Client.plum),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label.of(lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(a.line1.of(lang), style: const TextStyle(fontSize: 13, height: 1.4)),
                              Text(a.city.of(lang), style: const TextStyle(fontSize: 12, color: Client.muted)),
                              if (a.reachNotes.of(lang).trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(a.reachNotes.of(lang), style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                                ),
                              if (a.lat != 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: InkWell(
                                    onTap: () => openExternal(googleMapsUrl(a.lat, a.lng)),
                                    child: Text('${p['openGmaps']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.plum)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (a.isDefault) ClientKicker(lang == 'ar' ? 'أساسي' : 'Default', color: Client.olive),
                        if (addrs.length > 1)
                          IconButton(
                            onPressed: () async {
                              try {
                                final u = await ref.read(repoProvider).deleteAddress(a.id);
                                ref.read(sessionProvider.notifier).setUser(u);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: T.danger),
                          ),
                      ],
                    ),
                  ),
                  );
                }),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClientPrimaryButton(label: '${p['addAddress']}', onTap: () => context.push('/me/addresses/new')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final ids = ref.watch(sessionProvider).user?.savedIds ?? const ['65a000000000000000000001', '65a000000000000000000003'];
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p['saved']}', onBack: () => context.pop()),
            Expanded(
              child: FutureBuilder<List<ProviderP>>(
                future: Future.wait(ids.map((id) => ref.read(repoProvider).provider(id))),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  return ListView(
                    children: list.map((pro) {
                      return InkWell(
                        onTap: () => context.push('/provider/${pro.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
                          child: Row(
                            children: [
                              Face(id: pro.id, ini: pro.initials.of(lang), size: 48, photo: pro.photo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pro.name(lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                    Text(pro.specialty.of(lang), style: const TextStyle(fontSize: 12, color: Client.muted)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward, size: 16, color: Client.muted, textDirection: Directionality.of(context)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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

class ProfileCopyScreen extends ConsumerWidget {
  const ProfileCopyScreen({super.key, required this.titleKey, required this.bodyKey});
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p[titleKey]}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Glyph(GlyphKind.shield, size: 28, color: Client.plum),
                  const SizedBox(height: 16),
                  Text('${p[bodyKey]}', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
