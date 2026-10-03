import 'package:flutter/material.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/ds/primitives/button.dart';
import 'package:oons/ds/tokens.dart';

/// Cream bottom sheet with an ink top border, a title and a close (×) button,
/// over an ink 42% scrim. Content scrolls; the keyboard never covers it.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Ds.cream,
    barrierColor: Ds.scrim,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    builder: (ctx) => DsSheetFrame(title: title, child: builder(ctx)),
  );
}

class DsSheetFrame extends StatelessWidget {
  const DsSheetFrame({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ar = dsIsAr(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: const BoxDecoration(color: Ds.cream, border: Border(top: BorderSide(color: Ds.ink, width: Ds.rule))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Ds.gutter, Ds.s2, Ds.s2, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title ?? '', style: DsText.section)),
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: Ds.minTarget,
                      height: Ds.minTarget,
                      child: Center(child: OnsIconOnly('close', semanticLabel: ar ? 'إغلاق' : 'Close', size: 22, color: Ds.ink)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Ds.gutter, Ds.s2, Ds.gutter, Ds.s5),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
