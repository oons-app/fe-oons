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
import 'package:oons/data/api.dart';

class ClaimsScreen extends ConsumerStatefulWidget {
  const ClaimsScreen({super.key});

  @override
  ConsumerState<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends ConsumerState<ClaimsScreen> {
  List<Map<String, dynamic>> claims = [];
  List<Map<String, dynamic>> filteredClaims = [];
  bool loading = true;
  String? error;
  String selectedFilter = 'All';
  final List<String> filters = ['All', 'Open', 'Escalated', 'Closed'];

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/claims');
      setState(() {
        claims = asMapList(data['claims']);
        _applyFilter();
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  void _applyFilter() {
    if (selectedFilter == 'All') {
      filteredClaims = List.from(claims);
    } else {
      filteredClaims = claims.where((claim) {
        final status = '${claim['status']}'.toLowerCase();
        return status == selectedFilter.toLowerCase();
      }).toList();
    }
  }

  void _onFilterChange(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilter();
    });
  }

  Future<void> _resolveClaim(String claimId) async {
    final lang = ref.read(localeCodeProvider);
    String? note;
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'حل المطالبة' : 'Resolve claim',
      confirmLabel: lang == 'ar' ? 'حل' : 'Resolve',
      bodyBuilder: (ctx, setState) => V2FormField(
        label: lang == 'ar' ? 'ملاحظة الحل' : 'Resolution note',
        child: TextField(onChanged: (v) => note = v, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
      ),
    );
    if (!confirmed) return;
    try {
      await staffClient.post('/admin/claims/$claimId/resolve', data: {
        'status': 'resolved',
        if (note != null && note!.isNotEmpty) 'note': note,
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم حل المطالبة' : 'Claim resolved'); _loadClaims(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'claims.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canWrite = staffCan(staffState.effectiveRole, 'claims.write');
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(title: lang == 'ar' ? 'المطالبات' : 'Claims', lang: lang, resultCount: loading ? null : filteredClaims.length),
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              ...filters.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: V2FilterChip(
                  label: filter,
                  selected: selectedFilter == filter,
                  onTap: () => _onFilterChange(filter),
                ),
              )),
            ],
          ),
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _loadClaims))
            : filteredClaims.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'المطالبة' : 'Claim',
                      lang == 'ar' ? 'النوع' : 'Type',
                      lang == 'ar' ? 'الحجز' : 'Booking',
                      lang == 'ar' ? 'العميل' : 'Customer',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      lang == 'ar' ? 'التفاصيل' : 'Details',
                      lang == 'ar' ? 'التاريخ' : 'Date',
                      if (canWrite) lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (final claim in filteredClaims)
                        [
                          Text('#${shortId(idOf(claim))}', style: const TextStyle(fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                          Text('${claim['kind'] ?? claim['type'] ?? ''}'),
                          InkWell(
                            onTap: () {
                              final bid = '${claim['bookingId'] ?? ''}';
                              if (bid.isEmpty) return;
                              context.go(V2Paths.booking(bid));
                            },
                            child: Text('#${shortId('${claim['bookingId'] ?? ''}')}', style: const TextStyle(fontFamily: Ops.mono, fontSize: 12, color: Ops.plum, decoration: TextDecoration.underline)),
                          ),
                          Text('${claim['customer'] ?? claim['customerName'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          V2StatusPill(label: statusLabel('${claim['status']}', lang), tone: statusTone('${claim['status']}')),
                          Text('${claim['body'] ?? claim['resolutionNote'] ?? ''}', style: const TextStyle(fontSize: 12)),
                          Text(formatDay(claim['createdAt'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted)),
                          if (canWrite)
                            TextButton(
                              onPressed: '${claim['status']}'.toLowerCase() == 'resolved' || '${claim['status']}'.toLowerCase() == 'closed'
                                  ? null
                                  : () => _resolveClaim(idOf(claim)),
                              child: Text(lang == 'ar' ? 'حل' : 'Resolve'),
                            ),
                        ],
                    ],
                  )),
                  const SizedBox(height: 24),
                ]),
        ),
      ]),
    );
  }
}
