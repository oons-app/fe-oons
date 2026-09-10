import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';

class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key, required this.docId});

  final String docId;

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  Map? doc;
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final d = await ref.read(repoProvider).legalDoc(widget.docId);
      if (mounted) setState(() => doc = d);
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0,
                        1,
                        1,
                      ),
                      child: const Glyph(GlyphKind.back, size: 20),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      doc?['title']?.toString() ?? (lang == 'ar' ? 'المستند' : 'Document'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: Client.plum))
                  : err != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(err!, textAlign: TextAlign.center, style: const TextStyle(color: T.danger)),
                                const SizedBox(height: 16),
                                ClientGhostButton(label: lang == 'ar' ? 'حاولي تاني' : 'Try again', onTap: _load),
                                const SizedBox(height: 12),
                                ClientGhostButton(
                                  label: lang == 'ar' ? 'افتحي على الموقع' : 'Open on the website',
                                  onTap: () => openExternal(legalPageUrl(widget.docId)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            if (doc?['summary'] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Text('${doc!['summary']}', style: const TextStyle(fontSize: 14, height: 1.5, color: Client.muted)),
                              ),
                            ...((doc?['sections'] as List?) ?? []).map((s) {
                              final m = s as Map;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${m['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    Text('${m['body']}', style: const TextStyle(fontSize: 14, height: 1.55, color: Client.body)),
                                  ],
                                ),
                              );
                            }),
                            if (doc?['version'] != null)
                              Text(
                                lang == 'ar' ? 'الإصدار: ${doc!['version']}' : 'Version: ${doc!['version']}',
                                style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: Client.muted),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
