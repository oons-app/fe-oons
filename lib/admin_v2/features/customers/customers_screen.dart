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
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

const _filterAreas = [
  'zamalek',
  'dokki',
  'mohandeseen',
  'maadi',
  'nasr_city',
  'heliopolis',
  'garden_city',
  'downtown',
  'madinaty',
  'rehab',
  'capital',
];

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<Map<String, dynamic>> customers = [];
  bool loading = true;
  String? error;
  String searchQuery = '';
  String areaFilter = '';
  String phoneFilter = '';
  String visitsFilter = '';
  String hasNotesFilter = '';
  bool showAdvanced = false;
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final query = <String, dynamic>{'limit': 80};
      if (searchQuery.isNotEmpty) query['q'] = searchQuery;
      if (areaFilter.isNotEmpty) query['area'] = areaFilter;
      if (phoneFilter.isNotEmpty) query['phone'] = phoneFilter;
      if (visitsFilter.isNotEmpty) query['visits'] = visitsFilter;
      if (hasNotesFilter.isNotEmpty) query['hasNotes'] = hasNotesFilter;
      final data = await staffClient.get('/admin/users', query: query);
      setState(() {
        customers = asMapList(data['users'] ?? data['customers']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _impersonate(Map<String, dynamic> c) async {
    final lang = ref.read(localeCodeProvider);
    final id = idOf(c);
    if (id.isEmpty) return;
    try {
      final response = await staffClient.post('/admin/users/$id/impersonate');
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      final name = personName(c, lang, fallbackId: id);
      if (token.isEmpty) {
        if (mounted) v2Toast(context, lang == 'ar' ? 'لا يوجد رمز' : 'No token returned', error: true);
        return;
      }
      ref.read(staffSessionProvider.notifier).startImpersonation(
            id: id,
            name: name,
            token: token,
            kind: 'customer',
          );
      if (mounted) context.go(V2Paths.impersonateSubject(id, kind: 'customer'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'users.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    final canImpersonate = staffCan(staffState.effectiveRole, 'users.impersonate');

    return ColoredBox(
      color: Ops.page,
      child: Column(
        children: [
          V2PageHeader(
            title: lang == 'ar' ? 'العميلات' : 'Customers',
            lang: lang,
            resultCount: loading ? null : customers.length,
            actions: [
              TextButton(
                onPressed: () => setState(() => showAdvanced = !showAdvanced),
                child: Text(showAdvanced
                    ? (lang == 'ar' ? 'إخفاء الفلاتر' : 'Hide filters')
                    : (lang == 'ar' ? 'فلاتر متقدمة' : 'Advanced')),
              ),
            ],
            filters: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  onChanged: (q) {
                    searchQuery = q;
                    _loadCustomers();
                  },
                  decoration: InputDecoration(
                    hintText: lang == 'ar' ? 'بحث في العميلات...' : 'Search customers...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Ops.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ops.radiusCtl)),
                  ),
                ),
                if (showAdvanced) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                        SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: areaFilter,
                          decoration: InputDecoration(
                            labelText: lang == 'ar' ? 'المنطقة' : 'Area',
                            filled: true,
                            fillColor: Ops.card,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ops.radiusCtl)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            DropdownMenuItem(value: '', child: Text(lang == 'ar' ? 'الكل' : 'Any')),
                            for (final a in _filterAreas)
                              DropdownMenuItem(value: a, child: Text(areaName(a, lang))),
                          ],
                          onChanged: (v) {
                            setState(() => areaFilter = v ?? '');
                            _loadCustomers();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _phoneCtrl,
                          onChanged: (v) {
                            phoneFilter = v.trim();
                            _loadCustomers();
                          },
                          decoration: InputDecoration(
                            labelText: lang == 'ar' ? 'الهاتف' : 'Phone',
                            filled: true,
                            fillColor: Ops.card,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ops.radiusCtl)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(lang == 'ar' ? 'الزيارات' : 'Visits', style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in [
                        ('', lang == 'ar' ? 'أي' : 'Any'),
                        ('any', lang == 'ar' ? 'يوجد' : 'Has visits'),
                        ('none', lang == 'ar' ? 'لا يوجد' : 'None'),
                        ('live', lang == 'ar' ? 'مباشر' : 'Live'),
                        ('done', lang == 'ar' ? 'مكتمل' : 'Done'),
                        ('dispute', lang == 'ar' ? 'نزاع' : 'Dispute'),
                      ])
                        V2FilterChip(
                          label: f.$2,
                          selected: visitsFilter == f.$1,
                          onTap: () {
                            setState(() => visitsFilter = visitsFilter == f.$1 ? '' : f.$1);
                            _loadCustomers();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(lang == 'ar' ? 'ملاحظات' : 'Notes', style: const TextStyle(fontSize: 12, color: Ops.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in [
                        ('', lang == 'ar' ? 'أي' : 'Any'),
                        ('1', lang == 'ar' ? 'بها ملاحظات' : 'Has notes'),
                        ('0', lang == 'ar' ? 'بدون' : 'No notes'),
                      ])
                        V2FilterChip(
                          label: f.$2,
                          selected: hasNotesFilter == f.$1,
                          onTap: () {
                            setState(() => hasNotesFilter = hasNotesFilter == f.$1 ? '' : f.$1);
                            _loadCustomers();
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const V2Loading()
                : error != null
                    ? Center(child: V2ErrorBanner(message: error!, onRetry: _loadCustomers))
                    : customers.isEmpty
                        ? const V2Empty()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              V2Card(
                                padding: EdgeInsets.zero,
                                child: V2DataTable(
                                  headers: [
                                    lang == 'ar' ? 'العميلة' : 'Customer',
                                    lang == 'ar' ? 'الهاتف' : 'Phone',
                                    lang == 'ar' ? 'المنطقة' : 'Area',
                                    lang == 'ar' ? 'الحجوزات' : 'Bookings',
                                    lang == 'ar' ? 'آخر حالة' : 'Last status',
                                    lang == 'ar' ? 'التسجيل' : 'Joined',
                                    lang == 'ar' ? 'إجراءات' : 'Actions',
                                  ],
                                  rows: [
                                    for (final c in customers)
                                      [
                                        identityCell(personName(c, lang, fallbackId: idOf(c)), shortId(idOf(c))),
                                        Text('${c['phone'] ?? ''}', style: const TextStyle(fontSize: 12, fontFamily: Ops.mono)),
                                        Text(areaLabel(c['area'] ?? c['areaName'], lang)),
                                        Text('${asInt(c['bookingCount'])}', style: const TextStyle(fontFamily: Ops.mono)),
                                        Text(statusLabel('${c['lastStatus'] ?? ''}', lang)),
                                        Text(formatDay(c['createdAt'], lang), style: const TextStyle(fontSize: 12, color: Ops.muted)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (canImpersonate)
                                              IconButton(
                                                tooltip: lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate',
                                                onPressed: () => _impersonate(c),
                                                icon: const Icon(Icons.login, size: 18),
                                              ),
                                            TextButton(
                                              onPressed: () => context.go(V2Paths.customer(idOf(c))),
                                              child: Text(lang == 'ar' ? 'فتح' : 'Open'),
                                            ),
                                          ],
                                        ),
                                      ],
                                  ],
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
