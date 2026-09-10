import 'package:flutter/material.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/core/format.dart';

class V2BulkPayBar extends StatelessWidget {
  const V2BulkPayBar({
    super.key,
    required this.count,
    required this.providerGrossPiastres,
    required this.lang,
    required this.onClear,
    required this.onSettle,
  });

  final int count;
  final int providerGrossPiastres;
  final String lang;
  final VoidCallback onClear;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ops.plum,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
          child: Row(
            children: [
              Text(
                '$count ${t(V2Copy.selected, lang)}',
                style: const TextStyle(color: Ops.plumText, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Text(
                '${t(V2Copy.providerGross, lang)}: ${money(providerGrossPiastres, lang)}',
                style: const TextStyle(color: Ops.plumText, fontFamily: Ops.mono, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(foregroundColor: Ops.plumMuted),
                child: Text(t(V2Copy.clear, lang)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onSettle,
                style: ElevatedButton.styleFrom(backgroundColor: Ops.green, foregroundColor: Ops.greenInk),
                child: Text(t(V2Copy.settle, lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Client total minus trust fee — never paid out to the provider.
int providerGrossFromBooking(Map b) {
  final total = b['total'] is num ? (b['total'] as num).toInt() : int.tryParse('${b['total']}') ?? 0;
  final trust = b['trustFeeAmount'] is num
      ? (b['trustFeeAmount'] as num).toInt()
      : int.tryParse('${b['trustFeeAmount']}') ?? 0;
  final g = total - trust;
  return g < 0 ? 0 : g;
}
