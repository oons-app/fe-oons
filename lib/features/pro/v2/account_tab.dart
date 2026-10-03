import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/pro_tour.dart';
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/services_actions.dart' show confirmSheet;
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/features/pro/v2/uploads.dart';
import 'package:oons/features/subscribe/prov_api.dart';
import 'package:oons/l10n/errors.dart';

/// Is her file complete enough to be reviewed: ID photo, criminal record
/// certificate and a payout number on file.
bool profileComplete(ProviderP? me) =>
    me != null &&
    (me.idPhotoUrl ?? '').isNotEmpty &&
    (me.fishPhotoUrl ?? '').isNotEmpty &&
    (me.payoutHandle ?? '').trim().isNotEmpty &&
    (me.nationalId ?? '').length == 14;

String yearsLabel(int n, {required bool ar}) {
  if (!ar) return n == 1 ? '1 year experience' : '$n years experience';
  if (n == 1) return 'سنة خبرة';
  if (n == 2) return 'سنتين خبرة';
  if (n >= 3 && n <= 10) return '${DsFormat.digits(n, ar: true)} سنين خبرة';
  return '${DsFormat.digits(n, ar: true)} سنة خبرة';
}

String ratingLabel(double r, {required bool ar}) {
  final s = r.toStringAsFixed(1);
  return ar ? DsFormat.digits(s.replaceAll('.', '٫'), ar: true) : s;
}

/// حسابي — who she is, whether she is bookable, and everything else one tap away
/// in three short groups.
class ProAccountTab extends ConsumerStatefulWidget {
  const ProAccountTab({super.key, this.plansApi});

  /// Test seam: how the plans count is read.
  final ProApi? plansApi;

  @override
  ConsumerState<ProAccountTab> createState() => _ProAccountTabState();
}

class _ProAccountTabState extends ConsumerState<ProAccountTab> {
  int? planCount;
  String? docIssue;
  bool? availableOverride;

  @override
  void initState() {
    super.initState();
    final prefs = Hive.box('prefs');
    final pending = prefs.get('pendingDocIssue') as String?;
    if (pending != null && pending.isNotEmpty) {
      docIssue = pending;
      prefs.delete('pendingDocIssue');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
      _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    final s = ref.read(sessionProvider);
    if (!s.subscriptionsPilot || !(s.provider?.offersCleaning ?? false)) return;
    try {
      final r = await (widget.plansApi ?? const LiveProApi()).get('/pro/plans');
      final rows = ((r['plans'] as List?) ?? const []).whereType<Map>().where((p) => '${p['status']}' != 'archived').toList();
      if (mounted) setState(() => planCount = rows.length);
    } catch (_) {}
  }

  Future<void> _setAvailable(bool v) {
    final before = availableOverride;
    return ProAutosave(context, ref).patchMe(
      'available',
      () => {'available': v},
      apply: () => setState(() => availableOverride = v),
      rollback: () {
        if (mounted) setState(() => availableOverride = before);
      },
    ).then((ok) {
      if (ok && mounted) setState(() => availableOverride = null);
    });
  }

  Future<void> _deleteAccount() async {
    final t = pv2(ref);
    final lang = langOf(ref);
    final yes = await confirmSheet(context, ref, title: t('deleteAccountTitle'), body: t('deleteAccountBody'), yes: t('deleteAccount'));
    if (!yes || !mounted) return;
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final s = ref.watch(sessionProvider);
    final me = s.provider;
    final available = availableOverride ?? me?.available ?? true;
    final linkOpen = me?.linkOpen ?? true;
    final showPlans = s.subscriptionsPilot && (me?.offersCleaning ?? false);

    Widget group(String title, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.only(top: Ds.s5, bottom: Ds.s2), child: DsSectionHeader(title)),
            DsCard.rows(children: rows),
          ],
        );

    return ColoredBox(
      color: Ds.cream,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            Text(t('tabAccount'), style: DsText.screenTitle),
            if (docIssue != null) ...[
              const SizedBox(height: Ds.s3),
              Container(
                padding: const EdgeInsets.all(Ds.s3),
                decoration: BoxDecoration(color: Ds.terracottaBg, border: Border.all(color: Ds.terracotta, width: Ds.rule)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const OnsIcon('alert', size: 18, color: Ds.terracottaText),
                  const SizedBox(width: Ds.s2),
                  Expanded(
                    child: Text(
                      ar ? 'اتسجل حسابك، بس في ورقة ما اترفعتش:\n$docIssue\nارفعيها تاني من «بياناتي وأوراقي».' : 'Your account is set up, but a document did not upload:\n$docIssue\nUpload it again from "My details and papers".',
                      style: DsText.body.copyWith(color: Ds.terracottaText),
                    ),
                  ),
                  InkWell(onTap: () => setState(() => docIssue = null), child: SizedBox(width: 32, height: 32, child: Center(child: OnsIconOnly('close', semanticLabel: ar ? 'إغلاق' : 'Close', size: 16, color: Ds.terracottaText)))),
                ]),
              ),
            ],
            const SizedBox(height: Ds.s4),
            // Profile + availability
            DsCard.rows(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  InkWell(
                    onTap: () => proUpload(context, ref, ProUpload.face),
                    child: Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Ds.plumLight, border: Border.all(color: Ds.ink, width: Ds.rule)),
                      child: Text(_initial(me, lang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Ds.plum)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me?.name(lang) ?? '', style: DsText.itemName.copyWith(fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(child: Text('${me == null ? '' : yearsLabel(me.years, ar: ar)} · ', style: DsText.meta)),
                        const OnsIcon('star', size: 13, color: Ds.textMuted),
                        const SizedBox(width: 3),
                        Text(ratingLabel(me?.rating ?? 0, ar: ar), style: DsText.num(size: 12.5, color: Ds.textMuted)),
                      ]),
                    ]),
                  ),
                  DsStatusBadge(me?.vetted == true ? t('verified') : t('pendingVerify'), tone: me?.vetted == true ? DsTone.olive : DsTone.attention),
                ]),
              ),
              DsListRow(
                label: available ? t('availableTitleOn') : t('availableTitleOff'),
                subtitle: available ? t('availableSubOn') : t('availableSubOff'),
                background: available ? null : Ds.terracottaBg,
                showChevron: false,
                trailing: DsSwitch(on: available, label: available ? t('availableTitleOn') : t('availableTitleOff'), onChanged: me == null ? null : _setAvailable),
              ),
            ]),
            group(t('grpWork'), [
              if (showPlans) DsListRow(label: t('rowPlans'), icon: 'card', value: planCount == null ? null : DsFormat.plans(planCount!, ar: ar), onTap: () => context.push('/pro/plans')),
              DsListRow(label: t('rowLink'), icon: 'message', value: linkOpen ? t('linkOpen') : t('linkClosed'), valueColor: linkOpen ? Ds.oliveText : Ds.terracottaText, onTap: () => context.push('/pro/link')),
              DsListRow(label: t('rowTeam'), icon: 'user', onTap: () => context.push('/pro/team')),
              DsListRow(label: t('rowCoupons'), icon: 'star', onTap: () => context.push('/pro/coupons')),
            ]),
            group(t('grpFile'), [
              DsListRow(label: t('rowDetails'), icon: 'shieldCheck', value: profileComplete(me) ? t('complete') : t('incomplete'), valueColor: profileComplete(me) ? Ds.oliveText : Ds.terracottaText, onTap: () => context.push('/pro/profile')),
            ]),
            group(t('grpSettings'), [
              DsListRow(label: t('rowNotif'), icon: 'bell', onTap: () => context.push('/me/notif')),
              DsListRow(label: t('rowLang'), icon: 'home', value: t('langValue'), onTap: () => ref.read(localeProvider.notifier).toggle()),
              DsListRow(
                label: t('rowTour'),
                icon: 'retry',
                onTap: () async {
                  await resetProTour();
                  if (context.mounted) await showProTour(context, lang: lang);
                },
              ),
              DsListRow(label: t('rowLegal'), icon: 'info', onTap: () => context.push('/pro/legal')),
            ]),
            const SizedBox(height: Ds.s6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              DsTextLink(t('signOut'), onTap: () => ref.read(sessionProvider.notifier).signOut()),
              DsTextLink(t('deleteAccount'), danger: true, onTap: _deleteAccount),
            ]),
          ],
        ),
      ),
    );
  }

  String _initial(ProviderP? me, String lang) {
    final n = me?.firstName.of(lang) ?? '';
    return n.isEmpty ? '·' : String.fromCharCodes(n.runes.take(1));
  }
}
