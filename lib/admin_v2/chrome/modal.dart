import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

Future<bool> v2Confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool danger = false,
  String? roleLabel,
}) async {
  final lang = Localizations.localeOf(context).languageCode;
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: const Color(0x703B2138),
        transitionDuration: Ops.dFast,
        pageBuilder: (ctx, a1, a2) {
          return _V2Modal(
            title: title,
            onClose: () => Navigator.pop(ctx, false),
            body: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(19, 21, 19, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(body, style: const TextStyle(fontSize: 13.5, height: 1.65, color: Ops.ink)),
                  const SizedBox(height: 7),
                  Text(
                    'Recorded in the audit trail as ${roleLabel ?? 'staff'}.',
                    style: const TextStyle(fontSize: 12, color: Ops.mutedSoft, height: 1.4),
                  ),
                ],
              ),
            ),
            footer: _Footer(
              cancelLabel: cancelLabel ?? t(V2Copy.cancel, lang),
              confirmLabel: confirmLabel,
              danger: danger,
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () => Navigator.pop(ctx, true),
            ),
          );
        },
        transitionBuilder: (ctx, anim, _, child) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ) ??
      false;
}

Future<bool> v2Form(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext ctx, void Function(void Function()) setLocal) bodyBuilder,
  String? confirmLabel,
  String? cancelLabel,
  bool danger = false,
  bool Function()? onValidate,
}) async {
  final lang = Localizations.localeOf(context).languageCode;
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        barrierColor: const Color(0x703B2138),
        transitionDuration: Ops.dFast,
        pageBuilder: (ctx, a1, a2) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
                },
                child: Focus(
                  autofocus: true,
                  child: _V2Modal(
                    title: title,
                    onClose: () => Navigator.pop(ctx, false),
                    body: Padding(
                      padding: const EdgeInsets.all(19),
                      child: SingleChildScrollView(child: bodyBuilder(ctx, setLocal)),
                    ),
                    footer: _Footer(
                      cancelLabel: cancelLabel ?? t(V2Copy.cancel, lang),
                      confirmLabel: confirmLabel ?? t(V2Copy.save, lang),
                      danger: danger,
                      onCancel: () => Navigator.pop(ctx, false),
                      onConfirm: () {
                        if (onValidate != null && !onValidate()) return;
                        Navigator.pop(ctx, true);
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
        transitionBuilder: (ctx, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ) ??
      false;
}

class V2FormField extends StatelessWidget {
  const V2FormField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Ops.muted)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _V2Modal extends StatelessWidget {
  const _V2Modal({required this.title, required this.body, required this.footer, required this.onClose});
  final String title;
  final Widget body;
  final Widget footer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Ops.card,
              borderRadius: BorderRadius.circular(Ops.radiusModal),
              border: Border.all(color: Ops.border),
              boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 28, offset: Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(19, 16, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Ops.ink)),
                      ),
                      IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18, color: Ops.muted)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Ops.borderSoft),
                Flexible(child: body),
                const Divider(height: 1, color: Ops.borderSoft),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.danger = false,
  });
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 14),
      child: Row(
        children: [
          TextButton(onPressed: onCancel, child: Text(cancelLabel)),
          const Spacer(),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? Ops.terracottaInk : Ops.plum,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
