import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/data/api.dart';

class V2LoginScreen extends ConsumerStatefulWidget {
  const V2LoginScreen({super.key});
  @override
  ConsumerState<V2LoginScreen> createState() => _V2LoginScreenState();
}

class _V2LoginScreenState extends ConsumerState<V2LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      await ref.read(staffSessionProvider.notifier).login(email.text.trim(), password.text);
      if (mounted) context.go(V2Paths.home);
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) v2Toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    return Scaffold(
      backgroundColor: Ops.page,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Ops.card,
              borderRadius: BorderRadius.circular(Ops.radiusCard),
              border: Border.all(color: Ops.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Ops.creamTile, borderRadius: BorderRadius.circular(12)),
                    child: const Text('أُنس', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Ops.plum)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(V2Copy.backOffice, lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  decoration: InputDecoration(labelText: t(V2Copy.email, lang)),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: InputDecoration(labelText: t(V2Copy.password, lang)),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t(V2Copy.signIn, lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
