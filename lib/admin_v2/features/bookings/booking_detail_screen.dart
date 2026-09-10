import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Map<String, dynamic>? booking;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/bookings/${widget.bookingId}');
      setState(() {
        booking = unwrapEntity(data, const ['booking']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _forceStatus(String status) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'تغيير الحالة' : 'Change status',
      body: lang == 'ar' ? 'تغيير الحالة إلى $status؟' : 'Change status to $status?',
      confirmLabel: lang == 'ar' ? 'تغيير' : 'Change',
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${widget.bookingId}/status', data: {'status': status});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تغيير الحالة' : 'Status changed');
        _loadBooking();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _resolveDispute(String outcome) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'حل النزاع' : 'Resolve dispute',
      body: lang == 'ar' ? 'حل النزاع: $outcome؟' : 'Resolve dispute: $outcome?',
      confirmLabel: lang == 'ar' ? 'حل' : 'Resolve',
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${widget.bookingId}/dispute/resolve', data: {'outcome': outcome});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم حل النزاع' : 'Dispute resolved');
        _loadBooking();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonate(String userId, String kind, String name) async {
    try {
      final path = kind == 'provider' ? '/admin/providers/$userId/impersonate' : '/admin/users/$userId/impersonate';
      final response = await staffClient.post(path);
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(id: userId, name: name, token: token, kind: kind);
      if (mounted) context.go(V2Paths.impersonateSubject(userId, kind: kind));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'bookings.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    if (loading) return const V2Loading();
    if (error != null) return Center(child: V2ErrorBanner(message: error!, onRetry: _loadBooking));
    final b = booking;
    if (b == null) return const V2Empty();

    final client = nestedPerson(b, const ['client', 'customer', 'user']);
    final provider = nestedPerson(b, const ['provider', 'pro']);
    final clientName = clientNameOf(b, lang);
    final providerName = providerNameOf(b, lang);
    final clientId = (() {
      final nested = idOf(client ?? {});
      return nested.isNotEmpty ? nested : '${b['clientId'] ?? ''}';
    })();
    final providerId = (() {
      final nested = idOf(provider ?? {});
      return nested.isNotEmpty ? nested : '${b['providerId'] ?? ''}';
    })();
    final addr = asMap(b['address']);
    final area = areaLabel(addr?['area'] ?? b['areaName'] ?? client?['area'], lang);
    final timeline = asDynList(b['timeline']);
    final trustFeeAmount = asInt(b['trustFeeAmount']);
    final travel = asInt(b['travel']);
    final addressStr = addr != null ? '${addr['street'] ?? ''} ${addr['area'] ?? ''}'.trim() : '';
    final payoutFlag = b['opsPaid'] == true;

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
        children: [
          // Header: back to bookings, ref, status pill, total + payment method
          Row(
            children: [
              IconButton(onPressed: () => context.go(V2Paths.bookings), icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(
                  bookingRef(b),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: Ops.mono),
                ),
              ),
              V2StatusPill(label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
            ],
          ),
          const SizedBox(height: 8),
          // Total and payment method in header
          Row(
            children: [
              Text(
                '${money(asInt(b['total']), lang)} • ${b['paymentMethod'] ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Visit card: Date, Time, Service, Area, Address, Payout flag
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lang == 'ar' ? 'تفاصيل الزيارة' : 'Visit Details', 
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (payoutFlag)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Ops.greenInk,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lang == 'ar' ? 'مدفوع' : 'PAID OUT',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                V2FactRow(label: lang == 'ar' ? 'التاريخ والوقت' : 'Date & Time', value: formatWhen(b['slotStart'], lang)),
                V2FactRow(label: lang == 'ar' ? 'الخدمة' : 'Service', value: serviceLabel(b, lang)),
                V2FactRow(label: lang == 'ar' ? 'المنطقة' : 'Area', value: area),
                if (addressStr.isNotEmpty)
                  V2FactRow(label: lang == 'ar' ? 'العنوان' : 'Address', value: addressStr),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Price breakdown: service, travel, trust fee (flagged not paid out), client total
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'ar' ? 'تفصيل الأسعار' : 'Price Breakdown', 
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                V2FactRow(
                  label: lang == 'ar' ? 'الخدمة' : 'Service', 
                  value: money(asInt(b['total']) - travel - trustFeeAmount, lang)
                ),
                if (travel > 0)
                  V2FactRow(label: lang == 'ar' ? 'السفر' : 'Travel', value: money(travel, lang)),
                if (trustFeeAmount > 0)
                  Row(
                    children: [
                      Expanded(
                        child: V2FactRow(
                          label: lang == 'ar' ? 'رسوم الضمان' : 'Trust Fee', 
                          value: money(trustFeeAmount, lang)
                        ),
                      ),
                      if (!payoutFlag)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Ops.terracottaInk,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            lang == 'ar' ? 'غير مدفوع' : 'NOT PAID',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                const Divider(),
                V2FactRow(
                  label: lang == 'ar' ? 'إجمالي العميل' : 'Client Total', 
                  value: money(asInt(b['total']), lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // People: client + pro with Open record + Impersonate
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: V2Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang == 'ar' ? 'العميلة' : 'Customer', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(clientName),
                      Text('${client?['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, color: Ops.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (clientId.isNotEmpty && staffCan(staffState.effectiveRole, 'users.read'))
                            TextButton(
                              onPressed: () => context.go(V2Paths.customer(clientId)),
                              child: Text(lang == 'ar' ? 'فتح السجل' : 'Open record'),
                            ),
                          if (clientId.isNotEmpty && staffCan(staffState.effectiveRole, 'users.impersonate'))
                            TextButton(
                              onPressed: () => _impersonate(clientId, 'customer', clientName),
                              child: Text(lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: V2Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang == 'ar' ? 'المهنية' : 'Provider', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(providerName),
                      Text('${provider?['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, color: Ops.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (providerId.isNotEmpty && staffCan(staffState.effectiveRole, 'providers.read'))
                            TextButton(
                              onPressed: () => context.go(V2Paths.provider(providerId)),
                              child: Text(lang == 'ar' ? 'فتح السجل' : 'Open record'),
                            ),
                          if (providerId.isNotEmpty && staffCan(staffState.effectiveRole, 'providers.impersonate'))
                            TextButton(
                              onPressed: () => _impersonate(providerId, 'provider', providerName),
                              child: Text(lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (timeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang == 'ar' ? 'الجدول الزمني' : 'Timeline', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final event in timeline)
                    Builder(builder: (_) {
                      final e = asMap(event) ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text('${e['status'] ?? e['event'] ?? e['description'] ?? e}', style: const TextStyle(fontSize: 13))),
                            Text(formatDay(e['at'] ?? e['timestamp'] ?? e['createdAt'], lang),
                                style: const TextStyle(fontSize: 11, color: Ops.muted, fontFamily: Ops.mono)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
          // Force status chips: confirmed, in_progress, completed, cancelled
          if (staffCan(staffState.effectiveRole, 'bookings.write')) ...[
            const SizedBox(height: 16),
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang == 'ar' ? 'تغيير الحالة' : 'Force Status', 
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _forceStatus('confirmed'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.greenInk),
                        child: Text(lang == 'ar' ? 'مؤكد' : 'Confirmed'),
                      ),
                      ElevatedButton(
                        onPressed: () => _forceStatus('in_progress'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: Text(lang == 'ar' ? 'قيد التنفيذ' : 'In Progress'),
                      ),
                      ElevatedButton(
                        onPressed: () => _forceStatus('completed'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text(lang == 'ar' ? 'مكتمل' : 'Completed'),
                      ),
                      ElevatedButton(
                        onPressed: () => _forceStatus('cancelled'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.terracottaInk),
                        child: Text(lang == 'ar' ? 'ملغى' : 'Cancelled'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Dispute: Refund / Release / Split
          if (staffCan(staffState.effectiveRole, 'bookings.write')) ...[
            const SizedBox(height: 12),
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang == 'ar' ? 'حل النزاع' : 'Dispute Resolution', 
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _resolveDispute('refund'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.terracottaInk),
                        child: Text(lang == 'ar' ? 'استرداد' : 'Refund'),
                      ),
                      ElevatedButton(
                        onPressed: () => _resolveDispute('release'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.greenInk),
                        child: Text(lang == 'ar' ? 'إطلاق' : 'Release'),
                      ),
                      ElevatedButton(
                        onPressed: () => _resolveDispute('split'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: Text(lang == 'ar' ? 'تقسيم' : 'Split'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
