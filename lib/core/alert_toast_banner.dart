import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/features/client/client_chrome.dart';

/// In-app alert. Sits below the page header so it never owns the iOS
/// status-bar swipe (that gesture opens Notification Center and can
/// background the app). Dismiss with the button, a sideways swipe, or tap
/// outside the card.
class AlertToastBanner extends StatefulWidget {
  const AlertToastBanner({super.key, required this.toast, required this.onDismiss, this.onOpen});

  final AlertToast toast;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  @override
  State<AlertToastBanner> createState() => _AlertToastBannerState();
}

class _AlertToastBannerState extends State<AlertToastBanner> {
  double _dx = 0;
  bool _closing = false;

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    widget.onDismiss();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_closing) return;
    setState(() => _dx += d.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_closing) return;
    final flung = d.velocity.pixelsPerSecond.dx.abs() > 620;
    if (_dx.abs() > 48 || flung) {
      _dismiss();
      return;
    }
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final top = MediaQuery.paddingOf(context).top;
    // Clear of the iOS status-bar / Notification Center swipe zone and the
    // in-app back row (~48pt) so the toast cannot steal a downward swipe.
    final inset = top + 56;
    final fade = (1 - (_dx.abs() / 160)).clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const ColoredBox(color: Color(0x33000000)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(14, inset, 14, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 80),
              opacity: fade,
              child: Transform.translate(
                offset: Offset(_dx, 0),
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Client.card,
                      border: Border.all(color: Client.ink, width: Client.rule),
                      boxShadow: [
                        BoxShadow(
                          color: Client.ink.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            const ColoredBox(color: Client.plum, child: SizedBox(width: 5)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.toast.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Client.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (widget.toast.body.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.toast.body,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Client.body,
                                          fontSize: 13.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          ),
                        ),
                        const ColoredBox(color: Client.line, child: SizedBox(height: 1)),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _dismiss,
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Text(
                                      ar ? 'إغلاق' : 'Dismiss',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Client.body,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onOpen != null) ...[
                              const SizedBox(width: 1, height: 48, child: ColoredBox(color: Client.line)),
                              Expanded(
                                child: InkWell(
                                  onTap: widget.onOpen,
                                  child: SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: Text(
                                        ar ? 'فتح' : 'Open',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Client.plum,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
