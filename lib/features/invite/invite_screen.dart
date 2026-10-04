import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/invite/invite_model.dart';
import 'package:oons/l10n/errors.dart';
import 'package:oons/l10n/invite_copy.dart';

final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo>((ref) async {
  final raw = await ref.read(repoProvider).referralInfo();
  return ReferralInfo.fromJson(raw);
});

/// The link a friend opens: the customer app with her code, kept until sign-up.
String inviteUrl(String code) {
  final base = publicWebBase();
  return '${base.isEmpty ? 'https://lady.oons.app' : base}/?ref=$code';
}

String _fill(String s, Map<String, String> v) => v.entries.fold(s, (a, e) => a.replaceAll('{${e.key}}', e.value));

/// «ادعي صديقة»: share a code, see how it is going, collect the 50% coupon.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});
  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  late final TextEditingController entered = TextEditingController(text: (Hive.box('prefs').get('inviteRef') as String?) ?? '');
  bool applying = false;

  @override
  void dispose() {
    entered.dispose();
    super.dispose();
  }

  Future<void> _apply(String lang, Map<String, String> t) async {
    final code = entered.text.trim();
    if (code.isEmpty || applying) return;
    setState(() => applying = true);
    try {
      await ref.read(repoProvider).redeemReferral(code);
      await Hive.box('prefs').delete('inviteRef');
      if (!mounted) return;
      DsToast.show(context, t['applied']!);
      ref.invalidate(referralInfoProvider);
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final t = InviteCopy.of(lang);
    final info = ref.watch(referralInfoProvider);

    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            DsBackHeader(crumb: t['title']!, onBack: () => context.canPop() ? context.pop() : context.go('/profile')),
            const SizedBox(height: Ds.s4),
            ...info.when(
              loading: () => [const DsSkeletonRows(rows: 3)],
              error: (e, _) => [
                DsCard(
                  padding: EdgeInsets.zero,
                  child: DsEmptyState(
                    icon: 'offline',
                    title: t['loadFail']!,
                    body: friendlyError(e, lang),
                    cta: t['retry']!,
                    onCta: () => ref.invalidate(referralInfoProvider),
                  ),
                ),
              ],
              data: (r) => _content(r, t, lang, ar),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(ReferralInfo r, Map<String, String> t, String lang, bool ar) {
    final p = {'p': DsFormat.digits(r.percent, ar: ar)};
    final link = inviteUrl(r.code);
    final capEgp = r.maxDiscount ~/ 100;
    final terms = _fill(t['terms']!, {
      'days': DsFormat.digits(r.validDays, ar: ar),
      'cap': r.maxDiscount > 0 ? _fill(t['cap']!, {'max': DsFormat.amount(capEgp, ar: ar)}) : '',
    });

    final who = r.providerNames(lang);
    return [
      Text(_fill(t['heroTitle']!, p), style: DsText.subTitle.copyWith(fontSize: 24)),
      const SizedBox(height: Ds.s2),
      Text(_fill(t['heroBody']!, p), style: DsText.body),
      const SizedBox(height: Ds.s5),
      if (!r.enabled)
        DsCard(child: Text(t['paused']!, style: DsText.body))
      else ...[
        DsCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['yourCode']!, style: DsText.meta),
            const SizedBox(height: Ds.s2),
            Semantics(
              label: '${t['yourCode']} ${r.code}',
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(r.code, key: const Key('invite-code'), style: DsText.num(size: 30, weight: FontWeight.w600).copyWith(letterSpacing: 4)),
              ),
            ),
            const SizedBox(height: Ds.s3),
            Row(children: [
              Expanded(
                child: DsButton(
                  label: t['copy']!,
                  kind: DsButtonKind.secondary,
                  compact: true,
                  icon: '',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.code));
                    DsToast.show(context, t['copied']!);
                  },
                ),
              ),
              const SizedBox(width: Ds.s2),
              Expanded(
                child: DsButton(
                  label: t['whatsapp']!,
                  compact: true,
                  icon: '',
                  onTap: () {
                    final text = _fill(t['shareText']!, {'code': r.code, 'link': link});
                    unawaited(openExternal('https://wa.me/?text=${Uri.encodeComponent(text)}'));
                  },
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: Ds.s5),
        DsStatStrip(items: [
          DsStat(label: t['statInvited']!, value: DsFormat.digits(r.invited, ar: ar)),
          DsStat(label: t['statDone']!, value: DsFormat.digits(r.completed, ar: ar), accent: true),
        ]),
        const SizedBox(height: Ds.s5),
        DsSectionHeader(t['how']!),
        const SizedBox(height: Ds.s2),
        DsCard.rows(children: [
          for (final (i, k) in ['step1', 'step2', 'step3'].indexed)
            Padding(
              padding: const EdgeInsets.all(Ds.s3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DsFormat.digits(i + 1, ar: ar), style: DsText.num(size: 14, weight: FontWeight.w600)),
                const SizedBox(width: Ds.s3),
                Expanded(child: Text(_fill(t[k]!, p), style: DsText.body)),
              ]),
            ),
        ]),
      ],
      const SizedBox(height: Ds.s5),
      DsSectionHeader(t['rewards']!),
      const SizedBox(height: Ds.s2),
      if (r.rewards.isEmpty)
        DsCard(child: Text(t['rewardsEmpty']!, style: DsText.meta))
      else ...[
        for (final w in r.rewards) ...[
          _RewardCard(reward: w, t: t, ar: ar),
          const SizedBox(height: Ds.s2),
        ],
        Text(t['useAtCheckout']!, style: DsText.hint),
      ],
      if (r.canApplyCode) ...[
        const SizedBox(height: Ds.s6),
        DsSectionHeader(t['haveCode']!),
        const SizedBox(height: Ds.s1),
        Text(t['haveCodeBody']!, style: DsText.meta),
        const SizedBox(height: Ds.s3),
        DsField(label: t['codeField']!, controller: entered, mono: true, ltr: true, hint: 'ABC123'),
        const SizedBox(height: Ds.s3),
        DsButton(label: t['apply']!, busy: applying, onTap: () => _apply(lang, t)),
      ] else if (r.usedCode) ...[
        const SizedBox(height: Ds.s5),
        Text(t['usedCode']!, style: DsText.meta),
      ],
      const SizedBox(height: Ds.s5),
      Text(who.isEmpty ? terms : '$terms ${_fill(t['withProviders']!, {'names': who})}', key: const Key('invite-terms'), style: DsText.hint),
    ];
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.t, required this.ar});
  final ReferralReward reward;
  final Map<String, String> t;
  final bool ar;

  @override
  Widget build(BuildContext context) {
    final tone = reward.available ? DsTone.olive : DsTone.neutral;
    final date = reward.expiresAt;
    return Semantics(
      button: reward.available,
      label: '${reward.code} ${_fill(t['off']!, {'p': '${reward.percent}'})} ${t[reward.status]}',
      child: InkWell(
        onTap: reward.available
            ? () {
                Clipboard.setData(ClipboardData(text: reward.code));
                DsToast.show(context, t['copied']!);
              }
            : null,
        child: Opacity(
          opacity: reward.available ? 1 : 0.6,
          child: DsCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(reward.code, style: DsText.num(size: 18, weight: FontWeight.w600).copyWith(letterSpacing: 2)),
                  ),
                  const SizedBox(height: 2),
                  Text(_fill(t['off']!, {'p': DsFormat.digits(reward.percent, ar: ar)}), style: DsText.body),
                  if (date != null && reward.available)
                    Text(
                      _fill(t['expires']!, {'date': DsFormat.digits('${date.day}/${date.month}/${date.year}', ar: ar)}),
                      style: DsText.hint,
                    ),
                ]),
              ),
              DsStatusBadge(t[reward.status] ?? reward.status, tone: tone),
            ]),
          ),
        ),
      ),
    );
  }
}
