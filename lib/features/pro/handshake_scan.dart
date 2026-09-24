import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:go_router/go_router.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

String? handshakeCodeFromInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 4) return null;
  return digits;
}

class HandshakeScanScreen extends ConsumerStatefulWidget {
  const HandshakeScanScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<HandshakeScanScreen> createState() => _HandshakeScanScreenState();
}

class _HandshakeScanScreenState extends ConsumerState<HandshakeScanScreen> {
  String code = '';
  bool busy = false;
  bool done = false;
  String? err;

  Future<Position?> _providerPosition(String lang) async {
    try {
      return await currentPosition();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(geoMessage(e, lang))));
      }
      return null;
    }
  }

  void _digit(String d) {
    if (busy || done || code.length >= 4) return;
    setState(() {
      code += d;
      err = null;
    });
    if (code.length == 4) {
      _submit();
    }
  }

  void _backspace() {
    if (busy || done || code.isEmpty) return;
    setState(() {
      code = code.substring(0, code.length - 1);
      err = null;
    });
  }

  Future<void> _submit() async {
    if (busy || done) return;
    final parsed = handshakeCodeFromInput(code);
    if (parsed == null) return;
    setState(() => busy = true);
    final lang = langOf(ref);
    try {
      final pos = await _providerPosition(lang);
      if (pos == null) {
        setState(() => busy = false);
        return;
      }
      await ref.read(repoProvider).proHandshake(widget.bookingId, parsed, lat: pos.latitude, lng: pos.longitude);
      tapSuccess();
      if (!mounted) return;
      setState(() => done = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Copy.of(lang)['pro']['scanDone']}')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        code = '';
        err = friendlyError(e, lang);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    return Scaffold(
      backgroundColor: Pro.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHead(title: '${p['scanHandshake']}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text('${p['scanHint']}', style: const TextStyle(fontSize: 13, height: 1.45, color: Pro.soft)),
                  const SizedBox(height: 28),
                  Ltr(child: ClientOtpBoxes(code: code, error: err != null)),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(err!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.4, color: T.danger)),
                  ],
                  const SizedBox(height: 24),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: Pro.plum)),
                    )
                  else
                    ClientNumpad(onDigit: _digit, onBackspace: _backspace, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
