import 'package:flutter/material.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';

/// Standard "generic table" screen body from `Oons Ops Console v2.html`:
/// an optional strip, a filter-chip row, a result-count + actions toolbar,
/// and the V2GridTable with loading / error / empty handling.
class V2ListView extends StatelessWidget {
  const V2ListView({
    super.key,
    required this.columns,
    required this.rows,
    required this.resultLabel,
    this.loading = false,
    this.error,
    this.onRetry,
    this.strip,
    this.filters = const [],
    this.trailingActions = const [],
    this.emptyText,
    this.actionsWidth = 120,
    this.bulkMode = false,
  });

  final Widget? strip;
  final List<Widget> filters;
  final List<Widget> trailingActions;
  final String resultLabel;
  final List<V2Col> columns;
  final List<V2GridRow> rows;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String? emptyText;
  final double actionsWidth;
  final bool bulkMode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          if (strip != null) ...[strip!, const SizedBox(height: 16)],
          if (filters.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: filters),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Text(resultLabel, style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
              const Spacer(),
              for (var i = 0; i < trailingActions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                trailingActions[i],
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (loading && rows.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading())
          else if (error != null)
            V2ErrorBanner(message: error!, onRetry: onRetry)
          else
            V2GridTable(
              columns: columns,
              rows: rows,
              bulkMode: bulkMode,
              actionsWidth: actionsWidth,
              emptyText: emptyText,
            ),
        ],
      ),
    );
  }
}
