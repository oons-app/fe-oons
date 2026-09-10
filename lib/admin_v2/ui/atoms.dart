import 'package:flutter/material.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

enum V2Tone { ok, warn, bad, info, plum, neutral }

class V2StatusPill extends StatelessWidget {
  const V2StatusPill({super.key, required this.label, this.tone = V2Tone.neutral});
  final String label;
  final V2Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      V2Tone.ok => (Ops.greenTint, Ops.greenInk),
      V2Tone.warn => (Ops.goldTint, Ops.goldInk),
      V2Tone.bad => (Ops.terracottaTint, Ops.terracottaInk),
      V2Tone.info => (Ops.blueTint, Ops.blueInk),
      V2Tone.plum => (const Color(0xFFEFE4EC), const Color(0xFF5A3552)),
      V2Tone.neutral => (Ops.greyTint, Ops.greyInk),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Ops.radiusPill)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class V2KpiTile extends StatelessWidget {
  const V2KpiTile({super.key, required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ops.card,
      borderRadius: BorderRadius.circular(Ops.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ops.radiusCard),
            border: Border.all(color: Ops.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFamily: Ops.mono, height: 0.95)),
            ],
          ),
        ),
      ),
    );
  }
}

class V2Card extends StatelessWidget {
  const V2Card({super.key, required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(Ops.radiusCard), child: body),
    );
  }
}

class V2Loading extends StatelessWidget {
  const V2Loading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.2, color: Ops.plum)),
          const SizedBox(height: 12),
          Text(label ?? t(V2Copy.loading, lang), style: const TextStyle(color: Ops.muted)),
        ],
      ),
    );
  }
}

class V2ErrorBanner extends StatelessWidget {
  const V2ErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Ops.terracottaTint,
        borderRadius: BorderRadius.circular(Ops.radiusCtl),
        border: Border.all(color: Ops.terracotta.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: const TextStyle(color: Ops.terracottaInk, fontSize: 13))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(t(V2Copy.retry, lang))),
        ],
      ),
    );
  }
}

class V2Empty extends StatelessWidget {
  const V2Empty({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Center(
      child: Text(message ?? t(V2Copy.empty, lang), style: const TextStyle(color: Ops.muted, fontSize: 14)),
    );
  }
}

class V2DataTable extends StatelessWidget {
  const V2DataTable({
    super.key,
    required this.headers,
    required this.rows,
    this.onRowTap,
    this.leading,
    this.minWidth = 900,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final Widget Function(int index)? leading;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth < minWidth ? minWidth : c.maxWidth),
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Ops.cardAlt),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 64,
                headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Ops.muted),
                columns: [
                  if (leading != null) const DataColumn(label: SizedBox(width: 36)),
                  for (final h in headers) DataColumn(label: Text(h)),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      onSelectChanged: onRowTap == null ? null : (_) => onRowTap!(i),
                      cells: [
                        if (leading != null) DataCell(leading!(i)),
                        for (final cell in rows[i]) DataCell(cell),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class V2FilterChip extends StatelessWidget {
  const V2FilterChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Ops.plum : Ops.card,
      borderRadius: BorderRadius.circular(Ops.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ops.radiusPill),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ops.radiusPill),
            border: Border.all(color: selected ? Ops.plum : Ops.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Ops.plumText : Ops.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class V2Gate extends StatelessWidget {
  const V2Gate({super.key, required this.allowed, required this.child});
  final bool allowed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    final lang = Localizations.localeOf(context).languageCode;
    return Center(
      child: Text(
        lang == 'ar' ? 'ليس لديك صلاحية لهذه الشاشة.' : 'You do not have access to this screen.',
        style: const TextStyle(color: Ops.muted),
      ),
    );
  }
}

class V2PageHeader extends StatelessWidget {
  const V2PageHeader({
    super.key,
    required this.title,
    this.filters,
    this.actions,
    this.resultCount,
    this.lang = 'en',
  });

  final String title;
  final Widget? filters;
  final List<Widget>? actions;
  final int? resultCount;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Ops.ink)),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          if (filters != null) ...[
            const SizedBox(height: 12),
            filters!,
          ],
          if (resultCount != null) ...[
            const SizedBox(height: 10),
            Text(
              lang == 'ar' ? '$resultCount نتيجة' : '$resultCount results',
              style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono),
            ),
          ],
        ],
      ),
    );
  }
}

class V2FactRow extends StatelessWidget {
  const V2FactRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, color: Ops.ink))),
        ],
      ),
    );
  }
}
