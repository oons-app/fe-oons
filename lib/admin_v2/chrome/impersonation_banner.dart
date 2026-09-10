import 'package:flutter/material.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

class V2ImpersonationBanner extends StatelessWidget {
  const V2ImpersonationBanner({
    super.key,
    required this.name,
    required this.kind,
    required this.lang,
    required this.onExit,
  });

  final String name;
  final String kind;
  final String lang;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ops.terracotta,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility, size: 16, color: Color(0xFFFFF6F2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${t(V2Copy.impersonating, lang)} $kind · $name (${t(V2Copy.readOnly, lang)})',
                style: const TextStyle(color: Color(0xFFFFF6F2), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFF6F2)),
              child: Text(t(V2Copy.exit, lang)),
            ),
          ],
        ),
      ),
    );
  }
}
