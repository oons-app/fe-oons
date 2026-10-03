import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/ds/tokens.dart';

/// Ink toast with a check, shown for 1.8s above the bottom navigation. Used for
/// every auto-save («اتحفظ») and for the error that follows a rolled-back
/// change. It never takes a tap: taps go straight through to the screen.
class DsToast {
  DsToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String message, {bool error = false, double bottomOffset = 84}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    final bottom = MediaQuery.paddingOf(context).bottom + bottomOffset;
    final entry = OverlayEntry(builder: (_) => _ToastView(message: message, error: error, bottom: bottom));
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(Ds.toastLife, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.error, required this.bottom});
  final String message;
  final bool error;
  final double bottom;
  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  bool shown = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.bottom,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: Ds.dState,
            child: Semantics(
              liveRegion: true,
              label: widget.message,
              excludeSemantics: true,
              child: Material(
                color: Ds.ink,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Ds.s4, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OnsIcon(widget.error ? 'alert' : 'check', size: 16, color: widget.error ? const Color(0xFFE3A58F) : Ds.oliveLight),
                      const SizedBox(width: Ds.s2),
                      Flexible(child: Text(widget.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Ds.cream))),
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
