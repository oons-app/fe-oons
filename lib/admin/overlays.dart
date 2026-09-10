import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/core/format.dart';

/// Design-faithful toast (bottom-right plum chip).
void opsToast(BuildContext context, String msg, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: error ? T.warm : const Color(0xFF8DBF8D),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Color(0xFFF1E8EE), fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
      backgroundColor: error ? T.warmInk : T.action,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      duration: const Duration(milliseconds: 2600),
      elevation: 0,
    ),
  );
}

Future<bool> showOpsConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? roleLabel,
  bool danger = false,
  String cancelLabel = 'Cancel',
}) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x703B2138),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return _OpsModalScaffold(
        title: title,
        onClose: () => Navigator.pop(ctx, false),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(19, 21, 19, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(body, style: const TextStyle(fontSize: 13.5, height: 1.65, color: T.ink)),
              const SizedBox(height: 7),
              Text(
                'Recorded in the audit trail as ${roleLabel ?? 'staff'}.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8C7F8A), height: 1.4),
              ),
            ],
          ),
        ),
        footer: _OpsModalFooter(
          cancelLabel: cancelLabel,
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
  );
  return ok == true;
}

/// Host a StatefulBuilder form body inside Ops modal chrome. Returns true on Save.
Future<bool> showOpsPanel(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext ctx, void Function(void Function()) setLocal) bodyBuilder,
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  bool danger = false,
  bool Function()? onValidate,
}) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x703B2138),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return _OpsModalScaffold(
            title: title,
            onClose: () => Navigator.pop(ctx, false),
            body: Padding(
              padding: const EdgeInsets.all(19),
              child: bodyBuilder(ctx, setLocal),
            ),
            footer: _OpsModalFooter(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              danger: danger,
              onCancel: () => Navigator.pop(ctx, false),
              onConfirm: () {
                if (onValidate != null && !onValidate()) return;
                Navigator.pop(ctx, true);
              },
            ),
          );
        },
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
  );
  return ok == true;
}

/// Form modal: [fields] are laid out in a 2-col grid. Returns true if Save pressed.
Future<bool> showOpsForm(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  bool Function()? onValidate,
}) async {
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x703B2138),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return _OpsModalScaffold(
        title: title,
        onClose: () => Navigator.pop(ctx, false),
        body: Padding(
          padding: const EdgeInsets.all(19),
          child: LayoutBuilder(
            builder: (ctx, box) {
              final wide = box.maxWidth >= 420;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: 13),
                      fields[i],
                    ],
                  ],
                );
              }
              final rows = <Widget>[];
              for (var i = 0; i < fields.length; i += 2) {
                final a = fields[i];
                final b = i + 1 < fields.length ? fields[i + 1] : const SizedBox.shrink();
                rows.add(Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 13),
                    Expanded(child: b),
                  ],
                ));
                if (i + 2 < fields.length) rows.add(const SizedBox(height: 13));
              }
              return Column(mainAxisSize: MainAxisSize.min, children: rows);
            },
          ),
        ),
        footer: _OpsModalFooter(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () {
            if (onValidate != null && !onValidate()) return;
            Navigator.pop(ctx, true);
          },
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
  );
  return ok == true;
}

class OpsFormField extends StatelessWidget {
  const OpsFormField({
    super.key,
    required this.label,
    required this.child,
    this.fullWidth = false,
  });
  final String label;
  final Widget child;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF5C4F5A))),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class OpsBulkSettleResult {
  const OpsBulkSettleResult({required this.receipt, this.note = ''});
  final XFile receipt;
  final String note;
}

Future<OpsBulkSettleResult?> showOpsBulkSettle(
  BuildContext context, {
  required String title,
  required String providerLabel,
  required int visitCount,
  required int clientTotalPiastres,
  required int providerGrossPiastres,
  required String lang,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Settle & send',
}) async {
  XFile? receipt;
  final note = TextEditingController();
  Future<void> pick(void Function(void Function()) setLocal) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (f != null) setLocal(() => receipt = f);
  }

  final result = await showGeneralDialog<OpsBulkSettleResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x703B2138),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, a1, a2) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return _OpsModalScaffold(
            title: title,
            onClose: () => Navigator.pop(ctx),
            body: Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Provider', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF5C4F5A))),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: T.surface,
                      borderRadius: BorderRadius.circular(T.radiusSm),
                      border: Border.all(color: T.lineStrong),
                    ),
                    child: Text(providerLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 14),
                  const Text('Transfer receipt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF5C4F5A))),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => pick(setLocal),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF1EC),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFFD9BFB4)),
                      ),
                      child: Column(
                        children: [
                          const Text('Drop the InstaPay screenshot here', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            receipt?.name ?? 'PNG · JPG · WEBP',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7F8A), fontFamily: T.mono),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => pick(setLocal),
                      child: Text(receipt == null ? 'Attach receipt' : 'Change receipt'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(hintText: 'Optional note'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F1E9),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFEBE2D6)),
                    ),
                    child: Column(
                      children: [
                        _BulkSumRow(label: 'Visits', value: '$visitCount'),
                        _BulkSumRow(label: 'Client total', value: money(clientTotalPiastres, lang)),
                        _BulkSumRow(label: 'Provider gross', value: money(providerGrossPiastres, lang)),
                        const _BulkSumRow(label: 'Trust fee', value: 'Excluded from Excel'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Settling writes a batch, generates the ops Excel with client total net of trust fee, and queues the WhatsApp receipt.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8C7F8A), height: 1.6),
                  ),
                ],
              ),
            ),
            footer: _OpsModalFooter(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () {
                if (receipt == null) {
                  opsToast(ctx, 'Attach a transfer receipt first', error: true);
                  return;
                }
                Navigator.pop(ctx, OpsBulkSettleResult(receipt: receipt!, note: note.text.trim()));
              },
            ),
          );
        },
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
  );
  note.dispose();
  return result;
}

class _BulkSumRow extends StatelessWidget {
  const _BulkSumRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5C4F5A)))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: T.mono)),
        ],
      ),
    );
  }
}

/// Sticky bottom bulk-pay bar (design #3B2138).
class OpsBulkBar extends StatelessWidget {
  const OpsBulkBar({
    super.key,
    required this.count,
    required this.grossLabel,
    required this.onClear,
    required this.onSettle,
    this.busy = false,
  });

  final int count;
  final String grossLabel;
  final VoidCallback onClear;
  final VoidCallback onSettle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Material(
      color: T.action,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$count visits selected',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFFF1E8EE)),
              ),
              Text(
                'Provider gross $grossLabel',
                style: const TextStyle(fontSize: 13, color: Color(0xFFBCA9B8), fontFamily: T.mono),
              ),
              const Text(
                'Trust fee excluded from gross',
                style: TextStyle(fontSize: 12, color: Color(0xFF9C8898)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: busy ? null : onClear,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFCBB8C6)),
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: busy ? null : onSettle,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF1E8EE),
                  foregroundColor: T.action,
                ),
                child: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: T.action))
                    : const Text('Settle & send receipt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsModalScaffold extends StatelessWidget {
  const _OpsModalScaffold({
    required this.title,
    required this.body,
    required this.footer,
    required this.onClose,
  });
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
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 640),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.line),
              boxShadow: const [
                BoxShadow(color: Color(0x473B2138), blurRadius: 60, offset: Offset(0, 24)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 17, 10, 17),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: T.ink)),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, size: 20, color: T.muted),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEBE2D6)),
                Flexible(
                  child: SingleChildScrollView(child: body),
                ),
                const Divider(height: 1, color: Color(0xFFEBE2D6)),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpsModalFooter extends StatelessWidget {
  const _OpsModalFooter({
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
      padding: const EdgeInsets.fromLTRB(19, 15, 19, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: T.ink,
              side: const BorderSide(color: T.lineStrong),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 9),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: danger ? T.warmInk : T.action,
              foregroundColor: danger ? const Color(0xFFFFF6F2) : T.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// Coral impersonation strip (design).
class OpsImpersonationBanner extends StatelessWidget {
  const OpsImpersonationBanner({
    super.key,
    required this.label,
    required this.onExit,
  });
  final String label;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.warm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility, size: 16, color: Color(0xFFFFF6F2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFFFFF6F2), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFF6F2)),
              child: const Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }
}
