import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/core/format.dart';

/// Sticky plum footer shown while selecting visits for bulk pay — mirrors the
/// prototype's `bulkBarOpen` bar: count, provider gross, a trust-fee note, and
/// Clear / Settle actions.
class V2BulkPayBar extends StatelessWidget {
  const V2BulkPayBar({
    super.key,
    required this.count,
    required this.providerGrossPiastres,
    required this.lang,
    required this.onClear,
    required this.onSettle,
    this.trustFeeExcludedPiastres = 0,
  });

  final int count;
  final int providerGrossPiastres;
  final int trustFeeExcludedPiastres;
  final String lang;
  final VoidCallback onClear;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final ar = lang == 'ar';
    return Material(
      color: Ops.plum,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Ops.gutter, 13, Ops.gutter, 13),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('$count ${ar ? 'زيارة محددة' : 'visits selected'}',
                        style: const TextStyle(color: Ops.plumTextSoft, fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text('${ar ? 'صافي المهنية' : 'Provider gross'} ${money(providerGrossPiastres, lang)}',
                        style: const TextStyle(color: Ops.plumMuted, fontFamily: Ops.mono, fontSize: 13)),
                    Text(
                        trustFeeExcludedPiastres > 0
                            ? (ar
                                ? 'رسوم الأمان ${money(trustFeeExcludedPiastres, lang)} مستبعدة'
                                : '${money(trustFeeExcludedPiastres, lang)} trust fee excluded')
                            : (ar ? 'رسوم الأمان مستبعدة من الصافي' : 'Trust fee excluded from gross'),
                        style: const TextStyle(color: Color(0xFF9C8898), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              V2Btn(label: ar ? 'مسح' : 'Clear', onPressed: onClear, kind: V2BtnKind.darkGhost, size: V2BtnSize.sm),
              const SizedBox(width: 8),
              V2Btn(
                label: ar ? 'تسوية وإرسال الإيصال' : 'Settle & send receipt',
                onPressed: onSettle,
                kind: V2BtnKind.light,
                size: V2BtnSize.sm,
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
