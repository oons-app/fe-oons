import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

void v2Toast(BuildContext context, String msg, {bool error = false}) {
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
              color: error ? Ops.terracotta : const Color(0xFF8DBF8D),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Color(0xFFF1E8EE), fontSize: 12.5, height: 1.35, fontFamily: Ops.sans),
            ),
          ),
        ],
      ),
      backgroundColor: error ? Ops.terracottaInk : Ops.plum,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      duration: Ops.dToast,
      elevation: 0,
    ),
  );
}
