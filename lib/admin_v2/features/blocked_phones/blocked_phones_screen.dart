import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/data/api.dart';

class BlockedPhonesScreen extends ConsumerStatefulWidget {
  const BlockedPhonesScreen({super.key});

  @override
  ConsumerState<BlockedPhonesScreen> createState() => _BlockedPhonesScreenState();
}

class _BlockedPhonesScreenState extends ConsumerState<BlockedPhonesScreen> {
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  bool loading = true;
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> phones = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/blocked-phones');
      if (!mounted) return;
      setState(() {
        phones = asMapList(data['phones']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is ApiException ? e.message : '$e';
      });
    }
  }

  Future<void> _block() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await staffClient.post('/admin/blocked-phones', data: {
        'phone': phone,
        'reason': _reason.text.trim(),
      });
      _phone.clear();
      _reason.clear();
      if (mounted) v2Toast(context, _ar ? 'تم إيقاف الرقم' : 'Number blocked');
      await _load();
    } catch (e) {
      if (mounted) v2Toast(context, e is ApiException ? e.message : '$e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _unblock(String phone) async {
    try {
      await staffClient.delete('/admin/blocked-phones/$phone');
      if (mounted) v2Toast(context, _ar ? 'تم فك الإيقاف' : 'Number unblocked');
      await _load();
    } catch (e) {
      if (mounted) v2Toast(context, e is ApiException ? e.message : '$e', error: true);
    }
  }

  bool get _ar => ref.read(localeCodeProvider) == 'ar';

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final ar = lang == 'ar';
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      children: [
        V2PageHeader(
          title: ar ? 'أرقام موقوفة' : 'Blocked numbers',
          lang: lang,
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ar
                      ? 'الرقم الموقوف لا يقدر يطلب رمز الدخول، ولا يسجّل، وأي جلسة مفتوحة له تتوقف.'
                      : 'A blocked number cannot request a code, register, or keep an open session.',
                  style: const TextStyle(fontSize: 13, color: Ops.muted, height: 1.45),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: ar ? 'رقم الموبايل' : 'Mobile number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  decoration: InputDecoration(labelText: ar ? 'السبب (اختياري)' : 'Reason (optional)'),
                ),
                const SizedBox(height: 12),
                V2Btn.primary(ar ? 'إيقاف الرقم' : 'Block number', onPressed: saving ? null : _block),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(error!, style: const TextStyle(color: Ops.terracotta)))
        else if (phones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(ar ? 'مفيش أرقام موقوفة.' : 'No blocked numbers.', style: const TextStyle(color: Ops.muted)),
          )
        else
          for (final row in phones)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: V2Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row['phone'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          if ('${row['reason'] ?? ''}'.isNotEmpty)
                            Text('${row['reason']}', style: const TextStyle(fontSize: 13, color: Ops.muted)),
                        ],
                      ),
                    ),
                    V2Btn.danger(ar ? 'فك الإيقاف' : 'Unblock', size: V2BtnSize.sm, onPressed: () => _unblock('${row['phone'] ?? ''}')),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
