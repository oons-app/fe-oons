import 'package:flutter/material.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';

/// Customer app chrome — matches Ons Customer App.html (cream canvas,
/// plum accents, olive trust, terracotta highlights, 1px ink borders).
class Client {
  static const bg = Color(0xFFF7F4EE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1518);
  static const plum = Color(0xFF3E2136);
  static const terracotta = Color(0xFFB5654B);
  static const olive = Color(0xFF6B7355);
  static const oliveInk = Color(0xFF4E5540);
  static const body = Color(0xFF4A3F45);
  static const muted = Color(0xFF6E655F);
  static const muted2 = Color(0xFF9A928C);
  static const line = Color(0xFFDCD4CC);
  static const sand = Color(0xFFEDE6E0);
  static const sand2 = Color(0xFFEFE9E2);
  static const hover = Color(0xFFFBF9F5);
  static const plumTint = Color(0xFFF0E6EE);
  static const warnTint = Color(0xFFF6E7E1);
  static const oliveTint = Color(0xFFE8EBE3);
  static const defer = Color(0xFF8E4B36);
  static const navMuted = Color(0xFF6E655F);

  static const rule = 1.0;
}

class ClientSectionLabel extends StatelessWidget {
  const ClientSectionLabel(this.label, {super.key, this.trailing, this.onTrailing});

  final String label;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: T.mono,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
              color: Client.muted2,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum),
              ),
            ),
        ],
      ),
    );
  }
}

class ClientSquareBtn extends StatelessWidget {
  const ClientSquareBtn({super.key, required this.label, this.onTap, this.filled = false, this.badge});

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Client.sand : Client.card,
          border: Border.all(color: Client.ink, width: Client.rule),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(label, style: const TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: Client.ink)),
            if (badge != null)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Client.terracotta, border: Border.all(color: Client.ink, width: Client.rule)),
                  child: Text(badge!, style: const TextStyle(fontFamily: T.mono, fontSize: 8, fontWeight: FontWeight.w600, color: Client.bg)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ClientAddressChip extends StatelessWidget {
  const ClientAddressChip({super.key, required this.line, required this.changeLabel, this.onTap});

  final String line;
  final String changeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 14, color: Client.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Client.ink),
              ),
            ),
            const SizedBox(width: 8),
            Text(changeLabel, style: const TextStyle(fontSize: 12, color: Client.muted2)),
          ],
        ),
      ),
    );
  }
}

class ClientSearchField extends StatelessWidget {
  const ClientSearchField({
    super.key,
    required this.hint,
    this.onTap,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
  });

  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: controller == null ? onTap : null,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
        child: Row(
          children: [
            const Text('⌕', style: TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.muted2)),
            const SizedBox(width: 10),
            if (controller != null)
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  autofocus: autofocus,
                  textInputAction: textInputAction,
                  style: const TextStyle(fontSize: 14, color: Client.ink),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 14, color: Client.muted2),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              )
            else
              Text(hint, style: const TextStyle(fontSize: 14, color: Client.muted2)),
          ],
        ),
      ),
    );
  }
}

class ClientTrustBanner extends StatelessWidget {
  const ClientTrustBanner({super.key, required this.text, required this.link, this.onTap});

  final String text;
  final String link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: Client.olive,
        child: Row(
          children: [
            const Text('⛨', style: TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.bg)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.45, color: Client.bg)),
            ),
            Text(link, style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w500, color: Client.bg.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}

class ClientPrimaryButton extends StatelessWidget {
  const ClientPrimaryButton({super.key, required this.label, this.onTap, this.enabled = true, this.trailing = true});

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Client.plum,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.bg)),
                ),
                if (trailing)
                  const Text('←', style: TextStyle(fontFamily: T.mono, fontSize: 16, color: Client.bg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClientGhostButton extends StatelessWidget {
  const ClientGhostButton({super.key, required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Client.card,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(icon!, style: const TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.ink)),
                const SizedBox(width: 9),
              ],
              Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Client.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientStatusChip extends StatelessWidget {
  const ClientStatusChip(this.label, {super.key, this.olive = true});

  final String label;
  final bool olive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: olive ? Client.olive : Client.line, width: Client.rule),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: T.mono, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: olive ? Client.oliveInk : Client.muted),
      ),
    );
  }
}

class ClientMenuRow extends StatelessWidget {
  const ClientMenuRow({super.key, required this.icon, required this.label, this.meta, this.onTap, this.danger = false});

  final String icon;
  final String label;
  final String? meta;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Client.bg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
          child: Row(
            children: [
              SizedBox(width: 26, child: Text(icon, style: const TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.body))),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: danger ? T.danger : Client.ink))),
              if (meta != null && meta!.isNotEmpty)
                Text(meta!, style: const TextStyle(fontSize: 12.5, color: Client.muted2)),
              const SizedBox(width: 8),
              const Text('›', style: TextStyle(fontFamily: T.mono, fontSize: 13, fontWeight: FontWeight.w500, color: Client.muted2)),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientSegmentTabs extends StatelessWidget {
  const ClientSegmentTabs({super.key, required this.left, required this.right, required this.index, required this.onChanged});

  final String left;
  final String right;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
      child: Row(
        children: [
          _tab(0, left),
          _tab(1, right),
        ],
      ),
    );
  }

  Widget _tab(int i, String label) {
    final on = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: on ? Client.plum : Colors.transparent, width: 3)),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: on ? Client.plum : Client.muted2),
          ),
        ),
      ),
    );
  }
}

// ── Layout primitives ────────────────────────────────────────────────────────

class ClientScaffold extends StatelessWidget {
  const ClientScaffold({super.key, required this.body, this.bottomBar, this.appBar});

  final Widget body;
  final Widget? bottomBar;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Client.bg,
      appBar: appBar,
      body: SafeArea(child: body),
      bottomNavigationBar: bottomBar,
    );
  }
}

class ClientBackHeader extends StatelessWidget {
  const ClientBackHeader({super.key, required this.title, this.meta, this.onBack});

  final String title;
  final String? meta;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
      decoration: const BoxDecoration(
        color: Client.bg,
        border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
      ),
      child: Row(
        children: [
          if (onBack != null || Navigator.of(context).canPop())
            IconButton(
              onPressed: onBack ?? () => Navigator.maybePop(context),
              icon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0, 1, 1),
                child: const Glyph(GlyphKind.back, size: 20, color: Client.ink),
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Client.ink)),
          ),
          if (meta != null)
            Text(meta!, style: const TextStyle(fontFamily: T.mono, fontSize: 10, letterSpacing: 0.8, color: Client.muted2)),
        ],
      ),
    );
  }
}

class ClientKicker extends StatelessWidget {
  const ClientKicker(this.text, {super.key, this.color = Client.muted2});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontFamily: T.mono, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w500, color: color),
    );
  }
}

class ClientDivider extends StatelessWidget {
  const ClientDivider({super.key});
  @override
  Widget build(BuildContext context) => const Divider(color: Client.ink, thickness: Client.rule, height: Client.rule);
}

class ClientTextField extends StatelessWidget {
  const ClientTextField({
    super.key,
    required this.controller,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.requiredMark = false,
  });

  final TextEditingController controller;
  final String? hint;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) {
    final hasErr = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: hasErr ? T.danger : Client.ink, width: Client.rule),
            color: Client.card,
          ),
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15, color: Client.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Client.muted2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        if (hasErr)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(errorText!, style: const TextStyle(color: T.danger, fontSize: 12.5, height: 1.35)),
          ),
      ],
    );
  }
}

class ClientFieldLabel extends StatelessWidget {
  const ClientFieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(fontFamily: T.mono, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w500, color: Client.muted2),
        ),
        if (required)
          const Text(' *', style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w700, color: T.danger)),
      ],
    );
  }
}

class ClientBookingStepper extends StatelessWidget {
  const ClientBookingStepper({super.key, required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Client.card,
        border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final n = i + 1;
          final on = step == n;
          final done = step > n;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on || done ? Client.plum : Client.card,
                    border: Border.all(color: Client.ink, width: Client.rule),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(fontFamily: T.mono, fontSize: 11, fontWeight: FontWeight.w600, color: on || done ? Client.bg : Client.muted2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? Client.plum : Client.muted2),
                  ),
                ),
                if (i < labels.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(width: 8, height: 1, color: Client.line),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class ClientStickyBar extends StatelessWidget {
  const ClientStickyBar({super.key, required this.label, required this.price, required this.cta, required this.note, required this.onTap, this.enabled = true});

  final String label;
  final String price;
  final String cta;
  final String note;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Client.bg, border: Border(top: BorderSide(color: Client.ink, width: Client.rule))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 10 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClientKicker(label),
              const Spacer(),
              Text(price, style: const TextStyle(fontFamily: T.mono, fontSize: 17, fontWeight: FontWeight.w600, color: Client.ink)),
            ],
          ),
          const SizedBox(height: 10),
          ClientPrimaryButton(label: cta, onTap: onTap, enabled: enabled),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⛨', style: TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.olive)),
              const SizedBox(width: 8),
              Expanded(child: Text(note, style: const TextStyle(fontSize: 11, height: 1.35, color: Client.muted))),
            ],
          ),
        ],
      ),
    );
  }
}

class ClientOtpBoxes extends StatelessWidget {
  const ClientOtpBoxes({super.key, required this.code, this.length = 4, this.error = false});
  final String code;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final ch = i < code.length ? code[i] : '';
        return Container(
          width: 56,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Client.card,
            border: Border.all(color: error ? T.danger : (ch.isNotEmpty ? Client.plum : Client.ink), width: Client.rule),
          ),
          child: Text(ch, style: const TextStyle(fontFamily: T.mono, fontSize: 28, fontWeight: FontWeight.w600, color: Client.ink)),
        );
      }),
    );
  }
}

class ClientNumpad extends StatelessWidget {
  const ClientNumpad({super.key, required this.onDigit, required this.onBackspace, this.compact = false});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: compact ? 6 : 8,
        crossAxisSpacing: compact ? 6 : 8,
        childAspectRatio: compact ? 2.15 : 1.6,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Client.card,
          child: InkWell(
            onTap: () {
              if (k == '⌫') {
                onBackspace();
              } else {
                onDigit(k);
              }
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
              child: Text(k, style: TextStyle(fontFamily: T.mono, fontSize: compact ? 20 : 22, fontWeight: FontWeight.w500, color: Client.ink)),
            ),
          ),
        );
      },
    );
  }
}

class ClientProviderHero extends StatelessWidget {
  const ClientProviderHero({super.key, required this.name, required this.subtitle, required this.rating, required this.reviewCount, required this.ini, this.photo, this.onReviews});

  final String name;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final String ini;
  final String? photo;
  final VoidCallback? onReviews;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Face(id: name, ini: ini, size: 84, photo: photo),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink))),
                    const ClientStatusChip('Verified', olive: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Client.muted, height: 1.4)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onReviews,
                  child: Text('$rating ★ · $reviewCount reviews', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Client.plum, decoration: TextDecoration.underline, decorationColor: Client.plum)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClientPriceRow extends StatelessWidget {
  const ClientPriceRow({super.key, required this.label, required this.amount, this.bold = false});
  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: bold ? Client.ink : Client.body))),
          Text(amount, style: TextStyle(fontFamily: T.mono, fontSize: bold ? 20 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w400, color: Client.ink)),
        ],
      ),
    );
  }
}

class ClientSelectRow extends StatelessWidget {
  const ClientSelectRow({super.key, required this.selected, required this.title, this.subtitle, required this.onTap});

  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Client.plum : Client.ink, width: Client.rule),
            color: selected ? Client.plumTint : Client.card,
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: selected ? Client.plum : Colors.transparent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Client.ink)),
                    if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11, color: Client.muted, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientEmptyState extends StatelessWidget {
  const ClientEmptyState({super.key, required this.title, required this.body, this.cta, this.onCta});

  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Client.sand, border: Border.all(color: Client.ink, width: Client.rule)),
            child: const Text('◌', style: TextStyle(fontFamily: T.mono, fontSize: 24, color: Client.muted2)),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink)),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, color: Client.body)),
          if (cta != null && onCta != null) ...[
            const SizedBox(height: 24),
            ClientPrimaryButton(label: cta!, onTap: onCta),
          ],
        ],
      ),
    );
  }
}

void showClientVerifiedSheet(BuildContext context, {required String title, required String body, required String lang}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Client.bg,
    shape: const RoundedRectangleBorder(),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⛨', style: TextStyle(fontFamily: T.mono, fontSize: 18, color: Client.olive)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Client.ink))),
            ],
          ),
          const SizedBox(height: 14),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.55, color: Client.body)),
          const SizedBox(height: 20),
          ClientPrimaryButton(
            label: lang == 'ar' ? 'فهمت' : 'Got it',
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

class ClientAuthHeader extends StatelessWidget {
  const ClientAuthHeader({super.key, this.showLang = true, this.onLang});

  final bool showLang;
  final VoidCallback? onLang;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
      decoration: const BoxDecoration(
        color: Client.bg,
        border: Border(bottom: BorderSide(color: Client.plum, width: Client.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const BrandMark(size: 40),
          const Spacer(),
          if (showLang && onLang != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLang,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: Client.plum, width: Client.rule)),
                  child: Text(
                    Directionality.of(context) == TextDirection.rtl ? 'EN' : 'ع',
                    style: const TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: Client.plum),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ClientTrustScreenBody extends StatelessWidget {
  const ClientTrustScreenBody({super.key, required this.title, required this.body, required this.bullets, required this.cta, required this.onCta, this.skip, this.onSkip});

  final String title;
  final String body;
  final List<String> bullets;
  final String cta;
  final VoidCallback onCta;
  final String? skip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: Client.olive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ONS TRUST', style: TextStyle(fontFamily: T.mono, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500, color: Client.bg.withValues(alpha: 0.85))),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, color: Client.bg)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body, style: const TextStyle(fontSize: 15, height: 1.55, color: Client.body)),
              const SizedBox(height: 20),
              ...bullets.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓', style: TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.olive, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Client.body))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ClientPrimaryButton(label: cta, onTap: onCta),
              if (skip != null && onSkip != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSkip, child: Text(skip!, style: const TextStyle(fontSize: 13, color: Client.muted))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
