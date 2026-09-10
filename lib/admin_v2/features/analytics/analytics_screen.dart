import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/data/api.dart';

const _knownEvents = [
  'booking_created',
  'purchase',
  'cancel',
  'refund',
  'provider_ops_paid',
];

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<String, dynamic>? status;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/analytics/status');
      setState(() {
        status = data;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    final role = staffState.effectiveRole;
    final allowed = staffCan(role, 'audit.read') || canSeeScreen(role, 'analytics');
    if (!allowed) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    if (loading) return const V2Loading();
    if (error != null) {
      return Center(child: V2ErrorBanner(message: error!, onRetry: _load));
    }

    final enabled = status?['enabled'] == true;
    final measurementId = '${status?['measurementId'] ?? ''}'.trim();

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 28),
        children: [
          V2PageHeader(
            title: lang == 'ar' ? 'التحليلات' : 'Analytics',
            lang: lang,
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'ar' ? 'حالة GA4' : 'GA4 status', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                V2FactRow(
                  label: lang == 'ar' ? 'مفعّل' : 'Enabled',
                  value: enabled ? (lang == 'ar' ? 'نعم' : 'Yes') : (lang == 'ar' ? 'لا' : 'No'),
                ),
                V2FactRow(
                  label: 'measurementId',
                  value: measurementId.isEmpty ? '—' : measurementId,
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'ar'
                      ? 'يجب ضبط GA4_API_SECRET على الخادم لإرسال أحداث Measurement Protocol.'
                      : 'GA4_API_SECRET must be set on the server for Measurement Protocol events.',
                  style: const TextStyle(fontSize: 13, color: Ops.muted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'ar' ? 'أحداث معروفة' : 'Known events', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                for (final e in _knownEvents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Ops.plum),
                        const SizedBox(width: 10),
                        Text(e, style: const TextStyle(fontFamily: Ops.mono, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
