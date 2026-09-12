import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';

class Ltr extends StatelessWidget {
  const Ltr({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.ltr, child: child);
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.color = T.action});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = T.muted});
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

class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.danger = false,
    this.enabled = true,
    this.trailing = true,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool danger;
  final bool enabled;
  final bool trailing;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = !filled
        ? Colors.transparent
        : danger
            ? T.danger
            : T.action;
    final fg = filled ? T.white : T.ink;
    final canTap = enabled && !busy;
    return Opacity(
      opacity: canTap ? 1 : 0.45,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: canTap ? onTap : null,
          onHighlightChanged: (_) {},
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: filled ? null : BoxDecoration(border: Border.all(color: T.ink, width: T.rule)),
            child: Row(
              children: [
                Expanded(
                  child: busy
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                          ),
                        )
                      : Text(label, textAlign: TextAlign.start, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                ),
                if (trailing && filled && !busy)
                  Icon(Icons.arrow_forward, size: 18, color: fg, textDirection: Directionality.of(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule)),
        alignment: AlignmentDirectional.centerStart,
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
      ),
    );
  }
}

class LangChip extends StatelessWidget {
  const LangChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule)),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
      ),
    );
  }
}

class AvatarIni extends StatelessWidget {
  const AvatarIni(this.ini, {super.key, this.size = 64});
  final String ini;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: T.ink, width: T.rule),
        color: T.sand,
      ),
      child: Text(ini, style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.w800)),
    );
  }
}

String? resolveMedia(String? src) {
  if (src == null || src.isEmpty) return null;
  if (Face.photos.containsKey(src)) return Face.photos[src];
  if (src.startsWith('http') || src.startsWith('assets/')) return src;
  if (src.startsWith('/')) {
    return '${apiHost()}$src';
  }
  return null;
}

class MediaThumb extends StatelessWidget {
  const MediaThumb(this.src, {super.key, this.fit = BoxFit.cover});
  final String src;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final path = resolveMedia(src) ?? src;
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => const ColoredBox(color: T.sand));
    }
    return Image.network(
      path,
      fit: fit,
      headers: {
        if (api.accessToken != null && api.accessToken!.isNotEmpty) 'Authorization': 'Bearer ${api.accessToken}',
      },
      errorBuilder: (_, __, ___) => const ColoredBox(color: T.sand),
    );
  }
}

void openGallery(BuildContext context, List<String> shots, {int index = 0}) {
  if (shots.isEmpty) return;
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, __, ___) => GalleryPage(shots: shots, index: index),
  ));
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.shots, this.index = 0});
  final List<String> shots;
  final int index;
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final PageController ctrl = PageController(initialPage: widget.index);

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: T.ink,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: ctrl,
              itemCount: widget.shots.length,
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(child: MediaThumb(widget.shots[i], fit: BoxFit.contain)),
              ),
            ),
            PositionedDirectional(
              start: 8,
              top: 8,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(ar ? 'قفل' : 'Close', style: const TextStyle(color: T.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Face extends StatelessWidget {
  const Face({super.key, this.id, this.ini = '', this.size = 64, this.photo});
  final String? id;
  final String ini;
  final double size;
  final String? photo;

  static const photos = {
    '65a000000000000000000001': 'assets/images/providers/salma.png',
    '65a000000000000000000002': 'assets/images/providers/nourhan.png',
    '65a000000000000000000003': 'assets/images/providers/doaa.png',
    '65a000000000000000000004': 'assets/images/providers/heba.png',
    'client': 'assets/images/providers/nour.png',
    'salma': 'assets/images/providers/salma.png',
    'nourhan': 'assets/images/providers/nourhan.png',
    'doaa': 'assets/images/providers/doaa.png',
    'heba': 'assets/images/providers/heba.png',
    'nour': 'assets/images/providers/nour.png',
  };

  static const clientKey = 'client';

  @override
  Widget build(BuildContext context) {
    final path = resolveMedia(photo) ?? photos[id] ?? photos[photo];
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: T.ink, width: T.rule),
        color: T.sand,
      ),
      child: path == null
          ? Center(child: Text(ini, style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.w800)))
          : MediaThumb(path, fit: BoxFit.cover),
    );
  }
}

IconData glyphTimeline(String key) {
  switch (key) {
    case 'booked':
      return Icons.event_available_outlined;
    case 'confirmed':
      return Icons.payments_outlined;
    case 'on_the_way':
      return Icons.directions_walk;
    case 'checked_in':
      return Icons.handshake_outlined;
    case 'checked_out':
      return Icons.task_alt;
    default:
      return Icons.circle_outlined;
  }
}

IconData glyphStatus(String status) {
  switch (status) {
    case 'pending_payment':
      return Icons.schedule;
    case 'paid':
      return Icons.verified_outlined;
    case 'on_the_way':
      return Icons.directions_walk;
    case 'in_progress':
      return Icons.handshake_outlined;
    case 'completed':
      return Icons.task_alt;
    case 'disputed':
      return Icons.flag_outlined;
    case 'refunded':
      return Icons.replay;
    case 'cancelled_client':
    case 'cancelled_provider':
      return Icons.cancel_outlined;
    default:
      return Icons.circle_outlined;
  }
}

class CtaBar extends StatelessWidget {
  const CtaBar({super.key, required this.label, required this.price, required this.cta, required this.note, required this.onTap, this.enabled = true});
  final String label;
  final String price;
  final String cta;
  final String note;
  final VoidCallback onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: T.bg, border: Border(top: BorderSide(color: T.ink, width: T.rule))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 10 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Kicker(label),
              const Spacer(),
              Text(price, style: const TextStyle(fontFamily: T.mono, fontSize: 17, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          InkButton(label: cta, onTap: onTap, enabled: enabled),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 13, color: T.trust),
              const SizedBox(width: 8),
              Expanded(child: Text(note, style: const TextStyle(fontSize: 11, height: 1.35, color: T.muted))),
            ],
          ),
        ],
      ),
    );
  }
}

class ScreenHead extends StatelessWidget {
  const ScreenHead({super.key, required this.title, this.meta, this.onBack});
  final String title;
  final String? meta;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink, width: T.rule))),
      child: Row(
        children: [
          if (onBack != null || Navigator.of(context).canPop())
            IconButton(
              onPressed: onBack ?? () => Navigator.maybePop(context),
              icon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0,
                  1,
                  1,
                ),
                child: const Glyph(GlyphKind.back, size: 20, color: T.ink),
              ),
            )
          else
            const SizedBox(width: 16),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4),
            ),
          ),
          if (meta != null)
            Text(meta!, style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: T.muted)),
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      width: double.infinity,
      color: const Color(0xFFF6E7E1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFF8E4B36)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ar ? 'مفيش إنترنت دلوقتي. أي حاجة بتتسجل وهتتبعت لما النت يرجع.' : 'No internet. Changes are saved and will sync when you’re back online.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.35, color: Color(0xFF4A3F45)),
            ),
          ),
        ],
      ),
    );
  }
}

class Skel extends StatelessWidget {
  const Skel({super.key, required this.width, required this.height});
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 1400),
      builder: (context, v, child) => Opacity(opacity: reduce ? 0.6 : v, child: child),
      onEnd: () {},
      child: Container(width: width, height: height, color: T.line),
    );
  }
}

/// Keeps the client looking like a phone even in a wide Chrome window.
class PhoneCanvas extends StatelessWidget {
  const PhoneCanvas({super.key, required this.child});
  final Widget child;

  static const frameWidth = 390.0;
  static const breakWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= breakWidth;
    if (!wide) return child;
    final h = (size.height - 48).clamp(640.0, 874.0);
    return ColoredBox(
      color: T.sand,
      child: Center(
        child: Container(
          width: frameWidth,
          height: h,
          decoration: BoxDecoration(
            color: T.bg,
            border: Border.all(color: T.ink, width: T.rule),
          ),
          clipBehavior: Clip.hardEdge,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(frameWidth, h),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class OonsTabBar extends StatelessWidget {
  const OonsTabBar({super.key, required this.index, required this.labels, required this.onTap, this.provider = false});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onTap;
  final bool provider;

  static const height = 76.0;

  List<int> _clientVisualOrder(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return rtl ? [0, 1, 2] : [2, 1, 0];
  }

  @override
  Widget build(BuildContext context) {
    if (provider) return _proBar(context);
    final order = _clientVisualOrder(context);
    return Material(
      color: const Color(0xFFF7F4EE),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1C1518), width: 1))),
          child: SizedBox(
            height: height,
            child: Row(
              children: order.map((i) {
                final on = index == i;
                final active = const Color(0xFFF7F4EE);
                final idle = const Color(0xFF6E655F);
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      tapLight();
                      onTap(i);
                    },
                    child: ColoredBox(
                      color: on ? const Color(0xFF3E2136) : const Color(0xFFF7F4EE),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Glyph(tabGlyph(i, provider: false), size: 20, color: on ? active : idle, fill: on),
                          const SizedBox(height: 5),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                              color: on ? active : idle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _proBar(BuildContext context) {
    const plum = Color(0xFF4A2740);
    const muted = Color(0xFF8A7C84);
    const soft = Color(0xFFEDE4EA);
    const line = Color(0xFFE9E1DA);
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))),
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: List.generate(labels.length, (i) {
                  final on = index == i;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        tapLight();
                        onTap(i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: T.dState,
                            width: 36,
                            height: 26,
                            decoration: BoxDecoration(
                              color: on ? soft : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Glyph(
                              tabGlyph(i, provider: true),
                              size: 18,
                              color: on ? plum : const Color(0xFFA99DA4),
                              fill: on,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? plum : muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void tapLight() => HapticFeedback.lightImpact();
void tapSuccess() => HapticFeedback.mediumImpact();
void tapWarn() => HapticFeedback.heavyImpact();
