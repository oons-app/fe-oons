import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

class ProvidersScreen extends ConsumerStatefulWidget {
  final Map<String, String> queryParams;

  const ProvidersScreen({super.key, this.queryParams = const {}});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  List<Map<String, dynamic>> providers = [];
  Map<String, dynamic>? vettingSla;
  bool loading = true;
  String? error;
  String statusFilter = '';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    statusFilter = widget.queryParams['status'] ?? '';
    searchQuery = widget.queryParams['q'] ?? '';
    _loadProviders();
    _loadVettingSla();
  }

  Future<void> _loadProviders() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final query = <String, dynamic>{};
      if (statusFilter == 'pending') query['vetted'] = '0';
      if (statusFilter == 'active') query['vetted'] = '1';
      if (searchQuery.isNotEmpty) query['q'] = searchQuery;
      final data = await staffClient.get('/admin/providers', query: query);
      var rows = asMapList(data['providers']);
      if (statusFilter == 'suspended') {
        rows = rows.where((p) => !isZeroTime(p['payoutFrozenAt']) || '${p['status']}'.toLowerCase() == 'suspended').toList();
      }
      setState(() {
        providers = rows;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _loadVettingSla() async {
    if (!staffCan(ref.read(staffSessionProvider).effectiveRole, 'providers.vet')) return;
    try {
      final data = await staffClient.get('/admin/vetting-sla');
      setState(() => vettingSla = data);
    } on ApiException catch (_) {}
  }

  Future<void> _reindexSearch() async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post('/admin/search/reindex');
      if (mounted) v2Toast(context, lang == 'ar' ? 'تم إعادة الفهرسة' : 'Search reindexed');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonate(Map<String, dynamic> p) async {
    final lang = ref.read(localeCodeProvider);
    final id = idOf(p);
    if (id.isEmpty) return;
    try {
      final response = await staffClient.post('/admin/providers/$id/impersonate');
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      final name = personName(p, lang, fallbackId: id);
      if (token.isEmpty) {
        if (mounted) v2Toast(context, lang == 'ar' ? 'لا يوجد رمز' : 'No token returned', error: true);
        return;
      }
      ref.read(staffSessionProvider.notifier).startImpersonation(
            id: id,
            name: name,
            token: token,
            kind: 'provider',
          );
      if (mounted) context.go(V2Paths.impersonateSubject(id, kind: 'provider'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'providers.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canImpersonate = staffCan(staffState.effectiveRole, 'providers.impersonate');

    final pending = asMapList(vettingSla?['pending']);
    final backlog = asInt(vettingSla?['count'] ?? pending.length);
    var avgH = 0.0;
    if (pending.isNotEmpty) {
      avgH = pending.map((p) => asDouble(p['waitHours'])).fold<double>(0, (a, b) => a + b) / pending.length;
    }

    return ColoredBox(
      color: Ops.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2PageHeader(
            title: lang == 'ar' ? 'المهنيات' : 'Providers',
            lang: lang,
            resultCount: loading ? null : providers.length,
            actions: [
              if (staffCan(staffState.effectiveRole, 'audit.read'))
                TextButton.icon(
                  onPressed: _reindexSearch,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(lang == 'ar' ? 'إعادة الفهرسة' : 'Reindex'),
                ),
            ],
            filters: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vettingSla != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Ops.goldTint,
                      borderRadius: BorderRadius.circular(Ops.radiusCtl),
                      border: Border.all(color: Ops.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, size: 16, color: Ops.goldInk),
                        const SizedBox(width: 8),
                        Text(
                          '${lang == 'ar' ? 'متوسط الانتظار:' : 'Avg wait:'} ${avgH.toStringAsFixed(0)}h',
                          style: const TextStyle(fontSize: 12, color: Ops.goldInk, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '$backlog ${lang == 'ar' ? 'معلقة' : 'pending'}',
                          style: const TextStyle(fontSize: 12, color: Ops.goldInk, fontFamily: Ops.mono),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  onChanged: (q) {
                    searchQuery = q;
                    _loadProviders();
                  },
                  decoration: InputDecoration(
                    hintText: lang == 'ar' ? 'بحث في المهنيات...' : 'Search providers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Ops.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ops.radiusCtl)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in [
                      ('pending', lang == 'ar' ? 'معلقة' : 'Pending'),
                      ('active', lang == 'ar' ? 'نشطة' : 'Active'),
                      ('suspended', lang == 'ar' ? 'موقوفة' : 'Suspended'),
                    ])
                      V2FilterChip(
                        label: f.$2,
                        selected: statusFilter == f.$1,
                        onTap: () {
                          setState(() => statusFilter = statusFilter == f.$1 ? '' : f.$1);
                          _loadProviders();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const V2Loading()
                : error != null
                    ? Center(child: V2ErrorBanner(message: error!, onRetry: _loadProviders))
                    : providers.isEmpty
                        ? const V2Empty()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              V2Card(
                                padding: EdgeInsets.zero,
                                child: V2DataTable(
                                  headers: [
                                    lang == 'ar' ? 'المهنية' : 'Professional',
                                    lang == 'ar' ? 'الهاتف' : 'Phone',
                                    lang == 'ar' ? 'الخدمات' : 'Services',
                                    lang == 'ar' ? 'المناطق' : 'Areas',
                                    lang == 'ar' ? 'التقييم' : 'Rating',
                                    lang == 'ar' ? 'التحقق' : 'Vetting',
                                    lang == 'ar' ? 'الحالة' : 'State',
                                    lang == 'ar' ? 'التقديم' : 'Applied',
                                    if (canImpersonate) lang == 'ar' ? 'إجراءات' : 'Actions',
                                  ],
                                  rows: [
                                    for (final p in providers)
                                      [
                                        identityCell(personName(p, lang, fallbackId: idOf(p)), shortId(idOf(p))),
                                        Text('${p['phone'] ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: Ops.mono)),
                                        Text('${serviceCountOf(p)}', style: const TextStyle(fontFamily: Ops.mono)),
                                        Text('${areaCountOf(p)}', style: const TextStyle(fontFamily: Ops.mono)),
                                        Text(asDouble(p['rating']).toStringAsFixed(1), style: const TextStyle(fontFamily: Ops.mono)),
                                        V2StatusPill(label: providerVetting(p, lang), tone: vettingTone(p)),
                                        V2StatusPill(label: providerState(p, lang), tone: providerStateTone(p)),
                                        Text(formatDay(p['createdAt'] ?? p['consentedAt'], lang),
                                            style: const TextStyle(fontSize: 12, color: Ops.muted)),
                                        if (canImpersonate)
                                          IconButton(
                                            tooltip: lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate',
                                            onPressed: () => _impersonate(p),
                                            icon: const Icon(Icons.login, size: 18),
                                          ),
                                      ],
                                  ],
                                  onRowTap: (i) => context.go(V2Paths.provider(idOf(providers[i]))),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
