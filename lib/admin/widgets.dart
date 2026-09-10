import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin/shell.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/glyphs.dart';

void adminSnack(BuildContext context, String msg, {bool error = false}) {
  // Design-faithful toast chrome (see overlays.dart).
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
              color: error ? T.warm : const Color(0xFF8DBF8D),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(msg, style: const TextStyle(color: Color(0xFFF1E8EE), fontSize: 12.5, height: 1.35)),
          ),
        ],
      ),
      backgroundColor: error ? T.warmInk : T.action,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      duration: const Duration(milliseconds: 2600),
      elevation: 0,
    ),
  );
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onRefresh,
    this.busy = false,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final bool busy;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // Title lives in the shell top bar — keep this for detail actions only.
    if (onBack == null && actions.isEmpty && onRefresh == null && (subtitle == null || subtitle!.isEmpty)) {
      return const SizedBox(height: 4);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Glyph(GlyphKind.back, size: 20, color: T.ink),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: T.ink)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: T.muted, fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
          ...actions,
          if (onRefresh != null)
            IconButton(
              tooltip: 'Refresh',
              onPressed: busy ? null : onRefresh,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: T.muted))
                  : const Icon(Icons.refresh, size: 20, color: T.ink),
            ),
        ],
      ),
    );
  }
}

class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusLg),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.ink))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow({super.key, required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: T.muted, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: T.ink, fontFamily: mono ? T.mono : null))),
        ],
      ),
    );
  }
}

class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({super.key, required this.label, this.tone = AdminTone.neutral});
  final String label;
  final AdminTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      AdminTone.ok => T.trustTint,
      AdminTone.warn => T.pendingTint,
      AdminTone.bad => T.warmTint,
      AdminTone.neutral => T.sand,
      AdminTone.info => T.blueTint,
      AdminTone.plum => T.plumTint,
    };
    final fg = switch (tone) {
      AdminTone.ok => T.trustInk,
      AdminTone.warn => T.pendingInk,
      AdminTone.bad => T.warmInk,
      AdminTone.neutral => const Color(0xFF5F5560),
      AdminTone.info => T.blueInk,
      AdminTone.plum => T.plumInk,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

enum AdminTone { ok, warn, bad, neutral, info, plum }

class AdminAttentionCard extends StatelessWidget {
  const AdminAttentionCard({
    super.key,
    required this.label,
    required this.count,
    required this.unit,
    required this.state,
    required this.hint,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final String count;
  final String unit;
  final String state;
  final String hint;
  final AdminTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needs = int.tryParse(count) != null && (int.tryParse(count) ?? 0) > 0;
    return Material(
      color: T.surface,
      borderRadius: BorderRadius.circular(T.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.radiusLg),
          child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.radiusLg),
            border: Border.all(color: needs ? const Color(0xFFE0C9A8) : T.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (needs)
                  Container(
                    width: 3,
                    margin: const EdgeInsetsDirectional.only(end: 14),
                    decoration: BoxDecoration(color: T.warm, borderRadius: BorderRadius.circular(2)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.ink))),
                          AdminStatusPill(label: state, tone: tone),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: T.ink, height: 1)),
                          const SizedBox(width: 8),
                          Text(unit, style: const TextStyle(fontSize: 13, color: T.muted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(hint, style: const TextStyle(fontSize: 13, color: T.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({super.key, required this.label, required this.value, this.note});
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radiusLg),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: T.ink)),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note!, style: const TextStyle(fontSize: 12, color: T.mutedSoft)),
          ],
        ],
      ),
    );
  }
}

class AdminPhotoBlock extends StatefulWidget {
  const AdminPhotoBlock({super.key, required this.label, required this.url, required this.loader});
  final String label;
  final String url;
  final Future<Uint8List?> Function(String url) loader;

  @override
  State<AdminPhotoBlock> createState() => _AdminPhotoBlockState();
}

class _AdminPhotoBlockState extends State<AdminPhotoBlock> {
  Uint8List? bytes;
  bool busy = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminPhotoBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      setState(() {
        bytes = null;
        busy = false;
        failed = false;
      });
      return;
    }
    setState(() {
      busy = true;
      failed = false;
    });
    final data = await widget.loader(widget.url);
    if (!mounted) return;
    setState(() {
      bytes = data;
      busy = false;
      failed = data == null;
    });
  }

  bool get _isPdf => widget.url.toLowerCase().contains('.pdf');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: T.ink)),
        const SizedBox(height: 8),
        if (busy)
          const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: T.action)))
        else if (bytes != null && !_isPdf)
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => Dialog(
                child: InteractiveViewer(child: Image.memory(bytes!, fit: BoxFit.contain)),
              ),
            ),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                bytes!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(child: Text('—', style: TextStyle(color: T.muted))),
              ),
            ),
          )
        else if (bytes != null && _isPdf)
          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF1EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9BFB4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: T.action),
                SizedBox(width: 8),
                Text('PDF on file', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          )
        else
          Container(
            height: 150,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF1EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9BFB4), style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(failed ? 'Couldn’t load preview' : '—', style: const TextStyle(color: T.muted)),
                if (failed && widget.url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key, this.label = '…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2, color: T.action),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: T.muted)),
        ],
      ),
    );
  }
}

class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.warmTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0C9A8)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: const TextStyle(color: T.warmInk, fontSize: 13))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: T.warmInk, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class AdminDetailScaffold extends StatelessWidget {
  const AdminDetailScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.onRefresh,
    this.busy = false,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onRefresh;
  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: adminPagePad(context),
      children: [
        AdminPageHeader(
          title: title,
          subtitle: subtitle,
          onBack: () => context.pop(),
          onRefresh: onRefresh,
          busy: busy,
        ),
        child,
      ],
    );
  }
}

class AdminQuickLinks extends StatelessWidget {
  const AdminQuickLinks({super.key, required this.items});
  final List<({String label, String path})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Material(
            color: T.plumTint,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => context.go(item.path),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: T.plumInk)),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? T.action : T.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? T.action : T.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFFF6F0EF) : T.body,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.18) : T.sand,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    count!,
                    style: TextStyle(
                      fontFamily: T.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

String adminFormatAddress(Map addr, String lang) {
  final line1 = addr['line1'] is Map ? Loc.fromJson(addr['line1'] as Map).of(lang) : '${addr['line'] ?? ''}';
  final city = addr['city'] is Map ? Loc.fromJson(addr['city'] as Map).of(lang) : '${addr['city'] ?? ''}';
  final reach = addr['reachNotes'] is Map ? Loc.fromJson(addr['reachNotes'] as Map).of(lang) : '';
  final parts = <String>[
    if (line1.isNotEmpty) line1,
    if (addr['area'] != null && '${addr['area']}'.isNotEmpty) areaName('${addr['area']}', lang),
    if (city.isNotEmpty) city,
  ];
  final base = parts.where((s) => s.isNotEmpty).join(' · ');
  if (reach.trim().isEmpty) return base;
  return base.isEmpty ? reach : '$base\n$reach';
}

class AdminAddressTile extends StatelessWidget {
  const AdminAddressTile({super.key, required this.addr, required this.lang, required this.labels});
  final Map addr;
  final String lang;
  final Map labels;

  @override
  Widget build(BuildContext context) {
    final label = addr['label'] is Map ? Loc.fromJson(addr['label'] as Map).of(lang) : '${addr['label'] ?? ''}';
    final line1 = addr['line1'] is Map ? Loc.fromJson(addr['line1'] as Map).of(lang) : '${addr['line'] ?? ''}';
    final city = addr['city'] is Map ? Loc.fromJson(addr['city'] as Map).of(lang) : '${addr['city'] ?? ''}';
    final reach = addr['reachNotes'] is Map ? Loc.fromJson(addr['reachNotes'] as Map).of(lang) : '';
    final lat = (addr['lat'] as num?)?.toDouble() ?? 0;
    final lng = (addr['lng'] as num?)?.toDouble() ?? 0;
    final isDefault = addr['isDefault'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: T.line),
        color: T.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: T.ink))),
                if (isDefault) AdminStatusPill(label: '${labels['defaultAddr']}', tone: AdminTone.ok),
              ],
            ),
          if (line1.isNotEmpty) ...[const SizedBox(height: 6), Text(line1, style: const TextStyle(fontSize: 13, height: 1.4, color: T.ink))],
          if (city.isNotEmpty || '${addr['area'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [if (city.isNotEmpty) city, if ('${addr['area'] ?? ''}'.isNotEmpty) areaName('${addr['area']}', lang)].join(' · '),
                style: const TextStyle(fontSize: 12, color: T.muted),
              ),
            ),
          if (reach.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${labels['reachNotes']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.muted)),
            Text(reach, style: const TextStyle(fontSize: 13, height: 1.45, color: T.ink)),
          ],
          if (lat != 0 || lng != 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${labels['coordinates']}: $lat, $lng', style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: T.muted)),
            ),
        ],
      ),
    );
  }
}

class AdminInstructionTile extends StatelessWidget {
  const AdminInstructionTile({super.key, required this.item});
  final Map item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: T.line),
        color: T.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ('${item['title'] ?? ''}'.isNotEmpty) Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: T.ink)),
          if ('${item['body'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${item['body']}', style: const TextStyle(fontSize: 13, height: 1.45, color: T.ink)),
          ],
        ],
      ),
    );
  }
}
