import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class ImpersonateScreen extends ConsumerStatefulWidget {
  const ImpersonateScreen({super.key, required this.id, this.kind = 'provider'});
  final String id;
  final String kind;

  @override
  ConsumerState<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends ConsumerState<ImpersonateScreen> {
  Map? subject;
  List bookings = [];
  bool loading = true;
  String? error;

  bool get _isCustomer => widget.kind == 'customer' || widget.kind == 'user';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Ops still loads subject via staff API for full admin data.
      final path = _isCustomer ? '/admin/users/${widget.id}' : '/admin/providers/${widget.id}';
      final r = await staffClient.get(path);
      final key = _isCustomer ? 'user' : 'provider';
      final sub = r[key] is Map ? r[key] as Map : r;
      final b = await staffClient.get('/admin/bookings', query: {
        if (_isCustomer) 'clientId': widget.id else 'providerId': widget.id,
        'limit': 50,
      });
      if (!mounted) return;
      setState(() {
        subject = sub;
        bookings = b['bookings'] as List? ?? [];
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    final perm = _isCustomer ? 'users.impersonate' : 'providers.impersonate';
    final name = personName(subject, lang, fallbackId: widget.id);

    return V2Gate(
      allowed: staffCan(role, perm),
      child: loading
          ? const V2Loading()
          : error != null
              ? Padding(padding: const EdgeInsets.all(16), child: V2ErrorBanner(message: error!, onRetry: _load))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    V2Card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${t(V2Copy.impersonating, lang)} ${_isCustomer ? (lang == 'ar' ? 'عميلة' : 'customer') : (lang == 'ar' ? 'مهنية' : 'provider')} · $name',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          V2StatusPill(label: t(V2Copy.readOnly, lang), tone: V2Tone.warn),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              ref.read(staffSessionProvider.notifier).clearImpersonation();
                              context.go(_isCustomer ? V2Paths.customers : V2Paths.providers);
                            },
                            child: Text(t(V2Copy.exit, lang)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(lang == 'ar' ? 'الحجوزات' : 'Bookings', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (bookings.isEmpty)
                      const V2Empty()
                    else
                      ...bookings.map((raw) {
                        final b = raw as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: V2Card(
                            onTap: () => context.go(V2Paths.booking('${b['id']}')),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b['ref']} · ${b['status']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  '${b['slotStart'] != null ? formatSlot(DateTime.parse('${b['slotStart']}').toLocal(), lang) : ''} · ${money(asInt(b['total']), lang)}',
                                  style: const TextStyle(fontSize: 12.5, color: Ops.muted, fontFamily: Ops.mono),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
