import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/features/pro/v2/services_actions.dart';
import 'package:oons/features/pro/v2/services_model.dart';
import 'package:oons/features/pro/v2/t.dart';

String helpersLabel(int n, String Function(String, [Map<String, Object>]) t, bool ar) =>
    n == 1 ? t('helperOne') : n == 2 ? t('helperTwo') : t('helperMany', {'n': DsFormat.digits(n, ar: ar)});

/// Per-tier prices by flat area (cleaning). Each tier: from / to / price, and a
/// helpers chip that cycles 1 → 2 → 3.
Future<void> showTiersSheet(BuildContext context, WidgetRef ref, ProSpecialty spec) {
  return showDsSheet<void>(
    context,
    title: pv2(ref)('tiersTitle'),
    builder: (ctx) => _TiersBody(spec: spec, hostContext: context, hostRef: ref),
  );
}

class _TiersBody extends ConsumerStatefulWidget {
  const _TiersBody({required this.spec, required this.hostContext, required this.hostRef});
  final ProSpecialty spec;
  final BuildContext hostContext;
  final WidgetRef hostRef;
  @override
  ConsumerState<_TiersBody> createState() => _TiersBodyState();
}

class _Row {
  _Row(this.edit)
      : from = TextEditingController(text: '${edit.from}'),
        to = TextEditingController(text: '${edit.to}'),
        price = TextEditingController(text: '${edit.priceEgp}');
  final TierEdit edit;
  final TextEditingController from, to, price;
  void sync() {
    edit.from = int.tryParse(toWesternDigits(from.text.trim())) ?? 0;
    edit.to = int.tryParse(toWesternDigits(to.text.trim())) ?? 0;
    edit.priceEgp = int.tryParse(toWesternDigits(price.text.trim())) ?? 0;
  }

  void dispose() {
    from.dispose();
    to.dispose();
    price.dispose();
  }
}

class _TiersBodyState extends ConsumerState<_TiersBody> {
  late final rows = [for (final i in widget.spec.tiers) _Row(TierEdit.fromItem(i))];
  bool busy = false;

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  bool get _valid {
    for (final r in rows) {
      r.sync();
      if (r.edit.from <= 0 || r.edit.to < r.edit.from || r.edit.priceEgp <= 0) return false;
    }
    return rows.isNotEmpty;
  }

  void _add() {
    final last = rows.isEmpty ? null : rows.last.edit;
    setState(() => rows.add(_Row(TierEdit(from: (last?.to ?? 100) + 1, to: (last?.to ?? 100) + 50, helpers: 1, priceEgp: last?.priceEgp ?? 800))));
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => busy = true);
    final ok = await saveTiers(widget.hostContext, widget.hostRef, widget.spec, [for (final r in rows) r.edit]);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = pv2(ref);
    final ar = langOf(ref) == 'ar';
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: DsField(label: t('tierFrom'), controller: rows[i].from, mono: true, keyboardType: TextInputType.number, inputFormatters: digits, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: Ds.s2),
                  Expanded(child: DsField(label: t('tierTo'), controller: rows[i].to, mono: true, keyboardType: TextInputType.number, inputFormatters: digits, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: Ds.s2),
                  Expanded(child: DsField(label: t('tierPrice'), controller: rows[i].price, mono: true, keyboardType: TextInputType.number, inputFormatters: digits, onChanged: (_) => setState(() {}))),
                ]),
                const SizedBox(height: Ds.s3),
                Row(children: [
                  Flexible(child: DsChip(label: helpersLabel(rows[i].edit.helpers, t, ar), on: false, onTap: () => setState(() => rows[i].edit.helpers = rows[i].edit.helpers % 3 + 1))),
                  const Spacer(),
                  Flexible(child: DsTextLink(t('tierRemove'), danger: true, small: true, onTap: () => setState(() => rows.removeAt(i).dispose()))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: Ds.s2),
        ],
        DsButton(label: t('tierAdd'), kind: DsButtonKind.secondary, icon: 'plus', compact: true, onTap: _add),
        const SizedBox(height: Ds.s3),
        DsButton(label: t('tierSave'), busy: busy, onTap: _valid ? _save : null),
      ],
    );
  }
}

/// ±10% on this specialty's services only.
Future<void> showBulkSheet(BuildContext context, WidgetRef ref, ProSpecialty spec) {
  final t = pv2(ref);
  final lang = langOf(ref);
  final ar = lang == 'ar';
  return showDsSheet<void>(
    context,
    title: t('bulkTitle'),
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('bulkBody', {'name': spec.name.of(lang)}), style: DsText.body),
        const SizedBox(height: Ds.s4),
        Row(children: [
          for (final f in const [0.9, 1.1]) ...[
            if (f == 1.1) const SizedBox(width: Ds.s2),
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  bulkChangePrices(context, ref, spec, f);
                },
                child: Container(
                  height: Ds.buttonHeight,
                  alignment: Alignment.center,
                  decoration: Ds.card(),
                  child: Text('${f < 1 ? '−' : '+'}${DsFormat.percent(10, ar: ar)}', style: DsText.num(size: 16, weight: FontWeight.w600), textDirection: TextDirection.ltr),
                ),
              ),
            ),
          ],
        ]),
      ],
    ),
  );
}
