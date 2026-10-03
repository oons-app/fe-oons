import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart' show toWesternDigits;
import 'package:oons/core/widgets.dart' show MediaThumb, openGallery;
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/autosave.dart';
import 'package:oons/features/pro/v2/t.dart';
import 'package:oons/features/pro/v2/uploads.dart';
import 'package:oons/l10n/errors.dart';

/// Where one of her papers stands, from what staff decided.
enum DocState { confirmed, inReview, rejected, missing }

DocState docState({required bool hasFile, required String status, required bool vetted}) {
  if (!hasFile) return DocState.missing;
  if (status == 'accepted' || (status.isEmpty && vetted)) return DocState.confirmed;
  if (status == 'rejected') return DocState.rejected;
  return DocState.inReview;
}

/// بياناتي وأوراقي — her details, her papers with their review state, and the
/// photos of her work.
class ProDetailsScreen extends ConsumerStatefulWidget {
  const ProDetailsScreen({super.key});
  @override
  ConsumerState<ProDetailsScreen> createState() => _ProDetailsScreenState();
}

class _ProDetailsScreenState extends ConsumerState<ProDetailsScreen> {
  final years = TextEditingController();
  final payout = TextEditingController();
  final bio = TextEditingController();
  String? primedFor;
  bool saving = false;
  double? progress;

  @override
  void dispose() {
    years.dispose();
    payout.dispose();
    bio.dispose();
    super.dispose();
  }

  void _prime(ProviderP? me) {
    if (me == null || primedFor == me.id) return;
    primedFor = me.id;
    years.text = '${me.years}';
    payout.text = me.payoutHandle ?? '';
    bio.text = me.bio?.of('ar') ?? me.bio?.en ?? '';
  }

  void _back() => context.canPop() ? context.pop() : context.go('/pro/account');

  Future<void> _save(ProviderP me) async {
    final t = pv2(ref);
    final lang = langOf(ref);
    setState(() => saving = true);
    try {
      final r = await ref.read(repoProvider).patchPro({
        'years': int.tryParse(toWesternDigits(years.text.trim())) ?? me.years,
        'payoutHandle': toWesternDigits(payout.text.trim()),
        'bio': bio.text.trim(),
      });
      if (r['provider'] is Map) ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      if (mounted) DsToast.show(context, t('saved'));
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _editNid() async {
    final t = pv2(ref);
    final ctrl = TextEditingController(text: ref.read(sessionProvider).provider?.nationalId ?? '');
    final ok = await showDsSheet<bool>(
      context,
      title: t('docNid'),
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsField(
          label: t('nidLabel'),
          controller: ctrl,
          mono: true,
          ltr: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')), LengthLimitingTextInputFormatter(14)],
        ),
        const SizedBox(height: Ds.s4),
        DsButton(label: t('save'), onTap: () => Navigator.pop(ctx, true)),
      ]),
    );
    final raw = toWesternDigits(ctrl.text).replaceAll(RegExp(r'[^0-9]'), '');
    ctrl.dispose();
    if (ok != true || !mounted) return;
    if (raw.length != 14) {
      DsToast.show(context, t('nidInvalid'), error: true);
      return;
    }
    await ProAutosave(context, ref).patchMe('nid', () => {'nationalId': raw}, apply: () {}, rollback: () {});
  }

  Future<void> _upload(ProUpload kind) => proUpload(context, ref, kind, onProgress: (f) {
        if (mounted) setState(() => progress = f);
      });

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final lang = langOf(ref);
    final ar = lang == 'ar';
    final me = ref.watch(sessionProvider).provider;
    _prime(me);
    final vetted = me?.vetted == true;
    final nid = me?.nationalId ?? '';
    final nidMasked = nid.length >= 4 ? '${'•' * 4} ${DsFormat.digits(nid.substring(nid.length - 4), ar: ar)}' : t('docMissing');
    final id = docState(hasFile: (me?.idPhotoUrl ?? '').isNotEmpty, status: me?.idDocStatus ?? '', vetted: vetted);
    final fish = docState(hasFile: (me?.fishPhotoUrl ?? '').isNotEmpty, status: me?.fishDocStatus ?? '', vetted: vetted);
    final nidState = nid.length == 14 ? (vetted ? DocState.confirmed : DocState.inReview) : DocState.missing;
    final allConfirmed = [id, fish, nidState].every((s) => s == DocState.confirmed);
    final shots = me?.portfolio ?? const <String>[];

    Widget badge(DocState s) => switch (s) {
          DocState.confirmed => DsStatusBadge(t('docConfirmed'), tone: DsTone.olive),
          DocState.inReview => DsStatusBadge(t('docInReview'), tone: DsTone.neutral),
          DocState.rejected => DsStatusBadge(t('docRejected'), tone: DsTone.attention),
          DocState.missing => DsStatusBadge(t('docMissing'), tone: DsTone.attention),
        };

    return Scaffold(
      backgroundColor: Ds.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s8),
          children: [
            DsBackHeader(crumb: t('tabAccount'), onBack: _back),
            const SizedBox(height: Ds.s3),
            Text(t('detailsTitle'), style: DsText.subTitle),
            const SizedBox(height: Ds.s4),
            DsSectionHeader(t('details')),
            const SizedBox(height: Ds.s2),
            DsCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DsField(label: t('yearsField'), controller: years, mono: true, keyboardType: TextInputType.number),
                const SizedBox(height: Ds.s3),
                DsField(label: t('instapayField'), controller: payout, mono: true, ltr: true, keyboardType: TextInputType.phone),
                const SizedBox(height: Ds.s3),
                DsField(label: t('bio'), controller: bio, maxLines: 3),
                const SizedBox(height: Ds.s4),
                DsButton(label: t('save'), busy: saving, onTap: me == null ? null : () => _save(me)),
              ]),
            ),
            const SizedBox(height: Ds.s6),
            DsSectionHeader(t('docs'), meta: allConfirmed ? t('docsAllReviewed') : null),
            const SizedBox(height: Ds.s2),
            if (progress != null) ...[
              DsMeter(value: progress!, height: 8),
              const SizedBox(height: Ds.s2),
            ],
            DsCard.rows(children: [
              _DocRow(label: t('docNid'), sub: nidMasked, badge: badge(nidState), onTap: _editNid),
              _DocRow(label: t('docIdPhoto'), sub: _sub(id, t), badge: badge(id), thumb: me?.idPhotoUrl, onTap: () => _upload(ProUpload.id)),
              _DocRow(label: t('docFish'), sub: _sub(fish, t), badge: badge(fish), thumb: me?.fishPhotoUrl, onTap: () => _upload(ProUpload.fish)),
            ]),
            const SizedBox(height: Ds.s6),
            DsSectionHeader(t('portfolio')),
            const SizedBox(height: Ds.s2),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Ds.s2,
              crossAxisSpacing: Ds.s2,
              children: [
                for (var i = 0; i < shots.length; i++)
                  InkWell(
                    onTap: () => openGallery(context, shots, index: i),
                    onLongPress: () => _removePhoto(i),
                    child: Container(decoration: Ds.card(), clipBehavior: Clip.hardEdge, child: MediaThumb(shots[i])),
                  ),
                Semantics(
                  button: true,
                  label: t('addPhotos'),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => _upload(ProUpload.portfolio),
                    child: Container(
                      decoration: BoxDecoration(color: Ds.white, border: Border.all(color: Ds.ink, width: Ds.rule)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const OnsIcon('camera', size: 24, color: Ds.plum),
                        const SizedBox(height: 6),
                        Text(t('addPhotos'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Ds.plum)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            if (shots.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Ds.s2), child: Text(t('holdToRemove'), style: DsText.hint)),
          ],
        ),
      ),
    );
  }

  String _sub(DocState s, String Function(String, [Map<String, Object>]) t) => switch (s) {
        DocState.confirmed => t('docConfirmed'),
        DocState.inReview => t('docInReview'),
        DocState.rejected => t('docRejected'),
        DocState.missing => t('docMissing'),
      };

  Future<void> _removePhoto(int i) async {
    final t = pv2(ref);
    final lang = langOf(ref);
    try {
      final r = await ref.read(repoProvider).deleteProPortfolio(i);
      if (r['provider'] is Map) ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      if (mounted) DsToast.show(context, t('photoRemoved'));
    } catch (e) {
      if (mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    }
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.label, required this.sub, required this.badge, required this.onTap, this.thumb});
  final String label, sub;
  final Widget badge;
  final VoidCallback onTap;
  final String? thumb;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label · $sub',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Ds.s4, vertical: Ds.s3),
          child: Row(children: [
            if (thumb != null && thumb!.isNotEmpty) ...[
              Container(width: 44, height: 44, decoration: Ds.card(), clipBehavior: Clip.hardEdge, child: MediaThumb(thumb!)),
              const SizedBox(width: Ds.s3),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: DsText.itemName.copyWith(fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(sub, style: DsText.meta),
              ]),
            ),
            badge,
          ]),
        ),
      ),
    );
  }
}
