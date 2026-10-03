import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/tokens.dart';

/// done / verified / active = olive · cancelled / draft = neutral ·
/// pending / needs attention = terracotta.
enum DsTone { olive, neutral, attention }

/// Mono 10.5px bordered status. The colour never carries the meaning alone: the
/// label always says it too.
class DsStatusBadge extends StatelessWidget {
  const DsStatusBadge(this.label, {super.key, this.tone = DsTone.neutral});
  final String label;
  final DsTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      DsTone.olive => (Ds.olive, Ds.cream, Ds.ink),
      DsTone.neutral => (Ds.neutral, Ds.textBody, Ds.divider),
      DsTone.attention => (Ds.terracottaBg, Ds.terracottaText, Ds.terracotta),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: Ds.rule)),
      child: Text(label, style: TextStyle(fontFamily: T.mono, fontSize: 10.5, fontWeight: FontWeight.w600, color: fg, height: 1.3)),
    );
  }
}

/// Small plum-light label (e.g. «باقة» on a visit that belongs to a package).
class DsTag extends StatelessWidget {
  const DsTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        color: Ds.plumLight,
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Ds.plum, height: 1.4)),
      );
}
