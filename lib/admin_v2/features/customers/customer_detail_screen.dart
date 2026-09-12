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
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Map<String, dynamic>? customer;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> addresses = [];
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
      final data = await staffClient.get('/admin/users/${widget.customerId}');
      final user = unwrapEntity(data, const ['user', 'customer', 'client']);
      setState(() {
        customer = user;
        bookings = asMapList(data['bookings']);
        addresses = asMapList(user['addresses'] ?? data['addresses'] ?? []);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  String get _roleLabel => roleLabel(ref.read(staffSessionProvider).effectiveRole);

  Future<void> _appendNote(String text) async {
    final c = customer ?? {};
    final existing = '${c['staffNotes'] ?? c['notes'] ?? ''}'.trim();
    final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    final next = existing.isEmpty ? '$text  — $_roleLabel · $stamp' : '$existing\n$text  — $_roleLabel · $stamp';
    try {
      await staffClient.patch('/admin/users/${widget.customerId}/notes', data: {'notes': next});
      if (mounted) {
        v2Toast(context, ref.read(localeCodeProvider) == 'ar' ? 'تم حفظ الملاحظة' : 'Note saved');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonate() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final r = await staffClient.post('/admin/users/${widget.customerId}/impersonate');
      final token = '${r['accessToken'] ?? r['impersonateToken'] ?? ''}';
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(
          id: widget.customerId, name: personName(customer, lang, fallbackId: widget.customerId), token: token, kind: 'customer');
      if (mounted) context.go(V2Paths.impersonateSubject(widget.customerId, kind: 'customer'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _bookForThem() async {
    final lang = ref.read(localeCodeProvider);
    if (addresses.isEmpty) {
      v2Toast(context, lang == 'ar' ? 'أضيفي عنواناً أولاً' : 'Add an address first', error: true);
      return;
    }
    List<Map<String, dynamic>> providers = [];
    try {
      final data = await staffClient.get('/admin/providers', query: {'limit': 100, 'vetted': '1'});
      providers = asMapList(data['providers']);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
      return;
    }
    if (providers.isEmpty) {
      if (mounted) v2Toast(context, lang == 'ar' ? 'لا مهنيات موثّقات' : 'No vetted professionals', error: true);
      return;
    }

    Map<String, dynamic>? provider;
    List<Map<String, dynamic>> services = [];
    String? serviceId;
    var addressId = idOf(addresses.firstWhere((a) => a['isDefault'] == true, orElse: () => addresses.first));
    DateTime slot = DateTime.now().add(const Duration(days: 1, hours: 2));
    var notes = '';

    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'حجز لهذه العميلة' : 'Book for this customer',
      confirmLabel: lang == 'ar' ? 'إنشاء الحجز' : 'Create booking',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(
            label: lang == 'ar' ? 'المهنية' : 'Professional',
            child: Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (p) => personName(p, lang, fallbackId: idOf(p)),
              optionsBuilder: (t) {
                final q = t.text.trim().toLowerCase();
                final all = providers;
                if (q.isEmpty) return all.take(25);
                return all.where((p) =>
                    personName(p, lang, fallbackId: idOf(p)).toLowerCase().contains(q) ||
                    '${p['phone'] ?? ''}'.contains(q));
              },
              onSelected: (p) async {
                provider = p;
                serviceId = null;
                setLocal(() {});
                try {
                  final d = await staffClient.get('/admin/providers/${idOf(p)}');
                  final prov = unwrapEntity(d, const ['provider']);
                  setLocal(() => services = asMapList(prov['items']));
                } catch (e) {
                  debugPrint('book-for-them: provider services fetch failed: $e');
                }
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: InputDecoration(hintText: lang == 'ar' ? 'ابحثي بالاسم' : 'Search by name'),
              ),
            ),
          ),
          if (provider != null) ...[
            const SizedBox(height: 12),
            V2FormField(
              label: lang == 'ar' ? 'الخدمة' : 'Service',
              child: DropdownButtonFormField<String>(
                initialValue: serviceId,
                isExpanded: true,
                hint: Text(services.isEmpty ? (lang == 'ar' ? 'لا خدمات' : 'no services') : '—'),
                items: [
                  for (final s in services)
                    DropdownMenuItem(
                      value: idOf(s),
                      child: Text('${locName(s['name'], lang)} · ${money(asInt(s['price']), lang)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => serviceId = v),
              ),
            ),
          ],
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'العنوان' : 'Address',
            child: DropdownButtonFormField<String>(
              initialValue: addressId,
              isExpanded: true,
              items: [
                for (final a in addresses)
                  DropdownMenuItem(
                    value: idOf(a),
                    child: Text(_addrBody(a, lang), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setLocal(() => addressId = v ?? addressId),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'الموعد' : 'When',
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx, initialDate: slot, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setLocal(() => slot = DateTime(d.year, d.month, d.day, slot.hour, slot.minute));
                  },
                  child: Text(formatDayOnly(slot.toIso8601String())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final tm = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(slot));
                    if (tm != null) setLocal(() => slot = DateTime(slot.year, slot.month, slot.day, tm.hour, tm.minute));
                  },
                  child: Text('${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          V2FormField(
              label: lang == 'ar' ? 'ملاحظات (اختياري)' : 'Notes (optional)',
              child: TextField(onChanged: (v) => notes = v, maxLines: 2)),
        ],
      ),
      onValidate: () {
        if (provider == null || (serviceId ?? '').isEmpty || addressId.isEmpty) {
          v2Toast(context, lang == 'ar' ? 'أكملي الحقول' : 'Pick a professional, service and address', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      final r = await staffClient.post('/admin/users/${widget.customerId}/book', data: {
        'providerId': idOf(provider!),
        'addressId': addressId,
        'serviceItemId': serviceId,
        'slotStart': slot.toUtc().toIso8601String(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      final bid = idOf(unwrapEntity(r, const ['booking']));
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم إنشاء الحجز' : 'Booking created');
        bid.isNotEmpty ? context.go(V2Paths.booking(bid)) : _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _edit() async {
    final lang = ref.read(localeCodeProvider);
    final c = customer ?? {};
    final name = TextEditingController(text: personName(c, lang, fallbackId: idOf(c)));
    final phone = TextEditingController(text: '${c['phone'] ?? ''}');
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'تعديل العميلة' : 'Edit customer',
        bodyBuilder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: lang == 'ar' ? 'الاسم' : 'Full name', child: TextField(controller: name)),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'الهاتف' : 'Phone', child: TextField(controller: phone)),
          ],
        ),
      );
      if (!ok) return;
      try {
        await staffClient.patch('/admin/users/${widget.customerId}',
            data: {'name': name.text.trim(), 'phone': phone.text.trim()});
        if (mounted) {
          v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Customer updated');
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      name.dispose();
      phone.dispose();
    }
  }

  Future<void> _addAddress() async {
    final lang = ref.read(localeCodeProvider);
    final label = TextEditingController();
    final line1 = TextEditingController();
    final city = TextEditingController();
    var area = 'zamalek';
    var isDefault = false;
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'إضافة عنوان' : 'Add address',
        confirmLabel: lang == 'ar' ? 'إضافة' : 'Add',
        bodyBuilder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: lang == 'ar' ? 'التسمية' : 'Label', child: TextField(controller: label)),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'العنوان' : 'Line 1', child: TextField(controller: line1)),
            const SizedBox(height: 12),
            V2FormField(
              label: lang == 'ar' ? 'المنطقة' : 'Area',
              child: DropdownButtonFormField<String>(
                initialValue: area,
                items: [
                  for (final a in const ['zamalek', 'dokki', 'mohandeseen', 'maadi', 'nasr_city', 'heliopolis', 'new_cairo'])
                    DropdownMenuItem(value: a, child: Text(areaName(a, lang))),
                ],
                onChanged: (v) => area = v ?? area,
              ),
            ),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'المدينة' : 'City', child: TextField(controller: city)),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(lang == 'ar' ? 'افتراضي' : 'Set as default'),
              value: isDefault,
              onChanged: (v) => setLocal(() => isDefault = v ?? false),
            ),
          ],
        ),
        onValidate: () {
          if (line1.text.trim().isEmpty) {
            v2Toast(context, lang == 'ar' ? 'العنوان مطلوب' : 'Address is required', error: true);
            return false;
          }
          return true;
        },
      );
      if (!ok) return;
      try {
        await staffClient.post('/admin/users/${widget.customerId}/addresses', data: {
          'label': label.text.trim().isEmpty ? 'Home' : label.text.trim(),
          'line1': line1.text.trim(),
          'area': area,
          if (city.text.trim().isNotEmpty) 'city': city.text.trim(),
          'isDefault': isDefault,
        });
        if (mounted) {
          v2Toast(context, lang == 'ar' ? 'تمت الإضافة' : 'Address added');
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      label.dispose();
      line1.dispose();
      city.dispose();
    }
  }

  Future<void> _removeAddress(Map a) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context,
        title: lang == 'ar' ? 'حذف العنوان؟' : 'Delete address?',
        body: _addrBody(a, lang),
        confirmLabel: t(V2Copy.delete, lang),
        danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/users/${widget.customerId}/addresses/${idOf(a)}');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Address removed');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _setDefault(Map a) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/users/${widget.customerId}/addresses/${idOf(a)}', data: {'isDefault': true});
      _load();
      if (mounted) v2Toast(context, lang == 'ar' ? 'بقى العنوان الأساسي' : 'Set as default');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  String _addrBody(Map a, String lang) => [
        locName(a['line1'] ?? a['address'], lang),
        areaLabel(a['area'], lang),
        locName(a['city'], lang),
      ].where((s) => s.trim().isNotEmpty).join(' · ');

  List<String> _instructions(Map c) {
    final raw = c['instructions'] ?? c['savedInstructions'];
    if (raw is List) return raw.map((e) => '$e').where((s) => s.trim().isNotEmpty).toList();
    final s = '${raw ?? ''}'.trim();
    if (s.isEmpty) return const [];
    return s.split(RegExp(r'[\n•]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'users.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final c = customer;
    if (c == null) return const V2Empty();
    final canWrite = staffCan(role, 'users.write');
    final canNotes = staffCan(role, 'notes.write');
    final name = personName(c, lang, fallbackId: idOf(c));
    final notes = '${c['staffNotes'] ?? c['notes'] ?? ''}'.trim();
    final instructions = _instructions(c);

    final left = <Widget>[
      V2SectionCard(
        title: lang == 'ar' ? 'الملف' : 'Profile',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kv(lang == 'ar' ? 'الهاتف' : 'Phone', '${c['phone'] ?? ''}', mono: true),
            _kv(lang == 'ar' ? 'المنطقة' : 'Area', areaLabel(c['area'], lang)),
            _kv(lang == 'ar' ? 'انضمّت' : 'Joined', formatDayOnly(c['createdAt'])),
            _kv(lang == 'ar' ? 'الحجوزات' : 'Bookings', '${bookings.length}'),
            _kv(lang == 'ar' ? 'التقييم' : 'Rating', asDouble(c['rating']) > 0 ? asDouble(c['rating']).toStringAsFixed(1) : '—'),
            _kv(lang == 'ar' ? 'اللغة' : 'Locale', '${c['locale'] ?? '—'}', last: true),
          ],
        ),
      ),
      V2SectionCard(
        title: lang == 'ar' ? 'العناوين' : 'Addresses',
        trailing: [
          if (canWrite) V2Btn.ghost(lang == 'ar' ? '+ إضافة' : '+ Add', onPressed: _addAddress, size: V2BtnSize.sm),
        ],
        child: Column(
          children: [
            if (addresses.isEmpty)
              Text(lang == 'ar' ? 'لا عناوين بعد' : 'No addresses yet', style: const TextStyle(fontSize: 13, color: Ops.muted))
            else
              for (final a in addresses)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${locName(a['label'], lang).isEmpty ? (lang == 'ar' ? 'عنوان' : 'Address') : locName(a['label'], lang)}'
                              '${a['isDefault'] == true ? (lang == 'ar' ? ' · افتراضي' : ' · default') : ''}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(_addrBody(a, lang), style: const TextStyle(fontSize: 12, color: Ops.muted, height: 1.6)),
                          ],
                        ),
                      ),
                      if (canWrite) ...[
                        if (a['isDefault'] != true)
                          V2Btn.ghost(lang == 'ar' ? 'افتراضي' : 'Default', onPressed: () => _setDefault(a), size: V2BtnSize.row),
                        const SizedBox(width: 6),
                        V2Btn.danger(lang == 'ar' ? 'حذف' : 'Remove', onPressed: () => _removeAddress(a), size: V2BtnSize.row),
                      ],
                    ],
                  ),
                ),
          ],
        ),
      ),
      V2SectionCard(
        title: lang == 'ar' ? 'التعليمات المحفوظة' : 'Saved instructions',
        subtitle: lang == 'ar' ? 'تُعرض للمهنية قبل كل زيارة' : 'Shown to the pro before every visit',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (instructions.isEmpty)
              const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted))
            else
              for (final i in instructions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 7),
                        decoration: const BoxDecoration(color: Ops.barConfirmed, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(i, style: const TextStyle(fontSize: 13, height: 1.6))),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ];

    final right = <Widget>[
      Container(
        decoration: BoxDecoration(
          color: Ops.card,
          borderRadius: BorderRadius.circular(Ops.radiusCard),
          border: Border.all(color: Ops.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.borderSoft))),
              child: Row(
                children: [
                  Text(lang == 'ar' ? 'الحجوزات' : 'Bookings',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${bookings.length} ${lang == 'ar' ? 'إجمالاً' : 'total'}',
                      style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
                ],
              ),
            ),
            if (bookings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 38),
                child: Center(child: Text(lang == 'ar' ? 'لا حجوزات بعد' : 'No bookings yet', style: const TextStyle(fontSize: 13, color: Ops.muted))),
              )
            else
              for (final b in bookings)
                InkWell(
                  onTap: () => context.go(V2Paths.booking(idOf(b))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(serviceLabel(b, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${formatDayOnly(b['slotStart'])} · ${providerNameOf(b, lang)} · ${bookingRef(b)}',
                                  style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft)),
                            ],
                          ),
                        ),
                        V2StatusPill(label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
                        const SizedBox(width: 10),
                        Text(money(asInt(b['total']), lang),
                            style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
      V2SectionCard(
        title: lang == 'ar' ? 'ملاحظات الفريق' : 'Staff notes',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notes.isNotEmpty)
              for (final line in notes.split('\n'))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                  child: Text(line, style: const TextStyle(fontSize: 13, height: 1.6)),
                )
            else
              const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted)),
            if (canNotes) _NoteComposer(onSave: _appendNote, lang: lang),
          ],
        ),
      ),
    ];

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V2Btn(label: lang == 'ar' ? '→ العميلات' : '← Customers', onPressed: () => context.go(V2Paths.customers)),
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (bookings.isNotEmpty)
                V2StatusPill(
                    label: statusLabel('${bookings.first['status']}', lang),
                    tone: statusTone('${bookings.first['status']}'),
                    large: true),
              Text('${c['phone'] ?? ''}', style: const TextStyle(fontSize: 13, color: Ops.muted, fontFamily: Ops.mono)),
              const SizedBox(width: 1),
              if (staffCan(role, 'users.impersonate')) V2Btn.imp('Impersonate', onPressed: _impersonate),
              if (canWrite) V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: _edit),
              if (staffCan(role, 'bookings.write'))
                V2Btn.ghost(lang == 'ar' ? 'حجز لها' : 'Book for them', onPressed: _bookForThem),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            Widget stack(List<Widget> ws) =>
                Column(children: [for (final w in ws) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w)]);
            if (box.maxWidth < 940) return stack([...left, ...right]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 20, child: stack(left)),
                const SizedBox(width: Ops.gap),
                Expanded(flex: 27, child: stack(right)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false, bool last = false}) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.rowBorder))),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12.5, color: Ops.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v.isEmpty ? '—' : v,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: mono ? Ops.mono : Ops.sans)),
          ),
        ],
      ),
    );
  }
}

class _NoteComposer extends StatefulWidget {
  const _NoteComposer({required this.onSave, required this.lang});
  final Future<void> Function(String) onSave;
  final String lang;

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _c,
          maxLines: 3,
          decoration: InputDecoration(hintText: ar ? 'أضيفي ملاحظة تبقى على هذا الملف' : 'Add a note that stays on this record'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: V2Btn.primary(ar ? 'حفظ الملاحظة' : 'Save note', onPressed: () {
            final t = _c.text.trim();
            if (t.isEmpty) return;
            widget.onSave(t);
            _c.clear();
          }),
        ),
      ],
    );
  }
}
