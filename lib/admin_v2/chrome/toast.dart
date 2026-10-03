import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/ds/tokens.dart';

void v2Toast(BuildContext context, String msg, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          OnsIcon(error ? 'alert' : 'check', size: 16, color: error ? Ds.terracotta : Ds.oliveLight),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Ops.plumText, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
      backgroundColor: Ops.ink,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      duration: Ops.dToast,
      elevation: 0,
    ),
  );
}
