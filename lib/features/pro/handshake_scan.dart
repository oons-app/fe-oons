import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

bool _looksLikeJwt(String s) {
  if (s.contains('://')) return false;
  final p = s.split('.');
  return p.length == 3 && p.every((e) => e.isNotEmpty);
}

String? handshakeTokenFromScan(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  if (_looksLikeJwt(s)) return s;

  try {
    final decoded = Uri.decodeComponent(s);
    if (_looksLikeJwt(decoded)) return decoded;
    s = decoded;
  } catch (_) {}

  final uri = Uri.tryParse(s);
  if (uri != null && uri.scheme == 'oons' && uri.host == 'handshake') {
    final t = uri.queryParameters['t'];
    if (t != null && t.isNotEmpty && _looksLikeJwt(t)) return t;
  }

  final tIdx = s.indexOf('t=');
  if (tIdx >= 0) {
    final tail = s.substring(tIdx + 2);
    final end = tail.indexOf('&');
    final token = (end >= 0 ? tail.substring(0, end) : tail).trim();
    if (_looksLikeJwt(token)) return token;
  }

  return null;
}

class HandshakeScanScreen extends ConsumerStatefulWidget {
  const HandshakeScanScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<HandshakeScanScreen> createState() => _HandshakeScanScreenState();
}

class _HandshakeScanScreenState extends ConsumerState<HandshakeScanScreen> {
  final controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool busy = false;
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (busy || done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final token = raw == null ? null : handshakeTokenFromScan(raw);
    if (token == null) return;
    setState(() => busy = true);
    final lang = langOf(ref);
    try {
      final pos = await _providerPosition(lang);
      if (pos == null) {
        setState(() => busy = false);
        return;
      }
      await ref.read(repoProvider).proHandshake(widget.bookingId, token, lat: pos.latitude, lng: pos.longitude);
      tapSuccess();
      if (!mounted) return;
      setState(() => done = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Copy.of(lang)['pro']['scanDone']}')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHead(title: '${p['scanHandshake']}', onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('${p['scanHint']}', style: const TextStyle(fontSize: 13, height: 1.45, color: T.body)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule)),
                  child: Stack(
                    children: [
                      MobileScanner(controller: controller, onDetect: _onDetect),
                      if (busy)
                        const ColoredBox(
                          color: Color(0x88000000),
                          child: Center(child: CircularProgressIndicator(color: T.white)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
