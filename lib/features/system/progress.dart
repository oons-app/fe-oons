import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Progress states (design system §07).
///
/// Pick the treatment by how long the wait is:
///   < 1s   nothing — a flash of spinner is worse than the wait
///   1–3s   spinner inside the button; the rest of the screen is untouched
///   > 3s   content-shaped skeleton, or a bar with a REAL percentage
///   hours+ named stages ([JourneyStages]), never a creeping bar
/// Rule across all of them: no bare spinner beyond two seconds — say what is
/// being waited on, what is safe, and when it stops. The hold deadline always
/// comes from the server, never from a client timer.
enum ProgressTreatment { none, inlineSpinner, skeletonOrBar, journey }

ProgressTreatment progressTreatmentFor(Duration expected) {
  if (expected < const Duration(seconds: 1)) return ProgressTreatment.none;
  if (expected <= const Duration(seconds: 3)) return ProgressTreatment.inlineSpinner;
  if (expected < const Duration(hours: 1)) return ProgressTreatment.skeletonOrBar;
  return ProgressTreatment.journey;
}

bool _reduceMotion(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;

// ── 1. Skeleton ────────────────────────────────────────────────────────────

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height = 12});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Client.sand2, border: Border.all(color: Client.line, width: Client.rule)),
      );
}

/// Content-shaped skeleton (design-system name). Same as [ServiceListSkeleton].
typedef OnsSkeleton = ServiceListSkeleton;

/// Full-page wait for a 1–3s fetch. Names what is loading; never a bare spinner.
class OnsBusyPage extends StatelessWidget {
  const OnsBusyPage({super.key, required this.caption});
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Client.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const InlineSpinner(size: 22),
              const SizedBox(height: 14),
              Text(caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Client.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Takes the shape and count of the real content (not random rectangles). The
/// real [heading] stays visible; [caption] says what is loading.
class ServiceListSkeleton extends StatefulWidget {
  const ServiceListSkeleton({super.key, required this.heading, required this.caption, this.rows = 4});
  final String heading;
  final String caption;
  final int rows;

  @override
  State<ServiceListSkeleton> createState() => _ServiceListSkeletonState();
}

class _ServiceListSkeletonState extends State<ServiceListSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: widget.caption,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Client.ink)),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Opacity(opacity: 0.55 + 0.45 * (1 - _c.value), child: child),
              child: Column(
                children: List.generate(
                  widget.rows,
                  (_) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.line, width: Client.rule))),
                    child: const Row(
                      children: [
                        SkeletonBlock(width: 96, height: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBlock(width: 140, height: 13),
                              SizedBox(height: 8),
                              SkeletonBlock(width: 190, height: 10),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        SkeletonBlock(width: 52, height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.caption, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Client.muted)),
          ],
        ),
      ),
    );
  }
}

// ── 2. Busy button (+ sibling lock) ───────────────────────────────────────

/// Groups a [BusyButton] with the controls that must lock while it runs.
/// Double-submit is impossible: the lock is part of the state.
class BusyGroup extends StatefulWidget {
  const BusyGroup({super.key, required this.child});
  final Widget child;

  static bool isBusy(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BusyScope>()?.busy ?? false;

  @override
  State<BusyGroup> createState() => _BusyGroupState();
}

class _BusyGroupState extends State<BusyGroup> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _BusyScope(busy: _busy, run: _run, child: widget.child);
}

class _BusyScope extends InheritedWidget {
  const _BusyScope({required this.busy, required this.run, required super.child});
  final bool busy;
  final Future<void> Function(Future<void> Function()) run;

  @override
  bool updateShouldNotify(_BusyScope o) => o.busy != busy;
}

/// Wrap sibling controls so they lock while the group is busy.
class BusyLock extends StatelessWidget {
  const BusyLock({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final busy = BusyGroup.isBusy(context);
    return IgnorePointer(ignoring: busy, child: Opacity(opacity: busy ? 0.45 : 1, child: child));
  }
}

/// States what is actually happening ("نؤكّد الموعد…") and only returns to its
/// idle label when the action finishes. Must sit inside a [BusyGroup].
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busyLabel, required this.onPressed, this.enabled = true});
  final String label;
  final String busyLabel;
  final Future<void> Function() onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BusyScope>();
    assert(scope != null, 'BusyButton must be inside a BusyGroup');
    final busy = scope?.busy ?? false;
    return Semantics(
      button: true,
      enabled: enabled && !busy,
      label: busy ? busyLabel : label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Client.plum,
          child: InkWell(
            onTap: (!enabled || busy) ? null : () => scope?.run(onPressed),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (busy) ...[const InlineSpinner(color: Client.bg, size: 16), const SizedBox(width: 10)],
                  Expanded(
                    child: Text(busy ? busyLabel : label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.bg)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small wait that stays beside its field (coupon input, button). Never cover
/// the whole screen for something small.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = 14, this.color = Client.plum});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
      );
}

// ── 3. Handoff + hold ─────────────────────────────────────────────────────

/// Countdown to a SERVER-issued deadline (`paymentHoldUntil`). [now] is
/// injectable for tests. Fires [onExpired] once.
class HoldCountdown extends StatefulWidget {
  const HoldCountdown({super.key, required this.deadline, required this.label, this.ar = true, this.onExpired, this.now});
  final DateTime deadline;
  final String label;
  final bool ar;
  final VoidCallback? onExpired;
  final DateTime Function()? now;

  @override
  State<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<HoldCountdown> {
  Timer? _t;
  bool _fired = false;

  DateTime get _now => (widget.now ?? DateTime.now)();
  Duration get _left {
    final d = widget.deadline.difference(_now);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (_left == Duration.zero && !_fired) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final mm = left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    final txt = digits('$mm:$ss', ar: widget.ar);
    return Semantics(
      liveRegion: false,
      label: '${widget.label} $txt',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(txt, style: const TextStyle(fontFamily: T.mono, fontSize: 16, fontWeight: FontWeight.w600, color: Client.ink)),
            ),
            const SizedBox(width: 8),
            const OnsIcon('clock', size: 16, color: Client.ink),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.ink))),
          ],
        ),
      ),
    );
  }
}

// ── 4. Determinate vs indeterminate ───────────────────────────────────────

/// Real percentage → filling bar + number. Unknown duration → moving bar and
/// NO number. Never invent 99%.
class OnsProgressBar extends StatefulWidget {
  const OnsProgressBar.determinate({super.key, required double this.value, this.numberLabel}) : assert(value >= 0 && value <= 1);
  const OnsProgressBar.indeterminate({super.key})
      : value = null,
        numberLabel = null;

  final double? value;
  final String? numberLabel;

  bool get isDeterminate => value != null;

  @override
  State<OnsProgressBar> createState() => _OnsProgressBarState();
}

class _OnsProgressBarState extends State<OnsProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.isDeterminate && !_reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final fill = widget.isDeterminate ? w * widget.value! : w * 0.32;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        Widget seg() => Container(width: fill, height: 6, color: Client.plum);
        return Container(
          height: 6,
          decoration: const BoxDecoration(color: Client.line),
          child: widget.isDeterminate
              ? Align(alignment: AlignmentDirectional.centerStart, child: seg())
              : AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final x = (w + fill) * _c.value - fill;
                    return Stack(children: [Positioned(left: rtl ? null : x, right: rtl ? x : null, child: seg())]);
                  },
                ),
        );
      },
    );
    return Semantics(
      value: widget.isDeterminate ? '${(widget.value! * 100).round()}%' : null,
      child: Row(
        children: [
          Expanded(child: ClipRect(child: bar)),
          if (widget.isDeterminate && widget.numberLabel != null) ...[
            const SizedBox(width: 10),
            Text(widget.numberLabel!, style: const TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: Client.ink)),
          ],
        ],
      ),
    );
  }
}

/// Design-system names. Determinate always shows a number; indeterminate never
/// invents one.
class DeterminateBar extends OnsProgressBar {
  const DeterminateBar({super.key, required super.value, super.numberLabel}) : super.determinate();
}

class IndeterminateBar extends OnsProgressBar {
  const IndeterminateBar({super.key}) : super.indeterminate();
}

// ── 5. Journey ────────────────────────────────────────────────────────────

/// For anything spanning hours or days: named stages. Past = olive, current =
/// plum, future = hairline.
class JourneyStages extends StatelessWidget {
  const JourneyStages({super.key, required this.stages, required this.current});
  final List<String> stages;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: stages[current.clamp(0, stages.length - 1)],
      child: Row(
        children: List.generate(stages.length, (i) {
          final past = i < current;
          final now = i == current;
          final bar = past ? Client.olive : (now ? Client.plum : Client.line);
          final fg = past ? Client.oliveInk : (now ? Client.plum : Client.muted2);
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: i == stages.length - 1 ? 0 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 4, color: bar),
                  const SizedBox(height: 6),
                  Text(stages[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: now ? FontWeight.w700 : FontWeight.w500, color: fg)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── 6. Optimistic add with undo, rollback with a reason ───────────────────

/// Applies [apply] immediately, then awaits [request]. If it throws, [rollback]
/// runs and [onRejected] receives the reason — never a silent disappearance.
/// Returns true when the server accepted.
Future<bool> runOptimistic({
  required void Function() apply,
  required void Function() rollback,
  required Future<void> Function() request,
  required void Function(Object reason) onRejected,
}) async {
  apply();
  try {
    await request();
    return true;
  } catch (e) {
    rollback();
    onRejected(e);
    return false;
  }
}

/// "اتزوّد · X   تراجع" — the add already happened; this only offers the undo.
void showUndoSnack(BuildContext context, {required String message, required String undoLabel, required VoidCallback onUndo}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      backgroundColor: Client.ink,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      duration: const Duration(seconds: 6),
      content: Text(message, style: const TextStyle(color: Client.bg, fontSize: 13.5)),
      action: SnackBarAction(label: undoLabel, textColor: Client.bg, onPressed: onUndo),
    ),
  );
}
