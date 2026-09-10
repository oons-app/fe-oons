import 'package:flutter/material.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';

enum V2Tone { ok, warn, bad, info, plum, neutral }

(Color, Color) v2ToneColors(V2Tone tone) => switch (tone) {
      V2Tone.ok => (Ops.greenTint, Ops.greenInk),
      V2Tone.warn => (Ops.goldTint, Ops.goldInk),
      V2Tone.bad => (Ops.terracottaTint, Ops.terracottaInk),
      V2Tone.info => (Ops.blueTint, Ops.blueInk),
      V2Tone.plum => (Ops.plumChip, Ops.plumChipInk),
      V2Tone.neutral => (Ops.greyTint, Ops.greyInk),
    };

/// Prototype `TONE_OF` — maps a human status label to its chip tone.
V2Tone toneForLabel(String label) {
  switch (label.trim().toLowerCase()) {
    case 'completed':
    case 'vetted':
    case 'active':
    case 'paid':
    case 'approved':
    case 'accepted':
    case 'open':
    case 'healthy':
    case 'live':
    case 'released':
      return V2Tone.ok;
    case 'in progress':
    case 'on the way':
    case 'arrived':
    case 'confirmed':
    case 'owner':
    case 'admin':
    case 'balanced':
      return V2Tone.plum;
    case 'pending payment':
    case 'pending review':
    case 'pending':
    case 'awaiting docs':
    case 'requested':
    case 'held':
    case 'on hold':
    case 'tight':
    case 'simulate':
    case 'support':
      return V2Tone.warn;
    case 'cancelled by client':
    case 'cancelled':
    case 'rejected':
    case 'suspended':
    case 'disputed':
    case 'missing':
    case 'failed':
    case 'escalated':
    case 'undersupplied':
    case 'locked':
      return V2Tone.bad;
    case 'inactive':
    case 'draft':
    case 'closed':
    case 'settled':
      return V2Tone.neutral;
    case 'refunded':
    case 'split':
    case 'finance':
      return V2Tone.info;
    default:
      return V2Tone.neutral;
  }
}

class V2StatusPill extends StatelessWidget {
  const V2StatusPill({super.key, required this.label, this.tone = V2Tone.neutral, this.large = false});

  /// Tone inferred from the label text, matching the prototype's `chipFor`.
  V2StatusPill.forLabel(this.label, {super.key, this.large = false}) : tone = toneForLabel(label);

  final String label;
  final V2Tone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = v2ToneColors(tone);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: large ? 12 : 10, vertical: large ? 5 : 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Ops.radiusPill)),
      child: Text(label,
          style: TextStyle(fontSize: large ? 12.5 : 11.5, fontWeight: FontWeight.w600, color: fg, fontFamily: Ops.sans)),
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
  const V2FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Ops.plum : Ops.card,
      borderRadius: BorderRadius.circular(Ops.radiusBtn),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ops.radiusBtn),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ops.radiusBtn),
            border: Border.all(color: selected ? Ops.plum : Ops.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFFF6F0EF) : Ops.plumInk,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0x2EFFFFFF) : const Color(0xFFEFE8DD),
                    borderRadius: BorderRadius.circular(Ops.radiusPill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: Ops.mono,
                      color: selected ? const Color(0xFFF6F0EF) : const Color(0xFF6B5D69),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded on/off toggle (`pill` in the prototype).
class V2Pill extends StatelessWidget {
  const V2Pill({super.key, required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? Ops.plum : Ops.cardAlt,
      borderRadius: BorderRadius.circular(Ops.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ops.radiusPill),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ops.radiusPill),
            border: Border.all(color: on ? Ops.plum : Ops.borderStrong),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? const Color(0xFFF6F0EF) : Ops.plumInk)),
        ),
      ),
    );
  }
}

/// Underline tab row (`tabBtn` in the prototype).
class V2TabBar extends StatelessWidget {
  const V2TabBar({super.key, required this.tabs, required this.active, required this.onSelect});
  final List<String> tabs;
  final String active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.border))),
      child: Wrap(
        spacing: 4,
        children: [
          for (final tab in tabs)
            InkWell(
              onTap: () => onSelect(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab == active ? Ops.plum : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tab == active ? FontWeight.w700 : FontWeight.w500,
                    color: tab == active ? Ops.plum : Ops.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card with a bold 14.5px title row and optional trailing widgets.
class V2SectionCard extends StatelessWidget {
  const V2SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(17),
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Ops.card,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        border: Border.all(color: Ops.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Ops.ink)),
              ),
              if (trailing != null) ...trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 12, color: Ops.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// "Needs your attention" count card from the home screen.
class V2AttentionCard extends StatelessWidget {
  const V2AttentionCard({
    super.key,
    required this.label,
    required this.count,
    required this.unit,
    required this.hint,
    required this.onTap,
  });
  final String label;
  final int count;
  final String unit;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needsAction = count > 0;
    return Material(
      color: Ops.card,
      borderRadius: BorderRadius.circular(Ops.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ops.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Ops.radiusCard),
            border: Border(
              top: BorderSide(color: needsAction ? const Color(0xFFE0C9A8) : Ops.border),
              right: BorderSide(color: needsAction ? const Color(0xFFE0C9A8) : Ops.border),
              bottom: BorderSide(color: needsAction ? const Color(0xFFE0C9A8) : Ops.border),
              left: BorderSide(color: needsAction ? Ops.terracotta : Ops.border, width: needsAction ? 3 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Ops.ink)),
                  ),
                  const SizedBox(width: 8),
                  V2StatusPill(label: needsAction ? 'Needs action' : 'Clear', tone: needsAction ? V2Tone.warn : V2Tone.ok),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$count',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 0.9, fontFamily: Ops.mono)),
                  const SizedBox(width: 8),
                  Text(unit, style: const TextStyle(fontSize: 12, color: Ops.muted)),
                ],
              ),
              const SizedBox(height: 11),
              Text('$hint →', style: const TextStyle(fontSize: 12, color: Color(0xFF6B5D69))),
            ],
          ),
        ),
      ),
    );
  }
}

/// label / progress track / value row used across home, heatmap and vetting.
class V2MiniBar extends StatelessWidget {
  const V2MiniBar({
    super.key,
    required this.label,
    required this.fraction,
    required this.value,
    this.color = Ops.barConfirmed,
    this.labelWidth = 112,
  });
  final String label;
  final double fraction;
  final String value;
  final Color color;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Ops.radiusPill),
              child: Container(
                height: 9,
                color: Ops.track,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction.clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Ops.radiusPill)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.muted)),
          ),
        ],
      ),
    );
  }
}

/// A compact KPI cell for the 2-column overview grid (thin dividers, mono value).
class V2KpiCell extends StatelessWidget {
  const V2KpiCell({super.key, required this.label, required this.value, this.note});
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Ops.cardAlt,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Ops.muted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, fontFamily: Ops.mono, height: 1)),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(note!, style: const TextStyle(fontSize: 11, color: Ops.faint)),
          ],
        ],
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
