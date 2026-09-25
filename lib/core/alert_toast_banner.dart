import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Bottom card — never sits in the iOS status-bar swipe zone.
/// Dismiss: X, Dismiss, or tap the dimmed page. No swipe.
class AlertToastBanner extends StatelessWidget {
  const AlertToastBanner({super.key, required this.toast, required this.onDismiss, this.onOpen});

  final AlertToast toast;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  void _dismiss() {
    HapticFeedback.selectionClick();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const ColoredBox(color: Color(0x40000000)),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: bottom + 16,
          child: Material(
            color: Client.card,
            elevation: 12,
            shadowColor: Client.ink.withValues(alpha: 0.28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Client.ink, width: Client.rule),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 5, height: 44, color: Client.plum),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                toast.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Client.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.25,
                                ),
                              ),
                              if (toast.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  toast.body,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Client.body,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _dismiss,
                          tooltip: ar ? 'إغلاق' : 'Dismiss',
                          iconSize: 22,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          icon: const Icon(Icons.close, color: Client.ink),
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
                            height: 52,
                            child: Center(
                              child: Text(
                                ar ? 'إغلاق' : 'Dismiss',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Client.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (onOpen != null) ...[
                        const SizedBox(width: 1, height: 52, child: ColoredBox(color: Client.line)),
                        Expanded(
                          child: InkWell(
                            onTap: onOpen,
                            child: SizedBox(
                              height: 52,
                              child: Center(
                                child: Text(
                                  ar ? 'فتح' : 'Open',
                                  style: const TextStyle(
                                    fontSize: 15,
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
      ],
    );
  }
}
