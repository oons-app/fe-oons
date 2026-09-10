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
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Map<String, dynamic>? customer;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> addresses = [];
  bool loading = true;
  String? error;
  String notes = '';
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _loadCustomer();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/users/${widget.customerId}');
      final user = unwrapEntity(data, const ['user', 'customer', 'client']);
      final nextNotes = '${user['staffNotes'] ?? user['notes'] ?? ''}';
      setState(() {
        customer = user;
        bookings = asMapList(data['bookings']);
        addresses = asMapList(user['addresses'] ?? data['addresses'] ?? []);
        notes = nextNotes;
        _notesCtrl.text = nextNotes;
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/users/${widget.customerId}/notes', data: {'notes': notes});
      if (mounted) {
        v2Toast(context, t(V2Copy.saved, lang));
        _loadCustomer();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonateCustomer() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final response = await staffClient.post('/admin/users/${widget.customerId}/impersonate');
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      final name = personName(customer, lang, fallbackId: widget.customerId);
      if (token.isNotEmpty) {
        ref.read(staffSessionProvider.notifier).startImpersonation(
              id: widget.customerId,
              name: name,
              token: token,
              kind: 'customer',
            );
        if (mounted) context.go(V2Paths.impersonateSubject(widget.customerId, kind: 'customer'));
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _addAddress() async {
    final lang = ref.read(localeCodeProvider);
    String label = '';
    String line1 = '';
    String area = 'zamalek';
    String city = '';
    bool isDefault = false;
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'إضافة عنوان' : 'Add address',
      confirmLabel: lang == 'ar' ? 'إضافة' : 'Add',
      bodyBuilder: (ctx, setLocal) => Column(
        children: [
          V2FormField(
            label: lang == 'ar' ? 'التسمية' : 'Label',
            child: TextField(onChanged: (v) => label = v, decoration: const InputDecoration(border: OutlineInputBorder())),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'العنوان' : 'Line 1',
            child: TextField(onChanged: (v) => line1 = v, decoration: const InputDecoration(border: OutlineInputBorder())),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'المنطقة' : 'Area',
            child: DropdownButtonFormField<String>(
              value: area,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final a in ['zamalek', 'dokki', 'mohandeseen', 'maadi', 'nasr_city', 'heliopolis', 'garden_city', 'downtown'])
                  DropdownMenuItem(value: a, child: Text(areaName(a, lang))),
              ],
              onChanged: (v) => setLocal(() => area = v ?? area),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'المدينة' : 'City',
            child: TextField(onChanged: (v) => city = v, decoration: const InputDecoration(border: OutlineInputBorder())),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lang == 'ar' ? 'افتراضي' : 'Default'),
            value: isDefault,
            onChanged: (v) => setLocal(() => isDefault = v ?? false),
          ),
        ],
      ),
      onValidate: () => line1.trim().isNotEmpty,
    );
    if (!confirmed) return;
    try {
      await staffClient.post('/admin/users/${widget.customerId}/addresses', data: {
        'label': label.trim().isEmpty ? 'Home' : label.trim(),
        'line1': line1.trim(),
        'area': area,
        if (city.trim().isNotEmpty) 'city': city.trim(),
        'isDefault': isDefault,
      });
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تمت الإضافة' : 'Address added');
        _loadCustomer();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _setDefaultAddress(String aid) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/users/${widget.customerId}/addresses/$aid', data: {'isDefault': true});
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم التعيين' : 'Default set');
        _loadCustomer();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _deleteAddress(String aid) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(
      context,
      title: lang == 'ar' ? 'حذف العنوان' : 'Delete address',
      body: lang == 'ar' ? 'حذف هذا العنوان؟' : 'Delete this address?',
      confirmLabel: t(V2Copy.delete, lang),
      danger: true,
    );
    if (!ok) return;
    try {
      await staffClient.delete('/admin/users/${widget.customerId}/addresses/$aid');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Deleted');
        _loadCustomer();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _bookForThem() async {
    final lang = ref.read(localeCodeProvider);
    List<Map<String, dynamic>> providers = [];
    try {
      final data = await staffClient.get('/admin/providers', query: {'limit': 50, 'vetted': '1'});
      providers = asMapList(data['providers']);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
      return;
    }
    if (providers.isEmpty) {
      if (mounted) v2Toast(context, lang == 'ar' ? 'لا توجد مهنيات' : 'No vetted providers', error: true);
      return;
    }
    if (addresses.isEmpty) {
      if (mounted) v2Toast(context, lang == 'ar' ? 'أضيفي عنواناً أولاً' : 'Add an address first', error: true);
      return;
    }

    String? providerId;
    String providerLabel = '';
    String? addressId = idOf(addresses.firstWhere((a) => a['isDefault'] == true, orElse: () => addresses.first));
    String slotStart = '';
    String serviceItemId = '';
    String bookNotes = '';

    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'حجز للعميلة' : 'Book for them',
      confirmLabel: lang == 'ar' ? 'إنشاء حجز' : 'Create booking',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(
            label: lang == 'ar' ? 'المهنية' : 'Provider',
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (p) => personName(p, lang, fallbackId: idOf(p)),
              optionsBuilder: (text) {
                final q = text.text.trim().toLowerCase();
                if (q.isEmpty) return providers.take(20);
                return providers.where((p) {
                  final n = personName(p, lang, fallbackId: idOf(p)).toLowerCase();
                  final phone = '${p['phone'] ?? ''}'.toLowerCase();
                  return n.contains(q) || phone.contains(q);
                }).take(20);
              },
              onSelected: (p) {
                providerId = idOf(p);
                providerLabel = personName(p, lang, fallbackId: idOf(p));
                setLocal(() {});
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                if (providerLabel.isNotEmpty && controller.text.isEmpty) {
                  controller.text = providerLabel;
                }
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: lang == 'ar' ? 'ابحثي بالاسم' : 'Search by name',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'العنوان' : 'Address',
            child: DropdownButtonFormField<String>(
              value: addressId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final a in addresses)
                  DropdownMenuItem(
                    value: idOf(a),
                    child: Text(
                      [
                        if ('${a['label'] ?? ''}'.trim().isNotEmpty) locName(a['label'], lang),
                        locName(a['line1'] ?? a['address'], lang),
                      ].where((s) => s.trim().isNotEmpty).join(' · '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setLocal(() => addressId = v),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'موعد البداية (ISO)' : 'Slot start (ISO)',
            child: TextField(
              onChanged: (v) => slotStart = v,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '2026-09-15T10:00:00+03:00',
              ),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'معرف الخدمة' : 'Service item ID',
            child: TextField(
              onChanged: (v) => serviceItemId = v,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'ملاحظات (اختياري)' : 'Notes (optional)',
            child: TextField(
              onChanged: (v) => bookNotes = v,
              maxLines: 2,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
      onValidate: () =>
          (providerId ?? '').isNotEmpty &&
          (addressId ?? '').isNotEmpty &&
          slotStart.trim().isNotEmpty &&
          serviceItemId.trim().isNotEmpty,
    );
    if (!confirmed) return;
    try {
      final response = await staffClient.post('/admin/users/${widget.customerId}/book', data: {
        'providerId': providerId,
        'addressId': addressId,
        'slotStart': slotStart.trim(),
        'serviceItemId': serviceItemId.trim(),
        if (bookNotes.trim().isNotEmpty) 'notes': bookNotes.trim(),
      });
      final booking = unwrapEntity(response, const ['booking']);
      final bid = idOf(booking.isNotEmpty ? booking : response);
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم إنشاء الحجز' : 'Booking created');
        if (bid.isNotEmpty) {
          context.go(V2Paths.booking(bid));
        } else {
          _loadCustomer();
        }
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  String _addrLine(Map address, String lang) {
    final line = locName(address['line1'] ?? address['address'], lang);
    if (line.isNotEmpty) return line;
    return '${address['line1'] ?? address['address'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'users.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    if (loading) return const V2Loading();
    if (error != null) {
      return Center(child: V2ErrorBanner(message: error!, onRetry: _loadCustomer));
    }
    final c = customer;
    if (c == null) return const V2Empty();
    final name = personName(c, lang, fallbackId: idOf(c));
    final canWrite = staffCan(staffState.effectiveRole, 'users.write');
    final canBook = staffCan(staffState.effectiveRole, 'bookings.write');

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => context.go(V2Paths.customers), icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              if (staffCan(staffState.effectiveRole, 'users.impersonate'))
                TextButton.icon(
                  onPressed: _impersonateCustomer,
                  icon: const Icon(Icons.login, size: 16),
                  label: Text(lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate'),
                ),
              if (canBook)
                TextButton.icon(
                  onPressed: _bookForThem,
                  icon: const Icon(Icons.event_available, size: 16),
                  label: Text(lang == 'ar' ? 'حجز للعميلة' : 'Book for them'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'ar' ? 'الحقائق' : 'Facts', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                V2FactRow(label: lang == 'ar' ? 'المعرف' : 'ID', value: idOf(c)),
                V2FactRow(label: lang == 'ar' ? 'الهاتف' : 'Phone', value: '${c['phone'] ?? ''}'),
                V2FactRow(label: lang == 'ar' ? 'المنطقة' : 'Area', value: areaLabel(c['area'], lang)),
                V2FactRow(label: lang == 'ar' ? 'التسجيل' : 'Joined', value: formatDay(c['createdAt'], lang)),
                V2FactRow(label: lang == 'ar' ? 'التقييم' : 'Rating', value: asDouble(c['rating']).toStringAsFixed(1)),
                if (c['instructions'] != null && '${c['instructions']}'.trim().isNotEmpty)
                  V2FactRow(label: lang == 'ar' ? 'التعليمات' : 'Instructions', value: '${c['instructions']}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lang == 'ar' ? 'العناوين' : 'Addresses',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (canWrite)
                      TextButton.icon(
                        onPressed: _addAddress,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(lang == 'ar' ? 'إضافة' : 'Add'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (addresses.isEmpty)
                  Text(lang == 'ar' ? 'لا عناوين بعد' : 'No addresses yet', style: const TextStyle(color: Ops.muted, fontSize: 13))
                else
                  ...addresses.map((address) {
                    final aid = idOf(address);
                    final isDefault = address['isDefault'] == true;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Ops.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  locName(address['label'], lang).isNotEmpty
                                      ? locName(address['label'], lang)
                                      : (lang == 'ar' ? 'عنوان' : 'Address'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              if (isDefault)
                                V2StatusPill(label: lang == 'ar' ? 'افتراضي' : 'Default', tone: V2Tone.ok),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(_addrLine(address, lang), style: const TextStyle(fontSize: 13)),
                          if (address['line2'] != null && '${address['line2']}'.trim().isNotEmpty)
                            Text('${address['line2']}', style: const TextStyle(fontSize: 13, color: Ops.muted)),
                          if (address['city'] != null || address['area'] != null)
                            Text(
                              '${areaLabel(address['area'], lang)} ${locName(address['city'], lang)}'.trim(),
                              style: const TextStyle(fontSize: 12, color: Ops.muted),
                            ),
                          if (canWrite) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (!isDefault)
                                  TextButton(
                                    onPressed: aid.isEmpty ? null : () => _setDefaultAddress(aid),
                                    child: Text(lang == 'ar' ? 'تعيين افتراضي' : 'Set default'),
                                  ),
                                TextButton(
                                  onPressed: aid.isEmpty ? null : () => _deleteAddress(aid),
                                  style: TextButton.styleFrom(foregroundColor: Ops.terracottaInk),
                                  child: Text(lang == 'ar' ? 'حذف' : 'Delete'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(lang == 'ar' ? 'ملاحظات الفريق' : 'Staff notes',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (staffCan(staffState.effectiveRole, 'notes.write'))
                      TextButton(onPressed: _saveNotes, child: Text(t(V2Copy.save, lang))),
                  ],
                ),
                TextField(
                  controller: _notesCtrl,
                  onChanged: (v) => notes = v,
                  maxLines: 4,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(lang == 'ar' ? 'الحجوزات' : 'Bookings', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go('${V2Paths.bookings}?customerId=${widget.customerId}'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(lang == 'ar' ? 'تاريخ كامل' : 'Full history'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (bookings.isEmpty)
            const V2Empty()
          else
            V2Card(
              padding: EdgeInsets.zero,
              child: V2DataTable(
                minWidth: 720,
                headers: [
                  lang == 'ar' ? 'الحجز' : 'Booking',
                  lang == 'ar' ? 'الحالة' : 'Status',
                  lang == 'ar' ? 'المبلغ' : 'Amount',
                  lang == 'ar' ? 'الموعد' : 'When',
                ],
                rows: [
                  for (final b in bookings)
                    [
                      Text(bookingRef(b), style: const TextStyle(fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                      V2StatusPill(label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
                      Text(money(asInt(b['total']), lang), style: const TextStyle(fontFamily: Ops.mono)),
                      Text(formatWhen(b['slotStart'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted)),
                    ],
                ],
                onRowTap: (i) => context.go(V2Paths.booking(idOf(bookings[i]))),
              ),
            ),
        ],
      ),
    );
  }
}
