import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

// Keys must match the backend's BookingStatus enum (models.bookingStatusMeta)
// exactly — adminForceStatus rejects anything else with a 400. 'confirmed'
// and bare 'cancelled' aren't real statuses (the real ones are 'paid' and
// 'cancelled_client'); sending those always 400'd, which is why staff
// couldn't force a booking to "Confirmed" or "Cancelled by client" before.
const _forceStatuses = <(String key, String en, String ar)>[
  ('paid', 'Confirmed', 'مؤكد'),
  ('in_progress', 'In progress', 'جارية'),
  ('completed', 'Completed', 'مكتملة'),
  ('cancelled_client', 'Cancelled by client', 'ملغاة'),
];

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Map<String, dynamic>? booking;
  bool loading = true;
  String? error;
  Future<dynamic>? _receiptFuture;

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
      final data = await staffClient.get('/admin/bookings/${widget.bookingId}');
      final row = unwrapEntity(data, const ['booking']);
      final receipt = '${row['paymentReceiptUrl'] ?? ''}'.trim();
      setState(() {
        booking = row;
        loading = false;
        _receiptFuture = receipt.isEmpty ? null : staffClient.uploadBytes(receipt);
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _forceStatus(String key, String label) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'فرض الحالة' : 'Force status',
      body: lang == 'ar'
          ? 'تغيير حالة الحجز ${bookingRefOf()} إلى «$label»؟'
          : 'Force booking ${bookingRefOf()} to "$label"?',
      confirmLabel: label,
      roleLabel: roleLabel(ref.read(staffSessionProvider).effectiveRole),
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${widget.bookingId}/status', data: {'status': key});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'الحالة الآن «$label»' : 'Status set to $label');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  String bookingRefOf() => booking == null ? '' : bookingRef(booking!);

  Future<void> _confirmPayment() async {
    final lang = ref.read(localeCodeProvider);
    final existing = '${booking?['paymentReceiptUrl'] ?? ''}';
    if (existing.isNotEmpty) {
      final ok = await v2Confirm(
        context,
        title: lang == 'ar' ? 'تأكيد الدفع' : 'Confirm payment',
        body: lang == 'ar' ? 'العميلة رفعت صورة التحويل. تأكيد إن المبلغ وصل؟' : 'The client uploaded a transfer screenshot. Confirm the money arrived?',
        confirmLabel: lang == 'ar' ? 'تأكيد الدفع' : 'Confirm payment',
      );
      if (!ok) return;
      try {
        await staffClient.post('/admin/bookings/${widget.bookingId}/confirm-payment', data: {});
        if (mounted) {
          v2Toast(context, lang == 'ar' ? 'تم تأكيد الدفع' : 'Payment confirmed');
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
      return;
    }
    XFile? receipt;
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'تأكيد الدفع' : 'Confirm payment',
      confirmLabel: lang == 'ar' ? 'تأكيد الدفع' : 'Confirm payment',
      bodyBuilder: (ctx, setLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang == 'ar'
                  ? 'ده لتحويل وصل مباشرة برة Paymob (زي إنستاباي على حساب أُنس). أرفقي لقطة المعاملة عشان تتسجل مع الحجز.'
                  : 'For a transfer that reached Oons outside Paymob (e.g. straight InstaPay). Attach the transaction screenshot — it\'s stored on the booking.',
              style: const TextStyle(fontSize: 12.5, color: Ops.mutedSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            V2FormField(
              label: lang == 'ar' ? 'لقطة المعاملة (مطلوبة)' : 'Transaction screenshot (required)',
              child: OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                  setLocal(() => receipt = f);
                },
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(receipt == null
                    ? (lang == 'ar' ? 'أرفقي لقطة الشاشة' : 'Attach screenshot')
                    : (lang == 'ar' ? 'تم الإرفاق' : 'Attached')),
              ),
            ),
          ],
        );
      },
      onValidate: () {
        if (receipt == null) {
          v2Toast(context, lang == 'ar' ? 'اللقطة مطلوبة' : 'Screenshot is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok || receipt == null) return;
    try {
      final bytes = await receipt!.readAsBytes();
      await staffClient.postMultipart(
        '/admin/bookings/${widget.bookingId}/confirm-payment',
        fields: const {},
        fileField: 'receipt',
        bytes: bytes,
        filename: receipt!.name.isNotEmpty ? receipt!.name : 'receipt.jpg',
      );
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تأكيد الدفع' : 'Payment confirmed');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _resolveDispute(String outcome, String title, String detail, {bool danger = false}) async {
    final lang = ref.read(localeCodeProvider);
    final refLabel = bookingRefOf();
    final ok = await v2Confirm(
      context,
      title: title,
      body: refLabel.isEmpty ? detail : '${lang == 'ar' ? 'حجز' : 'Booking'} $refLabel · $detail',
      confirmLabel: title.split('—').last.trim(),
      danger: danger,
      roleLabel: roleLabel(ref.read(staffSessionProvider).effectiveRole),
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${widget.bookingId}/dispute/resolve', data: {'outcome': outcome});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم حل النزاع' : 'Dispute resolved — $outcome');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonate(String id, String kind, String name) async {
    try {
      final path = kind == 'provider' ? '/admin/providers/$id/impersonate' : '/admin/users/$id/impersonate';
      final response = await staffClient.post(path);
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(id: id, name: name, token: token, kind: kind);
      if (mounted) context.go(V2Paths.impersonateSubject(id, kind: kind));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final sess = ref.watch(staffSessionProvider);
    final role = sess.effectiveRole;
    if (!staffCan(role, 'bookings.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final b = booking;
    if (b == null) return const V2Empty();

    final canWrite = staffCan(role, 'bookings.write');
    final status = statusLabel('${b['status']}', lang);
    final client = nestedPerson(b, const ['client', 'customer', 'user']);
    final provider = nestedPerson(b, const ['provider', 'pro']);
    final clientName = clientNameOf(b, lang);
    final providerName = providerNameOf(b, lang);
    final clientId = idOf(client ?? {}).isNotEmpty ? idOf(client!) : '${b['clientId'] ?? ''}';
    final providerId = idOf(provider ?? {}).isNotEmpty ? idOf(provider!) : '${b['providerId'] ?? ''}';
    final addr = asMap(b['address']);
    final area = areaLabel(addr?['area'] ?? b['areaName'] ?? client?['area'], lang);
    final total = asInt(b['total']);
    final trust = asInt(b['trustFeeAmount']);
    final travel = asInt(b['travel']);
    final serviceAmt = total - trust - travel;
    final method = paymentMethodLabel('${b['paymentMethod'] ?? ''}', lang);
    // No dispute field on the DTO — infer from status / refund.
    final disputeNote = '${b['status']}'.toLowerCase() == 'disputed'
        ? (lang == 'ar' ? 'نزاع مفتوح' : 'Dispute open')
        : asInt(b['refundAmount']) > 0
            ? '${lang == 'ar' ? 'مُسترد' : 'Refunded'} ${money(asInt(b['refundAmount']), lang)}'
            : (lang == 'ar' ? 'لا نزاع على هذا الحجز' : 'No dispute on this booking');
    final timeline = asDynList(b['timeline']);

    final left = <Widget>[
      V2SectionCard(
        title: lang == 'ar' ? 'الزيارة' : 'Visit',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 13,
              runSpacing: 13,
              children: [
                _fact(lang == 'ar' ? 'التاريخ' : 'Date', formatDayOnly(b['slotStart'])),
                _fact(lang == 'ar' ? 'الوقت' : 'Time', formatTimeOnly(b['slotStart'])),
                _fact(lang == 'ar' ? 'الخدمة' : 'Service', serviceLabel(b, lang)),
                _fact(lang == 'ar' ? 'الفئة' : 'Category',
                    verticalLabel(b['service'] ?? b['vertical'] ?? b['categoryName'] ?? b['category'], lang)),
                _fact(lang == 'ar' ? 'المنطقة' : 'Area', area),
                _fact(lang == 'ar' ? 'الدفع للمهنية' : 'Payout', b['opsPaid'] == true ? (lang == 'ar' ? 'مسوّاة' : 'Settled') : (lang == 'ar' ? 'معلقة' : 'Pending')),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Ops.wellSand,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Ops.borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang == 'ar' ? 'العنوان' : 'Address', style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      locName(addr?['street'] ?? addr?['line1'], lang),
                      locName(addr?['building'], lang),
                      area,
                      areaLabel(addr?['city'] ?? addr?['cityName'], lang),
                    ].where((e) => e.trim().isNotEmpty).toSet().join(' · '),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      V2SectionCard(
        title: lang == 'ar' ? 'تفصيل السعر' : 'Price breakdown',
        child: Column(
          children: [
            _priceRow(serviceLabel(b, lang), money(serviceAmt, lang)),
            if (travel > 0) _priceRow('${lang == 'ar' ? 'الانتقال إلى' : 'Travel to'} $area', money(travel, lang)),
            _priceRow(lang == 'ar' ? 'رسوم الأمان (لا تُدفع للمهنية)' : 'Trust fee (not paid out)', money(trust, lang)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.border, width: 2))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(lang == 'ar' ? 'إجمالي العميلة' : 'Client total',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text(money(total, lang),
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                lang == 'ar'
                    ? 'صافي المهنية لا يشمل رسوم الأمان — هذا السطر لا يُدفع أبداً.'
                    : 'Provider gross excludes the trust fee — that line is never paid out.',
                style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft),
              ),
            ),
          ],
        ),
      ),
      if (timeline.isNotEmpty)
        V2SectionCard(
          title: lang == 'ar' ? 'الجدول الزمني' : 'Timeline',
          child: Column(
            children: [
              for (final e in timeline)
                Builder(builder: (_) {
                  final m = asMap(e) ?? {};
                  final label = timelineLabel(m['key'] ?? m['event'] ?? m['status'], lang);
                  if (label.isEmpty) return const SizedBox.shrink();
                  final done = m['done'] == true || !isZeroTime(m['at'] ?? m['timestamp'] ?? m['createdAt']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: done ? Ops.barCompleted : Ops.borderStrong,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: done ? Ops.ink : Ops.mutedSoft)),
                        ),
                        Text(formatDay(m['at'] ?? m['timestamp'] ?? m['createdAt'], lang),
                            style: const TextStyle(fontSize: 11.5, color: Ops.muted, fontFamily: Ops.mono)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
    ];

    final receiptUrl = '${b['paymentReceiptUrl'] ?? ''}';
    final lastPaymentError = '${b['lastPaymentError'] ?? ''}';
    final right = <Widget>[
      if ('${b['status']}' == 'pending_payment' || receiptUrl.isNotEmpty || lastPaymentError.isNotEmpty)
        V2SectionCard(
          title: lang == 'ar' ? 'الدفع' : 'Payment',
          subtitle: '${b['status']}' == 'pending_payment' && receiptUrl.isNotEmpty
              ? (lang == 'ar' ? 'العميلة رفعت صورة التحويل — أكّدي الدفع' : 'Client uploaded a screenshot — confirm the transfer')
              : receiptUrl.isNotEmpty
                  ? (lang == 'ar' ? 'تم تأكيده يدويًا' : 'Confirmed manually')
                  : (lang == 'ar' ? 'بانتظار الدفع' : 'Awaiting payment'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (method.isNotEmpty) ...[
                Text(method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
              ],
              if (lastPaymentError.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Ops.impBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFD9BFB4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'ar' ? 'آخر خطأ في محاولة الدفع الحية (Paymob)' : 'Last live payment attempt error (Paymob)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Ops.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(lastPaymentError, style: const TextStyle(fontSize: 11.5, fontFamily: Ops.mono, height: 1.4)),
                    ],
                  ),
                ),
              ],
              if (canWrite && '${b['status']}' == 'pending_payment')
                V2Btn(
                  label: lang == 'ar' ? 'تأكيد الدفع' : 'Confirm payment',
                  kind: V2BtnKind.primary,
                  expand: true,
                  onPressed: _confirmPayment,
                ),
              if (receiptUrl.isNotEmpty) ...[
                if (canWrite && '${b['status']}' == 'pending_payment') const SizedBox(height: 7),
                FutureBuilder(
                  future: _receiptFuture ?? staffClient.uploadBytes(receiptUrl),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final bytes = snap.data is Uint8List ? snap.data as Uint8List : null;
                    if (bytes == null || bytes.isEmpty) {
                      return Text(lang == 'ar' ? 'تعذر عرض الإيصال' : 'Could not load the screenshot',
                          style: const TextStyle(fontSize: 12.5, color: Ops.muted));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
                                child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(bytes, height: 220, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 7),
                        V2Btn(
                          label: lang == 'ar' ? 'عرض إيصال المعاملة' : 'View transaction screenshot',
                          kind: V2BtnKind.ghost,
                          expand: true,
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => Dialog(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
                                child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      if (canWrite)
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: Ops.plum, borderRadius: BorderRadius.circular(Ops.radiusCard)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang == 'ar' ? 'فرض الحالة' : 'Force status',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Ops.plumTextSoft)),
              const SizedBox(height: 4),
              Text('${lang == 'ar' ? 'الحالية' : 'Currently'} $status',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFBCA9B8))),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: 3.1,
                children: [
                  for (final s in _forceStatuses)
                    _StatusButton(
                      label: lang == 'ar' ? s.$3 : s.$2,
                      current: status.toLowerCase() == (lang == 'ar' ? s.$3 : s.$2).toLowerCase(),
                      cancel: s.$1 == 'cancelled_client',
                      onTap: () => _forceStatus(s.$1, lang == 'ar' ? s.$3 : s.$2),
                    ),
                ],
              ),
            ],
          ),
        ),
      if (canWrite)
        V2SectionCard(
          title: lang == 'ar' ? 'النزاع' : 'Dispute',
          subtitle: disputeNote,
          child: Column(
            children: [
              V2Btn(
                label: lang == 'ar' ? 'استرداد للعميلة' : 'Refund client',
                kind: V2BtnKind.danger,
                expand: true,
                onPressed: () => _resolveDispute(
                    'refund',
                    '${lang == 'ar' ? 'حل النزاع' : 'Resolve dispute'} — ${lang == 'ar' ? 'استرداد' : 'Refund'}',
                    lang == 'ar'
                        ? 'استرداد كامل للعميلة، ولا تُدفع المهنية.'
                        : 'Full refund to the client, provider not paid.',
                    danger: true),
              ),
              const SizedBox(height: 7),
              V2Btn(
                label: lang == 'ar' ? 'إطلاق للمهنية' : 'Release to pro',
                kind: V2BtnKind.primary,
                expand: true,
                onPressed: () => _resolveDispute(
                    'release',
                    '${lang == 'ar' ? 'حل النزاع' : 'Resolve dispute'} — ${lang == 'ar' ? 'إطلاق' : 'Release'}',
                    lang == 'ar' ? 'تُطلق المبالغ للمهنية بالكامل.' : 'Funds released to the provider in full.'),
              ),
              const SizedBox(height: 7),
              V2Btn(
                label: lang == 'ar' ? 'تقسيم ٥٠/٥٠' : 'Split 50/50',
                kind: V2BtnKind.ghost,
                expand: true,
                onPressed: () => _resolveDispute(
                    'split',
                    '${lang == 'ar' ? 'حل النزاع' : 'Resolve dispute'} — ${lang == 'ar' ? 'تقسيم' : 'Split'}',
                    lang == 'ar' ? 'تقسيم ٥٠/٥٠ بين العميلة والمهنية.' : '50/50 split between client and provider.'),
              ),
            ],
          ),
        ),
      V2SectionCard(
        title: lang == 'ar' ? 'الأشخاص' : 'People',
        child: Column(
          children: [
            _party(
              role: lang == 'ar' ? 'العميلة' : 'Client',
              name: clientName,
              phone: '${client?['phone'] ?? ''}',
              canOpen: clientId.isNotEmpty && staffCan(role, 'users.read'),
              onOpen: () => context.go(V2Paths.customer(clientId)),
              canImpersonate: clientId.isNotEmpty && staffCan(role, 'users.impersonate'),
              onImpersonate: () => _impersonate(clientId, 'customer', clientName),
            ),
            const SizedBox(height: 10),
            _party(
              role: lang == 'ar' ? 'المهنية' : 'Professional',
              name: providerName,
              phone: '${provider?['phone'] ?? ''}',
              canOpen: providerId.isNotEmpty && staffCan(role, 'providers.read'),
              onOpen: () => context.go(V2Paths.provider(providerId)),
              canImpersonate: providerId.isNotEmpty && staffCan(role, 'providers.impersonate'),
              onImpersonate: () => _impersonate(providerId, 'provider', providerName),
              last: true,
            ),
          ],
        ),
      ),
    ];

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 70),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V2Btn(
                label: lang == 'ar' ? '→ الحجوزات' : '← Bookings',
                onPressed: () => context.go(V2Paths.bookings),
                kind: V2BtnKind.ghost,
              ),
              V2StatusPill(label: status, tone: statusTone('${b['status']}'), large: true),
              Text('${money(total, lang)}${method.isNotEmpty ? ' · $method' : ''}',
                  style: const TextStyle(fontSize: 13, color: Ops.muted)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth < 940) {
              return Column(children: [
                for (final w in left) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w),
                for (final w in right) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w),
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [for (final w in left) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w)],
                  ),
                ),
                const SizedBox(width: Ops.gap),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [for (final w in right) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w)],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
          const SizedBox(height: 3),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: Ops.inkSoft))),
          Text(value, style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _party({
    required String role,
    required String name,
    required String phone,
    required bool canOpen,
    required VoidCallback onOpen,
    required bool canImpersonate,
    required VoidCallback onImpersonate,
    bool last = false,
  }) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.rowBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: const TextStyle(fontSize: 11.5, color: Ops.muted)),
          const SizedBox(height: 3),
          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (phone.trim().isNotEmpty)
            Text(phone, style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft, fontFamily: Ops.mono)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (canOpen) V2Btn.ghost('Open record', onPressed: onOpen, size: V2BtnSize.sm),
              if (canImpersonate) V2Btn.imp('Impersonate', onPressed: onImpersonate, size: V2BtnSize.sm),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label, required this.current, required this.cancel, required this.onTap});
  final String label;
  final bool current;
  final bool cancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ops.radiusBtn),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: current ? Ops.plumTextSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(Ops.radiusBtn),
          border: Border.all(color: cancel ? const Color(0x80E29E8C) : const Color(0x42F1E8EE)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: current ? Ops.plum : (cancel ? const Color(0xFFE9A995) : Ops.plumTextSoft),
          ),
        ),
      ),
    );
  }
}

