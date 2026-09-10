import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? homeData;
  List<Map<String, dynamic>> topUndersupplied = [];
  bool loading = true;
  String? error;
  String selectedRange = '7';

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final days = int.tryParse(selectedRange) ?? 7;
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
      final to = DateTime(now.year, now.month, now.day);
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final data = await staffClient.get('/admin/home', query: {
        'from': ymd(from),
        'to': ymd(to),
      });
      List<Map<String, dynamic>> under = asMapList(data['topUndersupplied']);
      if (under.isEmpty) {
        try {
          final heat = await staffClient.get('/admin/heatmap');
          under = asMapList(heat['topUndersupplied']);
        } on ApiException catch (_) {}
      }
      setState(() {
        homeData = data;
        topUndersupplied = under;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _reindex() async {
    final confirmed = await v2Confirm(
      context,
      title: 'Reindex search',
      body: 'This will update the search index. It may take a few minutes.',
      confirmLabel: 'Reindex',
    );
    if (!confirmed) return;

    try {
      await staffClient.post('/admin/search/reindex');
      if (mounted) v2Toast(context, 'Search reindex started');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  void _onKpiTap(String type) {
    switch (type) {
      case 'bookings':
        context.go('${V2Paths.bookings}?status=pending');
        break;
      case 'claims':
        context.go(V2Paths.claims);
        break;
      case 'providers':
        context.go('${V2Paths.providers}?status=pending');
        break;
      case 'vetting':
        context.go(V2Paths.vetting);
        break;
    }
  }

  void _onRangeChange(String range) {
    setState(() => selectedRange = range);
    _loadHome();
  }

  Widget _buildBookingChart(Map<String, dynamic> data, String lang) {
    final byStatus = (data['bookingsByStatus'] as List?) ?? const [];
    final counts = <String, int>{};
    for (final row in byStatus) {
      if (row is! Map) continue;
      final s = '${row['status'] ?? ''}'.toLowerCase();
      final n = asInt(row['count']);
      if (s.contains('pending')) {
        counts['pending'] = (counts['pending'] ?? 0) + n;
      } else if (s.contains('paid') || s.contains('on_the_way') || s.contains('confirmed')) {
        counts['confirmed'] = (counts['confirmed'] ?? 0) + n;
      } else if (s.contains('completed') || s.contains('released')) {
        counts['completed'] = (counts['completed'] ?? 0) + n;
      } else if (s.contains('cancel')) {
        counts['cancelled'] = (counts['cancelled'] ?? 0) + n;
      }
    }
    final pending = counts['pending'] ?? asInt(data['bookingsToday']);
    final confirmed = counts['confirmed'] ?? 0;
    final completed = counts['completed'] ?? 0;
    final cancelled = counts['cancelled'] ?? 0;
    final total = pending + confirmed + completed + cancelled;

    if (total == 0) {
      return Center(
        child: Text(
          lang == 'ar' ? 'لا توجد بيانات للعرض' : 'No data to display',
          style: const TextStyle(color: Ops.muted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'ar' ? 'توزيع الحجوزات' : 'Bookings Distribution',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (pending > 0) ...[
                  Expanded(
                    flex: pending,
                    child: Container(
                      height: (pending / total * 120).clamp(20, 120),
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: Ops.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
                if (confirmed > 0) ...[
                  Expanded(
                    flex: confirmed,
                    child: Container(
                      height: (confirmed / total * 120).clamp(20, 120),
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: Ops.plum,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
                if (completed > 0) ...[
                  Expanded(
                    flex: completed,
                    child: Container(
                      height: (completed / total * 120).clamp(20, 120),
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: Ops.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
                if (cancelled > 0) ...[
                  Expanded(
                    flex: cancelled,
                    child: Container(
                      height: (cancelled / total * 120).clamp(20, 120),
                      margin: const EdgeInsetsDirectional.only(end: 4),
                      decoration: BoxDecoration(
                        color: Ops.terracotta,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (pending > 0)
                _buildLegendItem(
                  lang == 'ar' ? 'معلقة' : 'Pending',
                  '$pending',
                  Ops.gold,
                ),
              if (confirmed > 0)
                _buildLegendItem(
                  lang == 'ar' ? 'مؤكدة' : 'Confirmed',
                  '$confirmed',
                  Ops.plum,
                ),
              if (completed > 0)
                _buildLegendItem(
                  lang == 'ar' ? 'مكتملة' : 'Completed',
                  '$completed',
                  Ops.green,
                ),
              if (cancelled > 0)
                _buildLegendItem(
                  lang == 'ar' ? 'ملغاة' : 'Cancelled',
                  '$cancelled',
                  Ops.terracotta,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12, color: Ops.ink),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);

    if (!staffCan(staffState.effectiveRole, 'home.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    if (loading) return const V2Loading();

    if (error != null) {
      return Center(
        child: V2ErrorBanner(
          message: error!,
          onRetry: _loadHome,
        ),
      );
    }

    final data = homeData ?? {};
    final kpis = data['kpis'] as Map<String, dynamic>? ?? {};
    final pendingBookings = asInt(kpis['pendingBookings'] ?? data['bookingsToday']);
    final openClaims = asInt(kpis['openClaims'] ?? data['openDisputes']);
    final pendingProviders = asInt(kpis['pendingProviders'] ?? data['pendingProviders']);
    final vettingBacklog = asInt(kpis['vettingBacklog'] ?? data['pendingProviders']);
    final attention = (data['attention'] as List?) ?? [
      if (pendingProviders > 0)
        {
          'type': 'providers',
          'filter': 'status=pending',
          'title': {'en': '$pendingProviders providers awaiting review', 'ar': '$pendingProviders مهنية بانتظار المراجعة'},
        },
      if (asInt(data['pendingPayouts']) > 0)
        {
          'type': 'bookings',
          'filter': 'unpaidOps=1',
          'title': {
            'en': '${data['pendingPayouts']} withdrawals awaiting approval',
            'ar': '${data['pendingPayouts']} سحب بانتظار الموافقة',
          },
        },
      if (openClaims > 0)
        {
          'type': 'bookings',
          'filter': 'status=disputed',
          'title': {'en': '$openClaims open disputes', 'ar': '$openClaims نزاع مفتوح'},
        },
    ];

    return Scaffold(
      backgroundColor: Ops.page,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  lang == 'ar' ? 'لوحة التشغيل' : 'Ops Console',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Ops.ink),
                ),
                const Spacer(),
                if (staffCan(staffState.effectiveRole, 'audit.read'))
                  ElevatedButton.icon(
                    onPressed: _reindex,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(lang == 'ar' ? 'إعادة فهرسة البحث' : 'Reindex search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Ops.plum,
                      foregroundColor: Ops.plumText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            if (topUndersupplied.isNotEmpty && canSeeScreen(staffState.effectiveRole, 'heatmap')) ...[
              Material(
                color: Ops.terracottaTint,
                borderRadius: BorderRadius.circular(Ops.radiusCtl),
                child: InkWell(
                  onTap: () => context.go(V2Paths.heatmap),
                  borderRadius: BorderRadius.circular(Ops.radiusCtl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Ops.radiusCtl),
                      border: Border.all(color: Ops.terracotta.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 18, color: Ops.terracottaInk),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang == 'ar' ? 'مناطق بنقص عرض' : 'Top undersupplied areas',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Ops.terracottaInk),
                              ),
                            ),
                            Text(
                              lang == 'ar' ? 'الخريطة الحرارية' : 'Heatmap',
                              style: const TextStyle(fontSize: 12, color: Ops.terracottaInk, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cell in topUndersupplied.take(5))
                              V2StatusPill(
                                label:
                                    '${areaName('${cell['area'] ?? ''}', lang)} · ${((asDouble(cell['fillRate'])) * 100).toStringAsFixed(0)}%',
                                tone: V2Tone.bad,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // KPI tiles
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                V2KpiTile(
                  label: lang == 'ar' ? 'حجوزات اليوم' : 'Bookings today',
                  value: '$pendingBookings',
                  onTap: () => _onKpiTap('bookings'),
                ),
                V2KpiTile(
                  label: lang == 'ar' ? 'نزاعات مفتوحة' : 'Open disputes',
                  value: '$openClaims',
                  onTap: () => _onKpiTap('claims'),
                ),
                V2KpiTile(
                  label: lang == 'ar' ? 'مهنيات معلقات' : 'Pending providers',
                  value: '$pendingProviders',
                  onTap: () => _onKpiTap('providers'),
                ),
                V2KpiTile(
                  label: lang == 'ar' ? 'متأخرات التحقق' : 'Vetting backlog',
                  value: '$vettingBacklog',
                  onTap: () => _onKpiTap('vetting'),
                ),
              ],
            ),

            if (attention.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                lang == 'ar' ? 'يتطلب انتباه' : 'Needs attention',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Ops.ink),
              ),
              const SizedBox(height: 16),
              ...attention.map<Widget>((item) {
                final itemMap = item as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: V2Card(
                    onTap: () {
                      final type = itemMap['type'] as String?;
                      final filter = itemMap['filter'] as String?;
                      if (type == 'bookings' && filter != null) {
                        context.go('${V2Paths.bookings}?$filter');
                      } else if (type == 'providers' && filter != null) {
                        context.go('${V2Paths.providers}?$filter');
                      }
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Ops.terracotta,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locName(itemMap['title'], lang),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ops.ink),
                              ),
                              if (itemMap['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  locName(itemMap['description'], lang),
                                  style: const TextStyle(fontSize: 12, color: Ops.muted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Ops.muted, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: 32),
            // Bookings chart section
            Text(
              lang == 'ar' ? 'الحجوزات' : 'Bookings',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Ops.ink),
            ),
            const SizedBox(height: 16),

            // Range chips
            Row(
              children: [
                V2FilterChip(
                  label: '7d',
                  selected: selectedRange == '7',
                  onTap: () => _onRangeChange('7'),
                ),
                const SizedBox(width: 8),
                V2FilterChip(
                  label: '14d',
                  selected: selectedRange == '14',
                  onTap: () => _onRangeChange('14'),
                ),
                const SizedBox(width: 8),
                V2FilterChip(
                  label: '30d',
                  selected: selectedRange == '30',
                  onTap: () => _onRangeChange('30'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Simple booking stats bar chart
            V2Card(
              child: SizedBox(
                height: 200,
                child: _buildBookingChart(data, lang),
              ),
            ),

            const SizedBox(height: 32),
            // Quick links
            Row(
              children: [
                if (canSeeScreen(staffState.effectiveRole, 'heatmap'))
                  Expanded(
                    child: V2Card(
                      onTap: () => context.go(V2Paths.heatmap),
                      child: Column(
                        children: [
                          const Icon(Icons.map, size: 32, color: Ops.plum),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'ar' ? 'الخريطة الحرارية' : 'Heatmap',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ops.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canSeeScreen(staffState.effectiveRole, 'vetting') && canSeeScreen(staffState.effectiveRole, 'heatmap'))
                  const SizedBox(width: 16),
                if (canSeeScreen(staffState.effectiveRole, 'vetting'))
                  Expanded(
                    child: V2Card(
                      onTap: () => context.go(V2Paths.vetting),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_user, size: 32, color: Ops.plum),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'ar' ? 'مهلة التحقق' : 'Vetting SLA',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ops.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}