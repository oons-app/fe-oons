import 'package:flutter/material.dart';
import 'package:oons/data/alerts.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Smooth in-app alert banner — readable cream card with slide + fade.
class AlertToastBanner extends StatelessWidget {
  const AlertToastBanner({super.key, required this.toast, required this.onDismiss, this.onOpen});

  final AlertToast toast;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
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
          child: InkWell(
            onTap: onOpen ?? onDismiss,
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
                            toast.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Client.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                          if (toast.body.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              toast.body,
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
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close, size: 18, color: Client.muted),
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
