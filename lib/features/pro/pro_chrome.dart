import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/core/tokens.dart';

/// Soft, rounded chrome for the provider app — matches the Service Provider
/// App HTML design (rounded cards, plum pills, white surfaces).
class Pro {
  static const bg = Color(0xFFF7F3EE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241820);
  static const muted = Color(0xFF8A7C84);
  static const soft = Color(0xFF6C5F66);
  static const plum = Color(0xFF4A2740);
  static const plumSoft = Color(0xFFEDE4EA);
  static const plumPale = Color(0xFFD9C6D2);
  static const sand = Color(0xFFEDE7E0);
  static const chip = Color(0xFFF2ECE6);
  static const line = Color(0xFFE4DBD3);
  static const lineSoft = Color(0xFFE9E1DA);
  static const tip = Color(0xFFF0E8EE);
  static const warnBg = Color(0xFFFBF6F0);
  static const warnLine = Color(0xFFEADFD2);
  static const danger = Color(0xFF9B3B3B);
  static const dangerLine = Color(0xFFE4CFCF);
  static const pendingBg = Color(0xFFFBF1E2);
  static const pendingLine = Color(0xFFE3C89A);
  static const pendingInk = Color(0xFF8A6420);
  static const navMuted = Color(0xFFA99DA4);

  static const rCard = 18.0;
  static const rMd = 14.0;
  static const rSm = 12.0;
  static const rPill = 999.0;

  static BoxDecoration cardDec({Color? color, Color? border, double radius = rCard}) => BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? line),
        boxShadow: const [BoxShadow(color: Color(0x0A241820), blurRadius: 2, offset: Offset(0, 1))],
      );
}

class ProPageTitle extends StatelessWidget {
  const ProPageTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink, height: 1.2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.4)),
                ],
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
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Pro.muted),
        ),
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
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: Pro.cardDec(color: color),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Pro.rCard),
        child: body,
      ),
    );
  }
}

class ProSegment extends StatelessWidget {
  const ProSegment({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Pro.sand, borderRadius: BorderRadius.circular(Pro.rPill)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: T.dState,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: on ? Pro.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(Pro.rPill),
                  boxShadow: on
                      ? const [BoxShadow(color: Color(0x14241820), blurRadius: 3, offset: Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: labels.length > 2 ? 12 : 13,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    color: on ? Pro.ink : Pro.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ProPill extends StatelessWidget {
  const ProPill(this.label, {super.key, this.hot = false, this.soft = false});
  final String label;
  final bool hot;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hot ? Pro.plum : (soft ? Pro.sand : Pro.plumSoft),
        borderRadius: BorderRadius.circular(Pro.rPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: hot ? Colors.white : (soft ? Pro.soft : Pro.plum),
        ),
      ),
    );
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
      decoration: BoxDecoration(
        color: Pro.plumSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        _initialOf(initial),
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Pro.plum),
      ),
    );
  }
}

class ProPrimaryButton extends StatelessWidget {
  const ProPrimaryButton({super.key, required this.label, required this.onTap, this.enabled = true});
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Pro.plum,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class ProSoftButton extends StatelessWidget {
  const ProSoftButton({super.key, required this.label, required this.onTap, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Pro.rSm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Pro.rSm),
            border: Border.all(color: danger ? Pro.dangerLine : const Color(0xFFDCD2CB)),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: danger ? Pro.danger : Pro.ink),
          ),
        ),
      ),
    );
  }
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
    Color bg = Pro.chip;
    Color fg = Pro.soft;
    Border? border;
    if (pending) {
      bg = Pro.pendingBg;
      fg = Pro.pendingInk;
      border = Border.all(color: Pro.pendingLine);
    } else if (on) {
      bg = Pro.plum;
      fg = Colors.white;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Pro.rPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Pro.rPill), border: border),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fg,
            fontFamily: mono ? T.mono : null,
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
      decoration: BoxDecoration(
        color: accent ? Pro.plum : Pro.card,
        borderRadius: BorderRadius.circular(Pro.rMd),
        border: Border.all(color: accent ? Pro.plum : Pro.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: accent ? Pro.plumPale : Pro.muted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: accent ? Colors.white : Pro.ink,
                fontFamily: T.mono,
              ),
            ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F5),
        borderRadius: BorderRadius.circular(Pro.rSm),
        border: Border.all(color: const Color(0xFFE0D6CE)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.number ||
                keyboard == const TextInputType.numberWithOptions(signed: false, decimal: false)
            ? [_ProAsciiDigitFormatter()]
            : null,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: mono ? T.mono : null,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Pro.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
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
      decoration: BoxDecoration(color: Pro.ink, borderRadius: BorderRadius.circular(Pro.rSm)),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.6, color: const Color(0xFFF0E8EE))),
    );
  }
}

/// Inline «؟» that toggles a dark tip bubble (prototype behavior).
class ProHelpMark extends StatefulWidget {
  const ProHelpMark(this.text, {super.key, this.size = 18});
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
          child: InkWell(
            onTap: () => setState(() => open = !open),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC9BCC4)),
                color: open ? Pro.plumSoft : Colors.transparent,
              ),
              child: Text(
                '؟',
                style: TextStyle(fontSize: widget.size * 0.55, fontWeight: FontWeight.w700, color: open ? Pro.plum : Pro.muted, height: 1),
              ),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          ProTip(widget.text),
        ],
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
            Expanded(
              child: Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Pro.muted)),
            ),
            if (help.isNotEmpty)
              InkWell(
                onTap: () => setState(() => open = !open),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC9BCC4)),
                    color: open ? Pro.plumSoft : Colors.transparent,
                  ),
                  child: Text('؟', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: open ? Pro.plum : Pro.muted, height: 1)),
                ),
              ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
        if (open && help.isNotEmpty) ...[
          const SizedBox(height: 8),
          ProTip(help),
        ],
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
        color: dashed ? const Color(0xFFFBF8F5) : Pro.warnBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dashed ? const Color(0xFFD6C9D1) : Pro.warnLine),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, height: 1.7, color: Pro.soft)),
    );
  }
}
