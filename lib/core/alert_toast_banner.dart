import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Cream in-app alert. Close button or swipe any direction to dismiss.
class AlertToastBanner extends StatefulWidget {
  const AlertToastBanner({super.key, required this.toast, required this.onDismiss, this.onOpen});

  final AlertToast toast;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  @override
  State<AlertToastBanner> createState() => _AlertToastBannerState();
}

class _AlertToastBannerState extends State<AlertToastBanner> {
  Offset _drag = Offset.zero;
  bool _closing = false;

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    widget.onDismiss();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_closing) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_closing) return;
    final flung = d.velocity.pixelsPerSecond.distance > 620;
    if (_drag.distance > 36 || flung) {
      _dismiss();
      return;
    }
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final fade = (1 - (_drag.distance / 160)).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: widget.onOpen ?? widget.onDismiss,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 80),
          opacity: fade,
          child: Transform.translate(
            offset: _drag,
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
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: Client.plum),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            onPressed: _dismiss,
                            tooltip: 'Dismiss',
                            style: IconButton.styleFrom(
                              backgroundColor: Client.bg,
                              side: const BorderSide(color: Client.ink, width: Client.rule),
                              shape: const RoundedRectangleBorder(),
                              minimumSize: const Size(36, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.close, size: 18, color: Client.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
