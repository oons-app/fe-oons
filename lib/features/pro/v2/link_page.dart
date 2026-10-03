import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/pro_nav.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

/// رابط الحجز — open/closed, the invite link she shares, and an optional own
/// domain. Reached from حسابي or from the pill on خدماتي; back returns there.
class ProLinkScreen extends ConsumerStatefulWidget {
  const ProLinkScreen({super.key, this.originTab});

  /// Which tab it was opened from (for the breadcrumb). Defaults to the current one.
  final int? originTab;

  @override
  ConsumerState<ProLinkScreen> createState() => _ProLinkScreenState();
}

class _ProLinkScreenState extends ConsumerState<ProLinkScreen> {
  late final int origin = widget.originTab ?? ProNav.tab.value;
  bool? openOverride;
  final domain = TextEditingController();
  bool busyDomain = false;
  String? dnsHint;

  @override
  void dispose() {
    domain.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(origin == ProNav.services ? '/pro/services' : '/pro/account');

  Future<void> _setOpen(bool v) {
    final before = openOverride;
    return ProAutosave(context, ref).patchMe(
      'link',
      () => {'linkOpen': v},
      apply: () => setState(() => openOverride = v),
      rollback: () {
        if (mounted) setState(() => openOverride = before);
      },
    ).then((ok) {
      if (ok && mounted) setState(() => openOverride = null);
    });
  }

  Future<void> _addDomain() async {
    final t = pv2(ref);
    final lang = langOf(ref);
    final host = domain.text.trim().toLowerCase();
    if (host.isEmpty) return;
    setState(() => busyDomain = true);
    try {
      final r = await ref.read(repoProvider).addProDomain(host);
      domain.clear();
      dnsHint = r['dnsHint']?.toString();
      if (r['provider'] is Map) ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      if (mounted) DsToast.show(context, t('domainAdded'));
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    } finally {
      if (mounted) setState(() => busyDomain = false);
    }
  }

  Future<void> _domainAction(Future<Map<String, dynamic>> Function() run, String okMsg) async {
    final lang = langOf(ref);
    setState(() => busyDomain = true);
    try {
      final r = await run();
      if (r['provider'] is Map) ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      if (mounted) DsToast.show(context, okMsg);
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    } finally {
      if (mounted) setState(() => busyDomain = false);
    }
  }

  Future<void> _renameSlug() async {
    final t = pv2(ref);
    final lang = langOf(ref);
    final me = ref.read(sessionProvider).provider;
    final ctrl = TextEditingController(text: me?.slug ?? '');
    final p = Copy.of(lang)['pro'] as Map;
    final save = await showDsSheet<bool>(
      context,
      title: t('renameLink'),
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsField(label: '${p['slugPlaceholder']}', controller: ctrl, mono: true, ltr: true),
        const SizedBox(height: Ds.s4),
        DsButton(label: t('save'), onTap: () => Navigator.pop(ctx, true)),
      ]),
    );
    final slug = ctrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '');
    ctrl.dispose();
    if (save != true || slug.isEmpty || !mounted) return;
    try {
      final r = await ref.read(repoProvider).patchPro({'slug': slug});
      if (r['provider'] is Map) ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      if (mounted) DsToast.show(context, t('saved'));
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final me = ref.watch(sessionProvider).provider;
    final open = openOverride ?? me?.linkOpen ?? true;
    final slug = (me?.slug ?? '').trim();
    final url = slug.isEmpty ? '' : providerInviteUrl(slug, customDomain: me?.liveCustomDomain, broughtToken: me?.broughtClientToken);
    final m = Copy.of(lang)['svcMgmt'] as Map;
    final crumb = origin == ProNav.services ? t('rowServicesCrumb') : t('tabAccount');

    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            DsBackHeader(crumb: crumb, onBack: _back),
            const SizedBox(height: Ds.s3),
            Text(t('rowLink'), style: DsText.subTitle),
            const SizedBox(height: Ds.s4),
            DsCard.rows(children: [
              DsListRow(
                label: open ? t('linkTitleOpen') : t('linkTitleClosed'),
                subtitle: open ? t('linkSubOpen') : t('linkSubClosed'),
                background: open ? null : Ds.terracottaBg,
                showChevron: false,
                trailing: DsSwitch(on: open, label: open ? t('linkTitleOpen') : t('linkTitleClosed'), onChanged: me == null ? null : _setOpen),
              ),
            ]),
            const SizedBox(height: Ds.s6),
            DsSectionHeader(t('invite')),
            const SizedBox(height: Ds.s2),
            if (url.isEmpty)
              DsCard(padding: EdgeInsets.zero, child: DsEmptyState(icon: 'message', title: t('noLinkYet'), body: t('noLinkYetWhy'), padding: const EdgeInsets.all(Ds.s5)))
            else
              DsCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(t('inviteBody'), style: DsText.body),
                  const SizedBox(height: Ds.s3),
                  Container(
                    padding: const EdgeInsets.all(Ds.s3),
                    decoration: BoxDecoration(color: Ds.surface, border: Border.all(color: Ds.divider, width: Ds.rule)),
                    child: SelectableText(url, textDirection: TextDirection.ltr, style: DsText.num(size: 12.5, weight: FontWeight.w500)),
                  ),
                  const SizedBox(height: Ds.s3),
                  Row(children: [
                    Expanded(
                      child: DsButton(
                        label: t('copyLink'),
                        kind: DsButtonKind.secondary,
                        compact: true,
                        icon: '',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: url));
                          unawaited(AppAnalytics.shareProviderLink(slug: slug, method: 'copy_invite'));
                          DsToast.show(context, t('linkCopied'));
                        },
                      ),
                    ),
                    const SizedBox(width: Ds.s2),
                    Expanded(
                      child: DsButton(
                        label: t('whatsapp'),
                        kind: DsButtonKind.secondary,
                        compact: true,
                        icon: '',
                        onTap: () {
                          final body = '${m['inviteWhatsAppBody'] ?? ''}\n$url';
                          unawaited(AppAnalytics.shareProviderLink(slug: slug, method: 'whatsapp_invite'));
                          unawaited(openExternal('https://wa.me/?text=${Uri.encodeComponent(body)}'));
                        },
                      ),
                    ),
                  ]),
                  Align(alignment: AlignmentDirectional.centerStart, child: DsTextLink(t('renameLink'), small: true, onTap: _renameSlug)),
                ]),
              ),
            const SizedBox(height: Ds.s6),
            Row(children: [
              Text(t('customDomain'), style: DsText.section),
              const SizedBox(width: Ds.s2),
              Text('· ${t('optional')}', style: DsText.meta),
            ]),
            const SizedBox(height: Ds.s2),
            DsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t('domainBody'), style: DsText.body),
                const SizedBox(height: Ds.s3),
                for (final d in me?.customDomains ?? const <ProviderDomain>[]) ...[
                  Container(
                    padding: const EdgeInsets.all(Ds.s3),
                    decoration: BoxDecoration(color: Ds.surface, border: Border.all(color: Ds.divider, width: Ds.rule)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(d.host, style: DsText.num(size: 13), textDirection: TextDirection.ltr)),
                        DsStatusBadge(
                          d.status == 'verified' ? (d.tlsStatus == 'active' ? t('domainLive') : t('domainTls')) : t('domainPending'),
                          tone: d.tlsStatus == 'active' ? DsTone.olive : DsTone.attention,
                        ),
                      ]),
                      if (d.status == 'pending' && d.verifyToken.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('TXT: oons-domain-verification=${d.verifyToken}', style: DsText.num(size: 11, color: Ds.textMuted), textDirection: TextDirection.ltr)),
                      Row(children: [
                        if (d.status != 'verified') DsTextLink(t('domainVerify'), small: true, onTap: busyDomain ? null : () => _domainAction(() => ref.read(repoProvider).verifyProDomain(d.host), t('saved'))),
                        const Spacer(),
                        DsTextLink(t('domainRemove'), small: true, danger: true, onTap: busyDomain ? null : () => _domainAction(() => ref.read(repoProvider).deleteProDomain(d.host), t('domainRemoved'))),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: Ds.s2),
                ],
                if ((me?.customDomains.length ?? 0) < 3) ...[
                  DsField(label: t('domainField'), controller: domain, hint: t('domainHint'), mono: true, ltr: true),
                  const SizedBox(height: Ds.s3),
                  DsButton(label: t('addDomain'), kind: DsButtonKind.secondary, compact: true, busy: busyDomain, icon: '', onTap: _addDomain),
                  if ((dnsHint ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: Ds.s2), child: Text(dnsHint!, style: DsText.hint)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
