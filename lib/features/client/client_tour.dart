import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';

const _tourKey = 'client_home_tour_done';

/// Shared client tab index so Profile "Replay tour" can switch back to Home
/// without relying on GoRouter (tabs are local in ClientShell).
final clientShellTab = ValueNotifier<int>(0);

bool clientTourDone() => Hive.box('prefs').get(_tourKey, defaultValue: false) as bool;

Future<void> setClientTourDone(bool done) async {
  await Hive.box('prefs').put(_tourKey, done);
}

Future<void> resetClientTour() => setClientTourDone(false);

/// Clears the done flag and jumps the shell to Home so the tour can show.
Future<void> replayClientTour() async {
  await resetClientTour();
  clientShellTab.value = 0;
}

class ClientTourStep {
  const ClientTourStep({required this.targetKey, required this.title, required this.body});
  final GlobalKey targetKey;
  final String title;
  final String body;
}

class ClientTourOverlay extends StatefulWidget {
  const ClientTourOverlay({super.key, required this.steps, required this.onDone, this.skipLabel = 'Skip', this.nextLabel = 'Next', this.doneLabel = 'Got it'});

  final List<ClientTourStep> steps;
  final VoidCallback onDone;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;

  @override
  State<ClientTourOverlay> createState() => _ClientTourOverlayState();
}

class _ClientTourOverlayState extends State<ClientTourOverlay> {
  int step = 0;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
  }

  Future<void> _finish() async {
    if (closing) return;
    closing = true;
    await setClientTourDone(true);
    if (!mounted) return;
    widget.onDone();
  }

  void _ensureVisible() {
    if (!mounted || step >= widget.steps.length) return;
    final ctx = widget.steps[step].targetKey.currentContext;
    if (ctx == null) {
      // Rebuild once layouts settle so targets that load async can appear.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() {});
      });
      return;
    }
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), alignment: 0.25, curve: Curves.easeOut).then((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _targetRect() {
    if (step >= widget.steps.length) return null;
    final ctx = widget.steps[step].targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @override
  Widget build(BuildContext context) {
    if (step >= widget.steps.length || closing) return const SizedBox.shrink();
    final rect = _targetRect();
    final s = widget.steps[step];
    final last = step == widget.steps.length - 1;
    final size = MediaQuery.sizeOf(context);
    final cardTop = rect != null
        ? (rect.bottom + 16).clamp(72.0, size.height * 0.52)
        : size.height * 0.32;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: CustomPaint(
                painter: _SpotlightPainter(hole: rect?.inflate(8)),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: cardTop,
            child: _CoachCard(
              title: s.title,
              body: s.body,
              step: step + 1,
              total: widget.steps.length,
              skipLabel: widget.skipLabel,
              nextLabel: last ? widget.doneLabel : widget.nextLabel,
              onSkip: _finish,
              onNext: () async {
                if (last) {
                  await _finish();
                } else {
                  setState(() => step++);
                  WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.body,
    required this.step,
    required this.total,
    required this.skipLabel,
    required this.nextLabel,
    required this.onSkip,
    required this.onNext,
  });

  final String title;
  final String body;
  final int step;
  final int total;
  final String skipLabel;
  final String nextLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Client.card,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Client.card,
          border: Border.all(color: Client.ink, width: Client.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$step / $total'.toUpperCase(),
              style: const TextStyle(fontFamily: T.mono, fontSize: 10, letterSpacing: 1.2, color: Client.muted2),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Client.ink)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Client.body)),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(onPressed: onSkip, child: Text(skipLabel, style: const TextStyle(fontSize: 13, color: Client.muted))),
                const Spacer(),
                Material(
                  color: Client.plum,
                  child: InkWell(
                    onTap: onNext,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(nextLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Client.bg)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({this.hole});
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Client.ink.withValues(alpha: 0.72);
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(4)));
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, paint);
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(4)),
        Paint()
          ..color = Client.plum
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.hole != hole;
}
