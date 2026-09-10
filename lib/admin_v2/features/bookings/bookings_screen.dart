import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/download_stub.dart'
    if (dart.library.html) 'package:oons/admin_v2/data/download_web.dart' as download;
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/chrome/bulk_pay_bar.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

/// Status chips matching the Ops Console v2 Bookings template.
const _statusChips = <(String key, String en, String ar)>[
  ('', 'All', 'الكل'),
  ('confirmed', 'Confirmed', 'مؤكد'),
  ('in_progress', 'In progress', 'جارية'),
  ('completed', 'Completed', 'مكتملة'),
  ('pending', 'Pending payment', 'بانتظار الدفع'),
  ('cancelled', 'Cancelled by client', 'ملغاة'),
];

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, this.queryParams = const {}, this.live = false});
  final Map<String, String> queryParams;
  final bool live;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> bookings = [];
  Map<String, int> statusCounts = {};
  int total = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;

  static const _pageSize = 50;
  String statusFilter = '';
  String queryFilter = '';
  bool unpaidOps = false;
  Set<String> selected = {};
  bool bulkMode = false;
  Timer? _refreshTimer;
  Timer? _debounce;
  bool _appInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    statusFilter = widget.queryParams['status'] ?? '';
    queryFilter = widget.queryParams['q'] ?? '';
    unpaidOps = widget.queryParams['unpaidOps'] == '1';
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishHeader());
    _load();
    if (widget.live) _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _publishHeader() {
    if (!mounted) return;
    final canWrite = staffCan(ref.read(staffSessionProvider).effectiveRole, 'bookings.write');
    ref.read(v2HeaderConfigProvider.notifier).state = V2HeaderConfig(
      newLabel: (canWrite && !widget.live) ? 'Booking' : null,
      onNewRecord: (canWrite && !widget.live) ? _bookForCustomer : null,
      liveCount: _liveCount,
    );
  }

  int get _liveCount => bookings.where((b) {
        final s = '${b['status'] ?? ''}'.toLowerCase();
        return s.contains('progress') || s.contains('on_the_way') || s == 'arrived';
      }).length;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.live) return;
    _appInBackground = state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (_appInBackground) {
      _refreshTimer?.cancel();
    } else {
      _startAutoRefresh();
      _load();
    }
  }

  void _startAutoRefresh() {
    if (!widget.live || _appInBackground) return;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Ops.refreshEvery, (_) {
      if (!_appInBackground) _load();
    });
  }

  Future<void> _load({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMore = true;
      } else {
        loading = true;
      }
      error = null;
    });
    try {
      final skip = append ? bookings.length : 0;
      final query = <String, dynamic>{
        'limit': _pageSize,
        'skip': skip,
        if (widget.live) 'live': '1',
        if (!widget.live && statusFilter.isNotEmpty) 'status': statusFilter,
        if (queryFilter.isNotEmpty) 'q': queryFilter,
        if (unpaidOps) 'unpaidOps': '1',
      };
      final data = await staffClient.get('/admin/bookings', query: query);
      final rows = asMapList(data['bookings']);
      // Server returns a `$group`-derived counts map keyed by enum key
      // (`paid`, `on_the_way`, …) over the un-status-filtered scope.
      final srv = asMap(data['counts']);
      final counts = <String, int>{};
      if (srv != null && srv.isNotEmpty) {
        srv.forEach((k, v) => counts[k.toString().toLowerCase()] = asInt(v));
      } else {
        for (final b in rows) {
          final s = '${b['status'] ?? ''}'.toLowerCase();
          counts[s] = (counts[s] ?? 0) + 1;
        }
      }
      if (!mounted) return;
      setState(() {
        bookings = append ? [...bookings, ...rows] : rows;
        // Counts only reflect the full scope on a fresh (skip 0) load.
        if (!append || statusCounts.isEmpty) statusCounts = counts;
        total = asInt(data['total']);
        loading = false;
        loadingMore = false;
        if (!bulkMode && !append) selected.clear();
      });
      _publishHeader();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
        loadingMore = false;
      });
    }
  }

  /// `total` is the server count for the *active* query (drives paging + the
  /// result label). The "All" chip must show the full un-filtered scope, which
  /// is the sum of the `counts` map.
  bool get _hasMore => total > 0 && bookings.length < total;

  int get _totalAll {
    if (statusCounts.isNotEmpty) return statusCounts.values.fold(0, (a, b) => a + b);
    return total > 0 ? total : bookings.length;
  }

  /// Chip key -> the real enum keys it groups (must match the backend
  /// `bookingStatusFilter`).
  static const _statusGroups = <String, List<String>>{
    'confirmed': ['paid', 'on_the_way'],
    'in_progress': ['in_progress'],
    'completed': ['completed', 'released'],
    'pending': ['pending_payment'],
    'cancelled': ['cancelled_client', 'cancelled_provider'],
  };

  int _countFor(String key) {
    if (key.isEmpty) return _totalAll;
    final group = _statusGroups[key] ?? [key];
    return group.fold(0, (a, k) => a + (statusCounts[k] ?? 0));
  }

  Future<void> _exportCsv() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final bytes = await staffClient.getBytes('/admin/bookings/export.csv', query: {
        if (widget.live) 'live': '1',
        if (statusFilter.isNotEmpty) 'status': statusFilter,
        if (queryFilter.isNotEmpty) 'q': queryFilter,
        if (unpaidOps) 'unpaidOps': '1',
      });
      download.downloadBytes(bytes, 'oons-bookings.csv');
      if (mounted) v2Toast(context, t(V2Copy.exportCsv, lang));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  int _gross() =>
      bookings.where((b) => selected.contains(idOf(b))).map(providerGrossFromBooking).fold(0, (a, b) => a + b);
  int _clientTotal() =>
      bookings.where((b) => selected.contains(idOf(b))).map((b) => asInt(b['total'])).fold(0, (a, b) => a + b);

  Future<void> _bookForCustomer() async {
    final lang = ref.read(localeCodeProvider);
    var q = '';
    List<Map<String, dynamic>> results = [];
    Map<String, dynamic>? picked;
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'حجز لعميلة' : 'Book for a customer',
      confirmLabel: lang == 'ar' ? 'فتح ملفها' : 'Open their record',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2FormField(
            label: lang == 'ar' ? 'ابحثي بالاسم أو الهاتف' : 'Search by name or phone',
            child: TextField(
              autofocus: true,
              onChanged: (v) async {
                q = v.trim();
                if (q.length < 2) return;
                try {
                  final data = await staffClient.get('/admin/users', query: {'q': q, 'limit': 8});
                  setLocal(() => results = asMapList(data['users']));
                } catch (e) {
                  debugPrint('book-for-customer: user search failed: $e');
                }
              },
              decoration: InputDecoration(hintText: lang == 'ar' ? 'اسم العميلة' : 'Customer name'),
            ),
          ),
          const SizedBox(height: 10),
          for (final u in results)
            ListTile(
              dense: true,
              selected: picked != null && idOf(picked!) == idOf(u),
              title: Text(personName(u, lang, fallbackId: idOf(u))),
              subtitle: Text('${u['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 11)),
              onTap: () => setLocal(() => picked = u),
            ),
        ],
      ),
      onValidate: () {
        if (picked == null) {
          v2Toast(context, lang == 'ar' ? 'اختاري عميلة' : 'Pick a customer', error: true);
          return false;
        }
        return true;
      },
    );
    if (ok && picked != null && mounted) context.go(V2Paths.customer(idOf(picked!)));
  }

  Future<void> _bulkSettle() async {
    if (selected.isEmpty) return;
    final lang = ref.read(localeCodeProvider);
    final selectedRows = bookings.where((b) => selected.contains(idOf(b))).toList();
    if (selectedRows.isEmpty) return;

    final providerOptions = <String, String>{}; // id -> display name
    for (final b in selectedRows) {
      final pid = '${b['providerId'] ?? idOf(asMap(b['provider']) ?? {})}';
      if (pid.isEmpty) continue;
      providerOptions[pid] = providerNameOf(b, lang);
    }
    if (providerOptions.isEmpty) {
      v2Toast(context, lang == 'ar' ? 'لا مهنية مرتبطة' : 'No professional on selected visits', error: true);
      return;
    }

    String providerId = providerOptions.keys.first;
    String providerQuery = providerOptions[providerId] ?? '';
    String note = '';
    XFile? receipt;
    final ok = await v2Form(
      context,
      title: '${lang == 'ar' ? 'تسوية' : 'Settle'} ${selected.length} ${lang == 'ar' ? 'زيارة' : 'visits'}',
      confirmLabel: lang == 'ar' ? 'تسوية وإرسال' : 'Settle & send',
      bodyBuilder: (ctx, setLocal) {
        final gross = _gross();
        final clientTotal = _clientTotal();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(
              label: lang == 'ar' ? 'المهنية (بالاسم)' : 'Provider',
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: providerQuery),
                optionsBuilder: (text) {
                  final query = text.text.trim().toLowerCase();
                  final names = providerOptions.values.toList()..sort();
                  return query.isEmpty ? names : names.where((n) => n.toLowerCase().contains(query));
                },
                onSelected: (name) {
                  providerQuery = name;
                  for (final e in providerOptions.entries) {
                    if (e.value == name) providerId = e.key;
                  }
                },
                fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (v) {
                    providerQuery = v;
                    for (final e in providerOptions.entries) {
                      if (e.value.toLowerCase() == v.trim().toLowerCase()) providerId = e.key;
                    }
                  },
                  decoration: InputDecoration(hintText: lang == 'ar' ? 'ابحثي بالاسم' : 'Search by name'),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(lang == 'ar' ? 'يُختار بالاسم — رقم المعرف يُحلّ داخلياً.' : 'Picked by name — the hex ID is resolved for you.',
                style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft)),
            const SizedBox(height: 12),
            V2FormField(
              label: lang == 'ar' ? 'إيصال التحويل (مطلوب)' : 'Transfer receipt (required)',
              child: OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                  setLocal(() => receipt = f);
                },
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(receipt == null
                    ? (lang == 'ar' ? 'أرفقي لقطة إنستاباي' : 'Attach the InstaPay screenshot')
                    : (lang == 'ar' ? 'تم الإرفاق' : 'Attached')),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Ops.wellSand,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Ops.borderSoft),
              ),
              child: Column(
                children: [
                  _sumRow(lang == 'ar' ? 'زيارات' : 'Visits', '${selected.length}'),
                  _sumRow(lang == 'ar' ? 'إجمالي العميلة' : 'Client total', money(clientTotal, lang)),
                  _sumRow(lang == 'ar' ? 'رسوم الأمان مستبعدة' : 'Trust fee excluded', money(clientTotal - gross, lang)),
                  _sumRow(lang == 'ar' ? 'صافي المهنية' : 'Provider gross', money(gross, lang), strong: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang == 'ar'
                  ? 'التسوية تُنشئ دفعة، وتولّد Excel بإجمالي صافٍ من رسوم الأمان، وتضع إيصال واتساب في الطابور.'
                  : 'Settling writes a batch, generates the ops Excel with client total net of trust fee, and queues the WhatsApp receipt.',
              style: const TextStyle(fontSize: 12, color: Ops.mutedSoft, height: 1.5),
            ),
            const SizedBox(height: 10),
            V2FormField(
              label: lang == 'ar' ? 'ملاحظة (اختياري)' : 'Note (optional)',
              child: TextField(onChanged: (v) => note = v, maxLines: 2),
            ),
          ],
        );
      },
      onValidate: () {
        final match = providerOptions.entries.where((e) => e.value.toLowerCase() == providerQuery.trim().toLowerCase());
        if (match.isEmpty && !providerOptions.containsKey(providerId)) {
          v2Toast(context, lang == 'ar' ? 'اختاري مهنية بالاسم' : 'Pick a professional by name', error: true);
          return false;
        }
        if (match.isNotEmpty) providerId = match.first.key;
        if (receipt == null) {
          v2Toast(context, lang == 'ar' ? 'الإيصال مطلوب' : 'Receipt is required', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok || receipt == null) return;
    try {
      final bytes = await receipt!.readAsBytes();
      await staffClient.postMultipart(
        '/admin/bookings/bulk-pay',
        fields: {
          'bookingIds': selected.join(','),
          'providerId': providerId,
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
        fileField: 'receipt',
        bytes: bytes,
        filename: receipt!.name.isNotEmpty ? receipt!.name : 'receipt.jpg',
      );
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تمت التسوية — Excel وواتساب في الطابور' : 'Settled — Excel + WhatsApp queued');
        setState(() {
          selected.clear();
          bulkMode = false;
        });
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _sumRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontFamily: Ops.mono, fontWeight: strong ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  String _areaOf(Map b, String lang) {
    final addr = asMap(b['address']);
    final fromAddr = areaLabel(addr?['area'] ?? addr?['city'], lang);
    if (fromAddr.isNotEmpty) return fromAddr;
    final client = asMap(b['client']);
    return areaLabel(client?['area'] ?? b['area'], lang);
  }

  String _dateLine(Map b) {
    final tm = parseTime(b['slotStart']);
    if (tm == null) return '';
    return '${tm.year.toString().padLeft(4, '0')}-${tm.month.toString().padLeft(2, '0')}-${tm.day.toString().padLeft(2, '0')}';
  }

  String _timeLine(Map b) {
    final tm = parseTime(b['slotStart']);
    if (tm == null) return '';
    return '${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}';
  }

  Widget _stacked(String top, String bottom, {bool mono = false, bool strong = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(top.isEmpty ? '—' : top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
                fontFamily: mono ? Ops.mono : Ops.sans,
                color: Ops.ink)),
        if (bottom.isNotEmpty)
          Text(bottom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Ops.mutedSoft)),
      ],
    );
  }

  void _toggle(String id) => setState(() => selected.contains(id) ? selected.remove(id) : selected.add(id));

  Future<void> _raiseClaim(Map b) async {
    final lang = ref.read(localeCodeProvider);
    var kind = 'damage';
    var note = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'فتح مطالبة' : 'Raise a claim',
      confirmLabel: lang == 'ar' ? 'فتح المطالبة' : 'Raise claim',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang == 'ar'
                ? 'مطالبة على الحجز ${bookingRef(b)} للعميلة ${clientNameOf(b, lang)}.'
                : 'Opens a claim against booking ${bookingRef(b)} for ${clientNameOf(b, lang)}.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'النوع' : 'Type',
            child: DropdownButtonFormField<String>(
              initialValue: kind,
              items: const [
                DropdownMenuItem(value: 'damage', child: Text('Damage')),
                DropdownMenuItem(value: 'theft', child: Text('Theft')),
                DropdownMenuItem(value: 'payout', child: Text('Payout dispute')),
              ],
              onChanged: (v) => kind = v ?? 'damage',
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'ملاحظة (مطلوبة)' : 'Note (required)',
            child: TextField(onChanged: (v) => note = v, maxLines: 3),
          ),
        ],
      ),
      onValidate: () {
        if (note.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'اكتبي ملاحظة' : 'Add a note', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      await staffClient.post('/admin/bookings/${idOf(b)}/claims', data: {'kind': kind, 'body': note.trim()});
      if (mounted) v2Toast(context, lang == 'ar' ? 'تم فتح المطالبة' : 'Claim opened');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    final canPay = staffCan(role, 'payouts.write');

    ref.listen(v2QueryProvider, (_, next) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        queryFilter = next.trim();
        _load();
      });
    });

    if (!staffCan(role, 'bookings.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 70),
            children: [
              // Toolbar: filters + result label + bulk + export
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!widget.live)
                    for (final chip in _statusChips)
                      V2FilterChip(
                        label: lang == 'ar' ? chip.$3 : chip.$2,
                        count: _countFor(chip.$1),
                        selected: statusFilter == chip.$1,
                        onTap: () {
                          setState(() => statusFilter = chip.$1);
                          _load();
                        },
                      ),
                  if (!widget.live)
                    V2FilterChip(
                      label: lang == 'ar' ? 'غير مسددة' : 'Unpaid only',
                      selected: unpaidOps,
                      onTap: () {
                        setState(() => unpaidOps = !unpaidOps);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                      total > bookings.length
                          ? '${bookings.length} / $total ${lang == 'ar' ? 'نتيجة' : 'results'}'
                          : '${bookings.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
                      style: const TextStyle(fontSize: 12.5, color: Ops.muted)),
                  const Spacer(),
                  if (canPay && !widget.live) ...[
                    V2Btn(
                      label: bulkMode
                          ? (lang == 'ar' ? 'إنهاء الدفع الجماعي' : 'Exit bulk pay')
                          : (lang == 'ar' ? 'دفع جماعي' : 'Bulk pay'),
                      onPressed: () => setState(() {
                        bulkMode = !bulkMode;
                        if (!bulkMode) selected.clear();
                      }),
                      kind: bulkMode ? V2BtnKind.primary : V2BtnKind.ghost,
                      size: V2BtnSize.sm,
                    ),
                    const SizedBox(width: 8),
                  ],
                  V2Btn.ghost(t(V2Copy.exportCsv, lang), onPressed: _exportCsv, size: V2BtnSize.sm, icon: Icons.download),
                ],
              ),
              const SizedBox(height: 12),
              if (error != null && bookings.isEmpty)
                V2ErrorBanner(message: error!, onRetry: _load)
              else ...[
                if (error != null) ...[
                  V2ErrorBanner(message: error!, onRetry: _load),
                  const SizedBox(height: 12),
                ],
                V2GridTable(
                  loading: loading,
                  bulkMode: bulkMode,
                  actionsWidth: widget.live ? 150 : 96,
                  emptyText: lang == 'ar'
                      ? 'لا شيء هنا بعد — امسح الفلتر أو البحث'
                      : 'Nothing here yet — clear the filter or search, or create a new record',
                  columns: [
                    V2Col(lang == 'ar' ? 'المرجع' : 'Ref', fixed: 150),
                    V2Col(lang == 'ar' ? 'العميلة' : 'Customer', flex: 1.05),
                    V2Col(lang == 'ar' ? 'المهنية' : 'Professional', flex: 0.95),
                    V2Col(lang == 'ar' ? 'التاريخ' : 'Date', fixed: 110),
                    V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 132),
                    V2Col(lang == 'ar' ? 'الإجمالي' : 'Total', fixed: 100),
                  ],
                  rows: [
                    for (final b in bookings)
                      V2GridRow(
                        onTap: () => context.go(V2Paths.booking(idOf(b))),
                        selectable: true,
                        selected: selected.contains(idOf(b)),
                        onToggleSelect: () => _toggle(idOf(b)),
                        cells: [
                          _stacked(bookingRef(b), serviceLabel(b, lang), mono: true),
                          _stacked(clientNameOf(b, lang), _areaOf(b, lang)),
                          Text(providerNameOf(b, lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Ops.ink)),
                          _stacked(_dateLine(b), _timeLine(b), mono: true, strong: false),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: V2StatusPill(
                                label: statusLabel('${b['status']}', lang), tone: statusTone('${b['status']}')),
                          ),
                          Text(money(asInt(b['total']), lang),
                              style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                        ],
                        actions: [
                          V2Btn(
                            label: lang == 'ar' ? 'فتح' : 'Open',
                            onPressed: () => context.go(V2Paths.booking(idOf(b))),
                            size: V2BtnSize.row,
                          ),
                          if (widget.live && staffCan(role, 'claims.write'))
                            V2Btn(
                              label: lang == 'ar' ? 'مطالبة' : 'Claim',
                              onPressed: () => _raiseClaim(b),
                              kind: V2BtnKind.danger,
                              size: V2BtnSize.row,
                            ),
                        ],
                      ),
                  ],
                ),
              ],
              if (!loading && error == null && _hasMore) ...[
                const SizedBox(height: 14),
                Center(
                  child: V2Btn.ghost(
                    loadingMore
                        ? (lang == 'ar' ? 'جارٍ التحميل…' : 'Loading…')
                        : (lang == 'ar' ? 'تحميل المزيد' : 'Load more'),
                    onPressed: loadingMore ? null : () => _load(append: true),
                    size: V2BtnSize.sm,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (bulkMode && selected.isNotEmpty)
          V2BulkPayBar(
            count: selected.length,
            providerGrossPiastres: _gross(),
            trustFeeExcludedPiastres: _clientTotal() - _gross(),
            lang: lang,
            onClear: () => setState(() => selected.clear()),
            onSettle: _bulkSettle,
          ),
      ],
    );
  }
}
