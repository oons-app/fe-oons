import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';
import 'package:oons/data/api.dart';

class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key, this.queryParams = const {}});
  final Map<String, String> queryParams;

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  List<Map<String, dynamic>> all = [];
  Map<String, dynamic>? sla;
  bool loading = true;
  String? error;
  String filter = ''; // '', 'Vetted', 'Pending review', 'Awaiting docs', 'Suspended'
  String query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    query = widget.queryParams['q'] ?? '';
    final s = widget.queryParams['status'] ?? '';
    if (s == 'pending') filter = 'Pending review';
    _load();
    _loadSla();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await staffClient.get('/admin/providers',
          query: {'limit': 300, if (query.isNotEmpty) 'q': query});
      setState(() {
        all = asMapList(data['providers']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _loadSla() async {
    if (!staffCan(ref.read(staffSessionProvider).effectiveRole, 'providers.vet')) return;
    try {
      final data = await staffClient.get('/admin/vetting-sla');
      setState(() => sla = data);
    } on ApiException catch (_) {}
  }

  Future<void> _reindex() async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'إعادة بناء فهرس البحث؟' : 'Rebuild provider search index?',
      body: lang == 'ar'
          ? 'يشغّل POST /admin/search/reindex. قد يتأخر البحث نحو دقيقة.'
          : 'Runs POST /admin/search/reindex. Search may lag for about a minute.',
      confirmLabel: lang == 'ar' ? 'إعادة الفهرسة' : 'Reindex',
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/search/reindex');
      if (mounted) v2Toast(context, lang == 'ar' ? 'تم وضع إعادة الفهرسة في الطابور' : 'Reindex queued');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _vet(Map p) async {
    final lang = ref.read(localeCodeProvider);
    final name = personName(p, lang, fallbackId: idOf(p));
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'التحقق من $name؟' : 'Vet $name?',
      body: lang == 'ar' ? 'يجعل الملف موثّقاً وقابلاً للحجز.' : 'Marks the profile vetted and makes it bookable.',
      confirmLabel: lang == 'ar' ? 'تحقّق' : 'Vet',
      roleLabel: roleLabel(ref.read(staffSessionProvider).effectiveRole),
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/providers/${idOf(p)}/vet');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم التحقق من $name' : '$name vetted');
        _load();
        _loadSla();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonate(Map p) async {
    final lang = ref.read(localeCodeProvider);
    final id = idOf(p);
    if (id.isEmpty) return;
    try {
      final response = await staffClient.post('/admin/providers/$id/impersonate');
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      final name = personName(p, lang, fallbackId: id);
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(id: id, name: name, token: token, kind: 'provider');
      if (mounted) context.go(V2Paths.impersonateSubject(id, kind: 'provider'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  bool _isSuspended(Map p) =>
      !isZeroTime(p['payoutFrozenAt']) || !isZeroTime(p['suspendedAt']) || '${p['status'] ?? ''}'.toLowerCase() == 'suspended';

  int _countFor(String f) {
    if (f.isEmpty) return all.length;
    if (f == 'Suspended') return all.where(_isSuspended).length;
    return all.where((p) => providerVetting(p, 'en') == f).length;
  }

  List<Map<String, dynamic>> get _rows {
    if (filter.isEmpty) return all;
    if (filter == 'Suspended') return all.where(_isSuspended).toList();
    return all.where((p) => providerVetting(p, 'en') == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'providers.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    final canImpersonate = staffCan(role, 'providers.impersonate');
    final canVet = staffCan(role, 'providers.vet');

    ref.listen(v2QueryProvider, (_, next) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        query = next.trim();
        _load();
      });
    });

    final pending = asMapList(sla?['pending']);
    final backlog = asInt(sla?['count'] ?? pending.length);
    var longestH = 0.0;
    for (final p in pending) {
      final w = asDouble(p['waitHours']);
      if (w > longestH) longestH = w;
    }
    final longest = longestH >= 24 ? '${(longestH / 24).floor()}d' : '${longestH.toStringAsFixed(0)}h';

    final filters = <(String, String)>[
      ('', lang == 'ar' ? 'الكل' : 'All'),
      ('Vetted', lang == 'ar' ? 'موثّقة' : 'Vetted'),
      ('Pending review', lang == 'ar' ? 'بانتظار المراجعة' : 'Pending review'),
      ('Awaiting docs', lang == 'ar' ? 'بانتظار المستندات' : 'Awaiting docs'),
      ('Suspended', lang == 'ar' ? 'موقوفة' : 'Suspended'),
    ];

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          if (sla != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Ops.panelSand,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Ops.panelSandBorder),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lang == 'ar' ? 'مهلة التحقق' : 'Vetting SLA',
                          style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
                      const SizedBox(height: 2),
                      Text(
                        lang == 'ar'
                            ? '$backlog بالانتظار · أطول انتظار $longest'
                            : '$backlog pending · longest wait $longest',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(width: 60),
                  V2Btn.ghost(lang == 'ar' ? 'طابور المهلة' : 'Open SLA queue',
                      onPressed: () => context.go(V2Paths.vetting), size: V2BtnSize.sm),
                  if (canVet)
                    V2Btn.ghost(lang == 'ar' ? 'إعادة فهرسة البحث' : 'Reindex search',
                        onPressed: _reindex, size: V2BtnSize.sm),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in filters)
                V2FilterChip(
                  label: f.$2,
                  count: _countFor(f.$1),
                  selected: filter == f.$1,
                  onTap: () => setState(() => filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${_rows.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
                  style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
            ],
          ),
          const SizedBox(height: 12),
          if (loading && all.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading())
          else if (error != null)
            V2ErrorBanner(message: error!, onRetry: _load)
          else
            V2GridTable(
              actionsWidth: canImpersonate || canVet ? 170 : 70,
              emptyText: lang == 'ar' ? 'لا مهنيات مطابقة' : 'No matching professionals',
              columns: [
                V2Col(lang == 'ar' ? 'المهنية' : 'Professional', flex: 1.05),
                V2Col(lang == 'ar' ? 'الهاتف' : 'Phone', fixed: 130),
                V2Col(lang == 'ar' ? 'الفئة' : 'Category', fixed: 100),
                V2Col(lang == 'ar' ? 'التقييم' : 'Rating', fixed: 78),
                V2Col(lang == 'ar' ? 'التحقق' : 'Vetting', fixed: 128),
                V2Col(lang == 'ar' ? 'الحالة' : 'State', fixed: 108),
              ],
              rows: [
                for (final p in _rows)
                  V2GridRow(
                    onTap: () => context.go(V2Paths.provider(idOf(p))),
                    cells: [
                      _identity(personName(p, lang, fallbackId: idOf(p)), '${p['service'] ?? p['category'] ?? p['vertical'] ?? ''}'),
                      Text('${p['phone'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.ink)),
                      Text('${p['service'] ?? p['category'] ?? p['vertical'] ?? ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
                      Text(asDouble(p['rating']).toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: V2StatusPill(label: providerVetting(p, lang), tone: vettingTone(p)),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: V2StatusPill(label: providerState(p, lang), tone: providerStateTone(p)),
                      ),
                    ],
                    actions: [
                      if (canImpersonate)
                        V2Btn.imp('Impersonate', onPressed: () => _impersonate(p), size: V2BtnSize.row),
                      if (canVet && providerVetting(p, 'en') != 'Vetted')
                        V2Btn(label: lang == 'ar' ? 'تحقّق' : 'Vet', onPressed: () => _vet(p), kind: V2BtnKind.primary, size: V2BtnSize.row),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _identity(String name, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name.isEmpty ? '—' : name,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        if (sub.trim().isNotEmpty)
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Ops.mutedSoft)),
      ],
    );
  }
}
