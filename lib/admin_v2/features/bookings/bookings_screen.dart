import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/admin_v2/chrome/bulk_pay_bar.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/download_stub.dart'
    if (dart.library.html) 'package:oons/admin_v2/data/download_web.dart' as download;
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

/// Status chips matching Ops Console v2 Bookings template.
const _statusChips = <(String key, String en, String ar)>[
  ('', 'All', 'الكل'),
  ('confirmed', 'Confirmed', 'مؤكد'),
  ('in_progress', 'In progress', 'جارية'),
  ('completed', 'Completed', 'مكتملة'),
  ('pending', 'Pending payment', 'بانتظار الدفع'),
  ('cancelled', 'Cancelled by client', 'ملغاة من العميلة'),
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
  bool loading = true;
  String? error;
  String statusFilter = '';
  String queryFilter = '';
  bool unpaidOps = false;
  final searchCtrl = TextEditingController();
  Set<String> selected = {};
  bool bulkMode = false;
  Timer? _refreshTimer;
  bool _appInBackground = false;

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      WidgetsBinding.instance.addObserver(this);
    }
    statusFilter = widget.queryParams['status'] ?? '';
    queryFilter = widget.queryParams['q'] ?? '';
    unpaidOps = widget.queryParams['unpaidOps'] == '1';
    searchCtrl.text = queryFilter;
    _load();
    if (widget.live) {
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    if (widget.live) {
      WidgetsBinding.instance.removeObserver(this);
      _refreshTimer?.cancel();
    }
    searchCtrl.dispose();
    super.dispose();
  }

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_appInBackground) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final query = <String, dynamic>{
        'limit': 100,
        if (widget.live) 'live': '1',
        if (!widget.live && statusFilter.isNotEmpty) 'status': statusFilter,
        if (queryFilter.isNotEmpty) 'q': queryFilter,
        if (unpaidOps) 'unpaidOps': '1',
      };
      final data = await staffClient.get('/admin/bookings', query: query);
      final rows = asMapList(data['bookings']);
      final counts = <String, int>{};
      try {
        final all = await staffClient.get('/admin/bookings', query: {'limit': 200});
        for (final b in asMapList(all['bookings'])) {
          final s = '${b['status'] ?? ''}'.toLowerCase();
          counts[s] = (counts[s] ?? 0) + 1;
        }
      } catch (_) {
        for (final b in rows) {
          final s = '${b['status'] ?? ''}'.toLowerCase();
          counts[s] = (counts[s] ?? 0) + 1;
        }
      }
      if (!mounted) return;
      setState(() {
        bookings = rows;
        statusCounts = counts;
        loading = false;
        if (!bulkMode) selected.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  int get _totalAll {
    if (statusCounts.isEmpty) return bookings.length;
    return statusCounts.values.fold(0, (a, b) => a + b);
  }

  int _countFor(String key) {
    if (key.isEmpty) return _totalAll;
    if (key == 'confirmed') {
      return (statusCounts['confirmed'] ?? 0) + (statusCounts['paid'] ?? 0);
    }
    if (key == 'pending') {
      return (statusCounts['pending'] ?? 0) + (statusCounts['pending_payment'] ?? 0);
    }
    if (key == 'cancelled') {
      return (statusCounts['cancelled'] ?? 0) + (statusCounts['canceled'] ?? 0);
    }
    return statusCounts[key] ?? 0;
  }

  int get _followUp =>
      _countFor('pending') + _countFor('in_progress') + (statusCounts['on_the_way'] ?? 0);

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

  Future<void> _bulkSettle() async {
    if (selected.isEmpty) return;
    final lang = ref.read(localeCodeProvider);
    final selectedRows = bookings.where((b) => selected.contains(idOf(b))).toList();
    if (selectedRows.isEmpty) return;

    // Unique providers in selection — ops picks by name, never by hex.
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
      title: lang == 'ar' ? 'تسوية وإرسال الإيصال' : 'Settle & send receipt',
      confirmLabel: t(V2Copy.settle, lang),
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${selected.length} ${t(V2Copy.selected, lang)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '${t(V2Copy.providerGross, lang)}: ${money(_gross(), lang)}',
            style: const TextStyle(fontFamily: Ops.mono, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          V2FormField(
            label: lang == 'ar' ? 'المهنية (بالاسم)' : 'Professional (by name)',
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: providerQuery),
              optionsBuilder: (text) {
                final q = text.text.trim().toLowerCase();
                final names = providerOptions.values.toList()..sort();
                if (q.isEmpty) return names;
                return names.where((n) => n.toLowerCase().contains(q));
              },
              onSelected: (name) {
                providerQuery = name;
                for (final e in providerOptions.entries) {
                  if (e.value == name) {
                    providerId = e.key;
                    break;
                  }
                }
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return TextField(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (v) {
                    providerQuery = v;
                    for (final e in providerOptions.entries) {
                      if (e.value.toLowerCase() == v.trim().toLowerCase()) {
                        providerId = e.key;
                        break;
                      }
                    }
                  },
                  decoration: InputDecoration(
                    hintText: lang == 'ar' ? 'ابحثي بالاسم' : 'Search by name',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(label: lang == 'ar' ? 'ملاحظة' : 'Note', child: TextField(onChanged: (v) => note = v, maxLines: 2)),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'إيصال إنستاباي (مطلوب)' : 'InstaPay receipt (required)',
            child: OutlinedButton.icon(
              onPressed: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery);
                setLocal(() => receipt = f);
              },
              icon: const Icon(Icons.attach_file, size: 16),
              label: Text(receipt == null
                  ? (lang == 'ar' ? 'اختر ملفاً' : 'Choose file')
                  : (lang == 'ar' ? 'تم الاختيار' : 'File selected')),
            ),
          ),
        ],
      ),
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
        v2Toast(context, lang == 'ar' ? 'تم التسوية وإرسال الإيصال' : 'Settled — Excel + WhatsApp queued');
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

  int _gross() => bookings.where((b) => selected.contains(idOf(b))).map(providerGrossFromBooking).fold(0, (a, b) => a + b);

  Widget _twoLine(String top, String bottom, {bool monoTop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          top.isEmpty ? '—' : top,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            fontFamily: monoTop ? Ops.mono : Ops.sans,
            color: Ops.ink,
          ),
        ),
        if (bottom.isNotEmpty) Text(bottom, style: const TextStyle(fontSize: 12, color: Ops.muted, height: 1.35)),
      ],
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
    final t = parseTime(b['slotStart']);
    if (t == null) return '';
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  String _timeLine(Map b) {
    final t = parseTime(b['slotStart']);
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    final canWrite = staffCan(role, 'bookings.write');
    final canPay = staffCan(role, 'payouts.write');
    final title = widget.live ? (lang == 'ar' ? 'زيارات مباشرة' : 'Live visits') : (lang == 'ar' ? 'الحجوزات' : 'Bookings');
    final sub = widget.live
        ? (lang == 'ar' ? 'تحديث كل ٣٠ ثانية' : 'Auto-refresh every 30s')
        : '$_totalAll ${lang == 'ar' ? 'إجمالي' : 'total'} · $_followUp ${lang == 'ar' ? 'تحتاج متابعة' : 'need follow-up'}';

    return V2Gate(
      allowed: staffCan(role, 'bookings.read'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Ops.ink)),
                      const SizedBox(height: 4),
                      Text(sub, style: const TextStyle(fontSize: 13, color: Ops.muted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: lang == 'ar' ? 'ابحث بالاسم أو الهاتف أو المرجع' : 'Search name, phone, or ref',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18, color: Ops.muted),
                    ),
                    onSubmitted: (v) {
                      queryFilter = v.trim();
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (!widget.live)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in _statusChips) ...[
                      V2FilterChip(
                        label: '${lang == 'ar' ? chip.$3 : chip.$2} (${_countFor(chip.$1)})',
                        selected: statusFilter == chip.$1,
                        onTap: () {
                          setState(() => statusFilter = chip.$1);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    V2FilterChip(
                      label: lang == 'ar' ? 'غير مسددة للمهنية' : 'Unpaid ops',
                      selected: unpaidOps,
                      onTap: () {
                        setState(() => unpaidOps = !unpaidOps);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 8),
            child: Row(
              children: [
                Text(
                  '${bookings.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
                  style: const TextStyle(fontSize: 12.5, color: Ops.muted, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (canPay && !widget.live)
                  TextButton(
                    onPressed: () => setState(() {
                      bulkMode = !bulkMode;
                      if (!bulkMode) selected.clear();
                    }),
                    child: Text(bulkMode ? t(V2Copy.clear, lang) : t(V2Copy.bulkPay, lang)),
                  ),
                TextButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(t(V2Copy.exportCsv, lang)),
                ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2, color: Ops.plum),
          Expanded(
            child: error != null
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: V2ErrorBanner(message: error!, onRetry: _load),
                  )
                : bookings.isEmpty && !loading
                    ? const V2Empty()
                    : ListView(
                        padding: const EdgeInsetsDirectional.fromSTEB(22, 0, 22, 24),
                        children: [
                          V2DataTable(
                            minWidth: 980,
                            headers: [
                              if (bulkMode) '',
                              lang == 'ar' ? 'المرجع' : 'Ref',
                              lang == 'ar' ? 'العميلة' : 'Customer',
                              lang == 'ar' ? 'المهنية' : 'Professional',
                              lang == 'ar' ? 'التاريخ' : 'Date',
                              lang == 'ar' ? 'الحالة' : 'Status',
                              lang == 'ar' ? 'الإجمالي' : 'Total',
                              if (canWrite) (lang == 'ar' ? 'إجراءات' : 'Actions'),
                            ],
                            leading: bulkMode
                                ? (i) => Checkbox(
                                      value: selected.contains(idOf(bookings[i])),
                                      onChanged: (_) {
                                        final id = idOf(bookings[i]);
                                        setState(() {
                                          if (selected.contains(id)) {
                                            selected.remove(id);
                                          } else {
                                            selected.add(id);
                                          }
                                        });
                                      },
                                    )
                                : null,
                            rows: [
                              for (final b in bookings)
                                [
                                  _twoLine(bookingRef(b), serviceLabel(b, lang), monoTop: true),
                                  _twoLine(clientNameOf(b, lang), _areaOf(b, lang)),
                                  Text(providerNameOf(b, lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  _twoLine(_dateLine(b), _timeLine(b)),
                                  V2StatusPill(
                                    label: statusLabel('${b['status']}', lang),
                                    tone: statusTone('${b['status']}'),
                                  ),
                                  Text(
                                    money(asInt(b['total']), lang),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: Ops.mono),
                                  ),
                                  if (canWrite)
                                    OutlinedButton(
                                      onPressed: () => context.go(V2Paths.booking(idOf(b))),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(lang == 'ar' ? 'فتح' : 'Open', style: const TextStyle(fontSize: 12)),
                                    ),
                                ],
                            ],
                            onRowTap: (i) {
                              final id = idOf(bookings[i]);
                              if (bulkMode) {
                                setState(() {
                                  if (selected.contains(id)) {
                                    selected.remove(id);
                                  } else {
                                    selected.add(id);
                                  }
                                });
                              } else {
                                context.go(V2Paths.booking(id));
                              }
                            },
                          ),
                        ],
                      ),
          ),
          if (bulkMode && selected.isNotEmpty)
            V2BulkPayBar(
              count: selected.length,
              providerGrossPiastres: _gross(),
              lang: lang,
              onClear: () => setState(() => selected.clear()),
              onSettle: _bulkSettle,
            ),
        ],
      ),
    );
  }
}
