import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/ds.dart';

/// Provider-app chrome. Since design system v2 every widget here is a thin
/// adapter over `lib/ds` (square, ink-bordered, plum): the names stay so older
/// screens keep compiling, but there is exactly one look. New code should use
/// the `Ds*` components directly.
class Pro {
  static const bg = Ds.cream;
  static const card = Ds.white;
  static const ink = Ds.ink;
  static const muted = Ds.textMuted;
  static const soft = Ds.textBody;
  static const plum = Ds.plum;
  static const plumSoft = Ds.plumLight;
  static const plumPale = Ds.plumLight;
  static const sand = Ds.neutral;
  static const chip = Ds.surface;
  static const line = Ds.divider;
  static const lineSoft = Ds.divider;
  static const tip = Ds.plumLight;
  static const warnBg = Ds.terracottaBg;
  static const warnLine = Ds.terracotta;
  static const danger = Ds.terracottaText;
  static const dangerLine = Ds.terracotta;
  static const pendingBg = Ds.terracottaBg;
  static const pendingLine = Ds.terracotta;
  static const pendingInk = Ds.terracottaText;
  static const navMuted = Ds.textMuted;

  /// Everything is square.
  static const rCard = 0.0;
  static const rMd = 0.0;
  static const rSm = 0.0;
  static const rPill = 0.0;

  static BoxDecoration cardDec({Color? color, Color? border, double radius = 0}) => Ds.card(color: color, border: border);
}

class ProPageTitle extends StatelessWidget {
  const ProPageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ds.gutter, 6, Ds.gutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DsText.subTitle),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: DsText.meta)],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ProSectionLabel extends StatelessWidget {
  const ProSectionLabel(this.label, {super.key, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: DsText.section.copyWith(fontSize: 15)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class ProCard extends StatelessWidget {
  const ProCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DsCard(padding: padding, color: color, onTap: onTap, child: child);
}

class ProSegment extends StatelessWidget {
  const ProSegment({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DsSegmented(labels: labels, index: index, onChanged: onChanged);
}

class ProPill extends StatelessWidget {
  const ProPill(this.label, {super.key, this.hot = false, this.soft = false});
  final String label;
  final bool hot;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    if (!hot && !soft) return DsTag(label);
    return DsStatusBadge(label, tone: hot ? DsTone.olive : DsTone.neutral);
  }
}

class ProAvatar extends StatelessWidget {
  const ProAvatar(this.initial, {super.key, this.size = 38});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: Ds.surface,
      child: Text(_initialOf(initial), style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Ds.plum)),
    );
  }
}

class ProPrimaryButton extends StatelessWidget {
  const ProPrimaryButton({super.key, required this.label, required this.onTap, this.enabled = true});
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DsButton(label: label, onTap: enabled ? onTap : null);
}

class ProSoftButton extends StatelessWidget {
  const ProSoftButton({super.key, required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) =>
      DsButton(label: label, onTap: onTap, kind: danger ? DsButtonKind.danger : DsButtonKind.secondary, compact: true);
}

class ProChip extends StatelessWidget {
  const ProChip({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.pending = false,
    this.mono = false,
  });
  final String label;
  final bool on;
  final bool pending;
  final bool mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!pending) return DsChip(label: label, on: on, onTap: onTap, mono: mono);
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Ds.terracottaBg, border: Border.all(color: Ds.terracotta, width: Ds.rule)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Ds.minTarget),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Ds.s3),
              child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Ds.terracottaText, fontFamily: mono ? T.mono : null)),
            ),
          ),
        ),
      ),
    );
  }
}

class ProStatTile extends StatelessWidget {
  const ProStatTile({super.key, required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: Ds.card(color: accent ? Ds.plumLight : Ds.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsText.meta.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, maxLines: 1, style: DsText.num(size: 18, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class ProField extends StatelessWidget {
  const ProField({
    super.key,
    required this.controller,
    this.hint,
    this.mono = false,
    this.keyboard,
    this.onChanged,
  });
  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: Ds.card(),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.number ||
                keyboard == const TextInputType.numberWithOptions(signed: false, decimal: false)
            ? [_ProAsciiDigitFormatter()]
            : null,
        onChanged: onChanged,
        cursorColor: Ds.plum,
        style: TextStyle(fontFamily: mono ? T.mono : null, fontSize: 15, fontWeight: FontWeight.w600, color: Ds.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Ds.textFaint),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _ProAsciiDigitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue n) {
    final converted = n.text.replaceAllMapped(
      RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'),
      (m) {
        final c = m.group(0)!.codeUnitAt(0);
        return String.fromCharCode(c - (c >= 0x06F0 ? 0x06F0 : 0x0660) + 0x30);
      },
    );
    if (converted == n.text) return n;
    return n.copyWith(
      text: converted,
      selection: n.selection.copyWith(
        baseOffset: n.selection.baseOffset.clamp(0, converted.length),
        extentOffset: n.selection.extentOffset.clamp(0, converted.length),
      ),
    );
  }
}

String _initialOf(String s) {
  final t = s.trim();
  if (t.isEmpty) return '·';
  return String.fromCharCodes(t.runes.take(1));
}

class ProTip extends StatelessWidget {
  const ProTip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      color: Ds.ink,
      child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.6, color: Ds.cream)),
    );
  }
}

Widget _helpDot(bool open, double size) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border.all(color: Ds.ink, width: Ds.rule), color: open ? Ds.plumLight : Colors.transparent),
      child: Text('؟', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w700, color: open ? Ds.plum : Ds.textMuted, height: 1)),
    );

/// Inline «؟» that toggles a dark tip bubble.
class ProHelpMark extends StatefulWidget {
  const ProHelpMark(this.text, {super.key, this.size = 22});
  final String text;
  final double size;

  @override
  State<ProHelpMark> createState() => _ProHelpMarkState();
}

class _ProHelpMarkState extends State<ProHelpMark> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkWell(onTap: () => setState(() => open = !open), child: _helpDot(open, widget.size)),
        ),
        if (open) ...[const SizedBox(height: 8), ProTip(widget.text)],
      ],
    );
  }
}

/// Section title row with optional «؟» help that expands a dark tip below.
class ProSectionWithHelp extends StatefulWidget {
  const ProSectionWithHelp(this.label, {super.key, this.help, this.trailing});
  final String label;
  final String? help;
  final Widget? trailing;

  @override
  State<ProSectionWithHelp> createState() => _ProSectionWithHelpState();
}

class _ProSectionWithHelpState extends State<ProSectionWithHelp> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final help = widget.help?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: DsText.section.copyWith(fontSize: 15))),
            if (help.isNotEmpty) InkWell(onTap: () => setState(() => open = !open), child: _helpDot(open, 22)),
            if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
          ],
        ),
        if (open && help.isNotEmpty) ...[const SizedBox(height: 8), ProTip(help)],
      ],
    );
  }
}

class ProHintBanner extends StatelessWidget {
  const ProHintBanner(this.text, {super.key, this.dashed = false});
  final String text;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dashed ? Ds.surface : Ds.terracottaBg,
        border: Border.all(color: dashed ? Ds.divider : Ds.terracotta, width: Ds.rule),
      ),
      child: Text(text, style: DsText.body.copyWith(fontSize: 12.5, height: 1.7)),
    );
  }
}
