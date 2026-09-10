import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin/api.dart';
import 'package:oons/admin/filters.dart';
import 'package:oons/admin/overlays.dart';
import 'package:oons/admin/paths.dart';
import 'package:oons/admin/session.dart';
import 'package:oons/admin/shell.dart';
import 'package:oons/admin/theme.dart';
import 'package:oons/admin/widgets.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/api.dart';
import 'package:oons/l10n/copy.dart';
import 'package:url_launcher/url_launcher.dart';

Map<String, dynamic> _copy(WidgetRef ref) => (Copy.of(langOf(ref))['admin'] as Map).cast<String, dynamic>();

int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String _when(dynamic v) {
  final s = '$v';
  if (s.length >= 16) return s.substring(0, 16).replaceFirst('T', ' ');
  return s;
}

Future<void> _openUrl(String url) async {
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

BoxDecoration get _cardDeco => BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(T.radiusLg),
      border: Border.all(color: T.line),
    );

class AdminHeatmapScreen extends ConsumerStatefulWidget {
  const AdminHeatmapScreen({super.key});
  @override
  ConsumerState<AdminHeatmapScreen> createState() => _AdminHeatmapScreenState();
}

class _AdminHeatmapScreenState extends ConsumerState<AdminHeatmapScreen> {
  List cells = [];
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/heatmap');
      final list = r['cells'] as List? ?? r['areas'] as List? ?? r['heatmap'] as List? ?? [];
      if (mounted) setState(() { cells = list; err = null; });
    } catch (e) {
      if (mounted) setState(() { cells = []; err = '$e'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    return AdminGate(
      perm: 'bookings.read',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) AdminErrorBanner(message: err!, onRetry: _load),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['heatmap']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: T.ink)),
                const SizedBox(height: 4),
                Text('${c['heatmapSub']}', style: const TextStyle(fontSize: 12, color: T.muted)),
                const SizedBox(height: 14),
                if (busy && cells.isEmpty)
                  AdminLoading(label: '${c['loading']}')
                else if (cells.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted))),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final raw in cells)
                        _HeatTile(cell: raw is Map ? raw : <String, dynamic>{}),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _HeatTile extends StatelessWidget {
  const _HeatTile({required this.cell});
  final Map cell;

  @override
  Widget build(BuildContext context) {
    final area = '${cell['area'] ?? cell['name'] ?? cell['areaName'] ?? ''}';
    final supply = _n(cell['supply'] ?? cell['pros'] ?? cell['providers']);
    final demand = _n(cell['demand'] ?? cell['requests'] ?? cell['open']);
    final fillPct = cell['fill'] != null
        ? _n(cell['fill'])
        : (demand <= 0 ? 100 : ((supply / demand) * 100).round());
    final state = fillPct >= 100 ? 'Healthy' : (fillPct >= 60 ? 'Tight' : 'Undersupplied');
    final barColor = fillPct >= 100 ? T.trustInk : (fillPct >= 60 ? T.pending : T.warm);
    final tone = fillPct >= 100 ? AdminTone.ok : (fillPct >= 60 ? AdminTone.warn : AdminTone.bad);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 196, maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: fillPct < 60 ? const Color(0xFFE0C9A8) : const Color(0xFFEBE2D6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(area, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink)),
                ),
                AdminStatusPill(label: state, tone: tone),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _Metric(label: 'Pros', value: '$supply'),
                const SizedBox(width: 16),
                _Metric(label: 'Demand', value: '$demand'),
                const SizedBox(width: 16),
                _Metric(label: 'Fill', value: '$fillPct%'),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (fillPct.clamp(0, 100)) / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFEDE4D8),
                color: barColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: T.muted)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: T.mono, color: T.ink)),
      ],
    );
  }
}

class AdminVettingSlaScreen extends ConsumerStatefulWidget {
  const AdminVettingSlaScreen({super.key});
  @override
  ConsumerState<AdminVettingSlaScreen> createState() => _AdminVettingSlaScreenState();
}

class _AdminVettingSlaScreenState extends ConsumerState<AdminVettingSlaScreen> {
  List pending = [];
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/vetting-sla');
      final list = r['pending'] as List? ?? r['queue'] as List? ?? r['providers'] as List? ?? [];
      if (mounted) setState(() { pending = list; err = null; });
    } catch (e) {
      if (mounted) setState(() { pending = []; err = '$e'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    return AdminGate(
      perm: 'providers.read',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null) AdminErrorBanner(message: err!, onRetry: _load),
          Container(
            decoration: _cardDeco,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(child: Text('${c['vetting']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final role = effectiveStaffRole(ref.read(staffSessionProvider));
                                final ok = await showOpsConfirm(
                                  context,
                                  title: '${c['reindexSearch']}',
                                  body: '${c['reindexConfirm'] ?? 'Rebuild provider search index?'}',
                                  confirmLabel: '${c['reindexSearch']}',
                                  roleLabel: '${c['role_$role'] ?? role}',
                                );
                                if (!ok) return;
                                try {
                                  await staffApi.post('/admin/search/reindex');
                                  if (context.mounted) opsToast(context, '${c['reindexDone']}');
                                } on ApiException catch (e) {
                                  if (context.mounted) opsToast(context, e.message, error: true);
                                }
                              },
                        child: Text('${c['reindexSearch']}'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: T.line),
                if (busy && pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: AdminLoading(label: '${c['loading']}'),
                  )
                else if (pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(38),
                    child: Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted))),
                  )
                else
                  for (var i = 0; i < pending.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFF0E9DE)),
                    _VettingRow(row: pending[i] is Map ? pending[i] as Map : {}),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _VettingRow extends StatelessWidget {
  const _VettingRow({required this.row});
  final Map row;

  @override
  Widget build(BuildContext context) {
    final id = '${row['id'] ?? row['providerId'] ?? ''}';
    final name = '${row['name'] ?? row['providerName'] ?? id}';
    final blocker = '${row['blocker'] ?? row['status'] ?? row['vetting'] ?? ''}';
    final wait = '${row['wait'] ?? row['waitDays'] ?? row['waiting'] ?? ''}';

    return InkWell(
      onTap: id.isEmpty ? null : () => context.go(AdminPaths.provider(id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink)),
                  if (blocker.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(blocker, style: const TextStyle(fontSize: 11.5, color: Color(0xFF8C7F8A))),
                  ],
                ],
              ),
            ),
            if (wait.isNotEmpty)
              Text(
                wait.contains('day') || wait.contains('d') ? wait : '$wait d',
                style: const TextStyle(fontFamily: T.mono, fontSize: 12.5, fontWeight: FontWeight.w600, color: T.body),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: id.isEmpty ? null : () => context.go(AdminPaths.provider(id)),
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBatchesScreen extends ConsumerStatefulWidget {
  const AdminBatchesScreen({super.key});
  @override
  ConsumerState<AdminBatchesScreen> createState() => _AdminBatchesScreenState();
}

class _AdminBatchesScreenState extends ConsumerState<AdminBatchesScreen> {
  List rows = [];
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final r = await staffApi.get('/admin/ops-batches');
      final list = r['batches'] as List? ?? r['rows'] as List? ?? r['items'] as List? ?? [];
      if (mounted) setState(() { rows = list; err = null; });
    } catch (e) {
      if (mounted) setState(() { rows = []; err = '$e'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    return AdminGate(
      perm: 'payouts.read',
      child: Column(
        children: [
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          if (err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AdminErrorBanner(message: err!, onRetry: _load),
            ),
          Expanded(
            child: busy && rows.isEmpty
                ? AdminLoading(label: '${c['loading']}')
                : rows.isEmpty
                    ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                    : ListView(
                        padding: adminPagePad(context),
                        children: [
                          Container(
                            decoration: _cardDeco,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < rows.length; i++) ...[
                                  if (i > 0) const Divider(height: 1, color: Color(0xFFF0E9DE)),
                                  _BatchRow(row: rows[i] is Map ? rows[i] as Map : {}, lang: lang, copy: c),
                                ],
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


class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.row, required this.lang, required this.copy});
  final Map row;
  final String lang;
  final Map copy;

  @override
  Widget build(BuildContext context) {
    final provider = '${row['providerName'] ?? row['provider'] ?? row['providerId'] ?? ''}';
    final visits = '${row['visits'] ?? row['visitCount'] ?? row['count'] ?? ''}';
    final net = row['net'] ?? row['gross'] ?? row['amount'] ?? row['providerGross'];
    final paidAt = _when(row['paidAt'] ?? row['settledAt'] ?? row['date'] ?? '');
    final excel = '${row['excelUrl'] ?? ''}';
    final receipt = '${row['receiptUrl'] ?? ''}';
    final pay = '${row['publicPayUrl'] ?? row['payUrl'] ?? row['publicUrl'] ?? ''}';
    final netLabel = net is num || int.tryParse('$net') != null ? money(_n(net), lang) : '$net';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: T.ink)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (visits.isNotEmpty) '$visits visits',
                    if (paidAt.isNotEmpty) paidAt,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: T.muted),
                ),
                if (excel.isNotEmpty || receipt.isNotEmpty || pay.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (excel.isNotEmpty)
                        TextButton(onPressed: () => _openUrl(excel), child: const Text('Excel')),
                      if (receipt.isNotEmpty)
                        TextButton(onPressed: () => _openUrl(receipt), child: Text('${copy['bulkPayPickReceipt'] ?? 'Receipt'}')),
                      if (pay.isNotEmpty)
                        TextButton(onPressed: () => _openUrl(pay), child: const Text('Pay link')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(netLabel, style: const TextStyle(fontFamily: T.mono, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}


class AdminCorporateScreen extends ConsumerStatefulWidget {
  const AdminCorporateScreen({super.key});
  @override
  ConsumerState<AdminCorporateScreen> createState() => _AdminCorporateScreenState();
}

class _AdminCorporateScreenState extends ConsumerState<AdminCorporateScreen> {
  final legalName = TextEditingController();
  final taxId = TextEditingController();
  final billingEmail = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    legalName.dispose();
    taxId.dispose();
    billingEmail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = _copy(ref);
    setState(() => busy = true);
    try {
      await staffApi.post('/admin/corporate', data: {
        'legalName': legalName.text.trim(),
        'taxId': taxId.text.trim(),
        'billingEmail': billingEmail.text.trim(),
      });
      if (mounted) adminSnack(context, '${c['saved']}');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) adminSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    return AdminGate(
      perm: 'staff.write',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${c['corporate']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 4),
                Text('${c['corporateSub']}', style: const TextStyle(fontSize: 12, color: T.muted)),
                const SizedBox(height: 16),
                TextField(
                  controller: legalName,
                  decoration: InputDecoration(labelText: '${c['legalName'] ?? 'Legal name'}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxId,
                  decoration: InputDecoration(labelText: '${c['taxId'] ?? 'Tax ID'}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: billingEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: '${c['billingEmail'] ?? 'Billing email'}'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text(busy ? '${c['loading']}' : '${c['save']}'),
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


const _matrixPerms = [
  'bookings.read',
  'bookings.write',
  'claims.read',
  'claims.write',
  'users.read',
  'providers.read',
  'providers.vet',
  'provider_categories.write',
  'payouts.read',
  'payouts.write',
  'ledger.read',
  'coupons.read',
  'coupons.write',
  'payments.settings',
  'staff.write',
  'categories.write',
  'areas.write',
  'audit.read',
  'notes.write',
  'providers.impersonate',
  'users.impersonate',
  'id.photos',
];

class AdminRoleMatrixScreen extends ConsumerWidget {
  const AdminRoleMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = _copy(ref);
    final roles = staffRoleChoices;

    return AdminGate(
      perm: 'staff.write',
      child: ListView(
        padding: adminPagePad(context),
        children: [
          Container(
            decoration: _cardDeco,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['matrix']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 4),
                      Text('${c['matrixSub']}', style: const TextStyle(fontSize: 12, color: T.muted)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: T.line),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(T.sand),
                    columns: [
                      const DataColumn(label: Text('Permission', style: TextStyle(fontWeight: FontWeight.w700))),
                      for (final r in roles)
                        DataColumn(
                          label: Text(
                            '${c['role_$r'] ?? r}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                    ],
                    rows: [
                      for (final perm in _matrixPerms)
                        DataRow(
                          cells: [
                            DataCell(Text(perm, style: const TextStyle(fontFamily: T.mono, fontSize: 12))),
                            for (final r in roles)
                              DataCell(
                                Center(
                                  child: Text(
                                    staffCan(r, perm) ? '✓' : '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: staffCan(r, perm) ? T.trustInk : T.mutedSoft,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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


class AdminImpersonateScreen extends ConsumerStatefulWidget {
  const AdminImpersonateScreen({super.key, required this.id, this.kind = 'provider'});
  final String id;
  final String kind;
  @override
  ConsumerState<AdminImpersonateScreen> createState() => _AdminImpersonateScreenState();
}

class _AdminImpersonateScreenState extends ConsumerState<AdminImpersonateScreen> {
  Map? subject;
  List bookings = [];
  String? err;
  bool busy = false;

  bool get _isCustomer => widget.kind == 'customer' || widget.kind == 'user';

  @override
  void initState() {
    super.initState();
    _loadSubject();
    _loadBookings();
  }

  Future<void> _loadSubject() async {
    setState(() { busy = true; err = null; });
    try {
      final path = _isCustomer ? '/admin/users/${widget.id}' : '/admin/providers/${widget.id}';
      final r = await staffApi.get(path);
      final key = _isCustomer ? 'user' : 'provider';
      if (mounted) {
        setState(() {
          subject = (r[key] is Map ? r[key] as Map : r) ;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { err = '$e'; busy = false; });
    }
  }

  Future<void> _loadBookings() async {
    try {
      final r = await staffApi.get('/admin/bookings', query: {
        if (_isCustomer) 'clientId': widget.id else 'providerId': widget.id,
        'limit': 50,
      });
      if (mounted) setState(() { bookings = r['bookings'] as List? ?? []; });
    } catch (_) {}
  }

  void _exitImpersonation() {
    ref.read(staffSessionProvider.notifier).clearImpersonation();
    context.go(_isCustomer ? AdminPaths.customers : AdminPaths.providers);
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(ref);
    final lang = langOf(ref);
    if (subject == null) return AdminLoading(label: err ?? '${c['loading']}');
    final name = locName(subject!['firstName'], lang);
    final kindLabel = _isCustomer ? '${c['customer'] ?? 'Customer'}' : '${c['provider'] ?? 'Provider'}';
    final perm = _isCustomer ? 'users.impersonate' : 'providers.impersonate';

    return AdminGate(
      perm: perm,
      child: Column(
        children: [
          FilterWrap(
            title: '${c['impersonateView']} • $kindLabel • $name',
            children: [
              AdminStatusPill(label: '${c['impersonateViewSub']}', tone: AdminTone.warn),
              FilterApply(label: 'Exit', onTap: _exitImpersonation),
            ],
          ),
          if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: AdminErrorBanner(message: err!, onRetry: _loadSubject)),
          if (busy) const LinearProgressIndicator(minHeight: 2, color: T.action),
          Expanded(
            child: bookings.isEmpty
                ? Center(child: Text('${c['empty']}', style: const TextStyle(color: T.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final b = bookings[i] as Map;
                      return Material(
                        color: T.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.go(AdminPaths.booking('${b['id']}')),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b['ref']} • ${c['st_${b['status']}'] ?? b['status']}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${b['slotStart'] != null ? formatSlot(DateTime.parse('${b['slotStart']}').toLocal(), lang) : ''} • ${money(_n(b['total']), lang)}',
                                  style: const TextStyle(fontSize: 12.5, color: T.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

