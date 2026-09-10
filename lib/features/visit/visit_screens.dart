import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/glyphs.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/track_socket.dart';
import 'package:oons/features/visit/track_map.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

class VisitScreen extends ConsumerStatefulWidget {
  const VisitScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  BookingBundle? data;
  int hs = 0;
  Timer? poll;
  Timer? qrRefresh;
  TrackSocket? track;
  String? qrPayload;
  bool qrBusy = false;
  String? qrError;

  @override
  void initState() {
    super.initState();
    _load();
    poll = Timer.periodic(const Duration(seconds: 25), (_) => _load());
    qrRefresh = Timer.periodic(const Duration(minutes: 4), (_) => _refreshQr(force: true));
    _listenTrack();
  }

  void _listenTrack() {
    final token = ref.read(sessionProvider).token;
    if (token == null) return;
    track?.stop();
    track = TrackSocket(
      bookingId: widget.bookingId,
      token: token,
      onFix: (f) {
        if (!mounted) return;
        if (f.lat == 0 && f.lng == 0) return;
        final cur = data;
        if (cur == null) {
          return;
        }
        setState(() => data = cur.withLocation(f.lat, f.lng));
      },
    )..start();
  }

  @override
  void dispose() {
    poll?.cancel();
    qrRefresh?.cancel();
    track?.stop();
    super.dispose();
  }

  bool _handshakeLive(String? status) =>
      status == 'paid' || status == 'rescheduled' || status == 'on_the_way' || status == 'in_progress';

  bool _canFetchQr(Booking? b) {
    if (b == null) return false;
    if (b.providerCheckIn != null) return false;
    return b.status == 'paid' || b.status == 'rescheduled' || b.status == 'on_the_way' || b.status == 'in_progress';
  }

  Future<void> _load() async {
    final b = await ref.read(repoProvider).booking(widget.bookingId);
    if (!mounted) return;
    setState(() {
      data = b;
      _syncHandshakeState(b.booking);
    });
    if (b.booking.status == 'completed' || b.booking.status == 'cancelled_client' || b.booking.status == 'cancelled_provider') {
      poll?.cancel();
    }
    if (_canFetchQr(b.booking)) {
      _refreshQr();
    }
  }

  void _syncHandshakeState(Booking b) {
    if (b.clientCheckIn != null && b.providerCheckIn != null) {
      hs = 3;
    } else if (b.clientCheckIn != null) {
      hs = 2;
    } else if (qrPayload != null && qrPayload!.isNotEmpty) {
      hs = 1;
    } else {
      hs = 0;
    }
  }

  Future<Position?> _clientPosition(String lang) async {
    try {
      return await currentPosition();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(geoMessage(e, lang))));
      }
      return null;
    }
  }

  Future<void> _refreshQr({bool force = false}) async {
    final b = data?.booking;
    if (!_canFetchQr(b)) return;
    if (qrBusy) return;
    if (!force && qrPayload != null && qrPayload!.isNotEmpty) return;
    final lang = langOf(ref);
    setState(() {
      qrBusy = true;
      qrError = null;
    });
    try {
      final pos = await _clientPosition(lang);
      if (pos == null) {
        setState(() => qrError = lang == 'ar' ? 'فعّلي الموقع عشان يظهر الـ QR.' : 'Turn on location to show your QR.');
        return;
      }
      final r = await ref.read(repoProvider).handshakeQr(widget.bookingId, lat: pos.latitude, lng: pos.longitude);
      final qr = '${r['qr'] ?? ''}';
      if (qr.isEmpty) throw StateError('empty qr');
      final fresh = await ref.read(repoProvider).booking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        qrPayload = qr;
        qrError = null;
        data = fresh;
        _syncHandshakeState(fresh.booking);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => qrError = friendlyError(e, lang));
    } finally {
      if (mounted) setState(() => qrBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final tr = t['track'] as Map;
    final sf = t['safety'] as Map;
    final b = data?.booking;
    final p = data?.provider;
    final labels = (tr['labels'] as List)[hs.clamp(0, 3)] as List;
    final captions = (tr['captions'] as List).cast<String>();
    final both = hs >= 3;
    final youOn = hs >= 2;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: lang == 'ar' ? 'الزيارة' : 'The visit', onBack: () => context.go('/bookings')),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Client.sand,
                      border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClientKicker('${tr['kicker']}', color: Client.plum),
                        const SizedBox(height: 8),
                        Text(
                          p == null ? '' : (lang == 'ar' ? '${p.name(lang)} في الطريق.' : '${p.name(lang)} is on the way.'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(b == null ? '' : formatSlot(b.slotStart, lang), style: const TextStyle(fontSize: 13, color: Client.body)),
                        const SizedBox(height: 14),
                        if (b != null && (b.status == 'on_the_way' || b.status == 'in_progress'))
                          VisitMap(booking: b, lang: lang)
                        else
                          Container(height: 8, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.plum)),
                        if (b?.notes != null && b!.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(b.notes!, style: const TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Face(id: p?.id, ini: p?.initials.of(lang) ?? '', size: 52, photo: p?.photo),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p?.name(lang) ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(p?.specialty.of(lang) ?? '', style: const TextStyle(fontSize: 12, color: Client.muted)),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                          child: const Icon(Icons.phone_outlined, size: 18),
                        ),
                      ],
                    ),
                  ),
                  if (b != null && _handshakeLive(b.status))
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClientKicker('${tr['ritualTitle']}'),
                          const SizedBox(height: 10),
                          Text(
                            (b.status == 'paid' || b.status == 'rescheduled') && (qrPayload == null || qrPayload!.isEmpty)
                                ? '${tr['qrWaiting']}'
                                : '${tr['qrHint']}',
                            style: const TextStyle(fontSize: 12, height: 1.45, color: Client.muted),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
                            child: Column(
                              children: [
                                if (both)
                                  const Icon(Icons.handshake_outlined, size: 48, color: Client.olive)
                                else if (qrPayload != null && qrPayload!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.bg),
                                    child: QrImageView(
                                      data: qrPayload!,
                                      size: 180,
                                      backgroundColor: Client.bg,
                                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    ),
                                  )
                                else if (qrError != null)
                                  SizedBox(
                                    height: 180,
                                    child: InkWell(
                                      onTap: () => _refreshQr(force: true),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text('${tr['qrError']}\n$qrError', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: T.danger, height: 1.45)),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 180,
                                    child: Center(
                                      child: qrBusy
                                          ? const CircularProgressIndicator(color: Client.plum)
                                          : (b.status == 'paid' || b.status == 'rescheduled')
                                              ? Text('${tr['qrWaiting']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.45))
                                              : InkWell(
                                                  onTap: () => _refreshQr(force: true),
                                                  child: Text('${tr['qrError']}', style: const TextStyle(fontSize: 12, color: Client.muted)),
                                                ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 72,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AnimatedContainer(
                                          duration: T.dState,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: youOn ? Client.olive : Client.card,
                                            border: Border.all(color: Client.ink, width: Client.rule),
                                          ),
                                          alignment: AlignmentDirectional.centerStart,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClientKicker('${tr['you']}', color: youOn ? Client.bg : Client.muted),
                                              Text('${labels[0]}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: youOn ? Client.bg : Client.ink)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      AnimatedContainer(duration: T.dArrival, width: both ? 10 : 24, height: 2, color: both ? Client.ink : Client.line),
                                      Expanded(
                                        child: Opacity(
                                          opacity: youOn ? 1 : 0.4,
                                          child: AnimatedContainer(
                                            duration: T.dState,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: both ? Client.olive : Client.card,
                                              border: Border.all(color: Client.ink, width: Client.rule),
                                            ),
                                            alignment: AlignmentDirectional.centerStart,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ClientKicker(p?.firstName.of(lang) ?? '', color: both ? Client.bg : Client.muted),
                                                Text('${labels[1]}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: both ? Client.bg : Client.ink)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                LinearProgressIndicator(
                                  value: [0.0, 0.45, 0.7, 1.0][hs.clamp(0, 3)],
                                  minHeight: 4,
                                  backgroundColor: Client.line,
                                  color: both ? Client.olive : Client.plum,
                                ),
                                const SizedBox(height: 12),
                                Align(alignment: AlignmentDirectional.centerStart, child: Text(captions[hs.clamp(0, 3)], style: const TextStyle(fontSize: 13, height: 1.45))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        _safety('${sf['share']}', '2', Client.card, Client.ink, Client.olive, () => context.push('/share/${widget.bookingId}')),
                        _safety('${sf['call']}', '${sf['callMeta']}', Client.card, Client.ink, Client.olive, () {}),
                        _safety('${sf['sos']}', '${sf['sosMeta']}', T.danger, Client.bg, Client.bg, () => _sos(lang)),
                        if (b?.status == 'in_progress') ...[
                          const SizedBox(height: 12),
                          ClientPrimaryButton(label: '${(t['rate'] as Map)['checkout']}', onTap: () async {
                            await ref.read(repoProvider).checkout(widget.bookingId);
                            if (context.mounted) context.go('/rate/${widget.bookingId}');
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sos(String lang) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      double? lat;
      double? lng;
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      }
      await ref.read(repoProvider).sos(widget.bookingId, lat: lat, lng: lng);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang == 'ar' ? 'المساعدة في الطريق.' : 'Help is on the way.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
    }
  }

  Widget _safety(String label, String meta, Color bg, Color fg, Color chip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: bg),
          child: Row(
            children: [
              Container(width: 12, height: 12, color: chip, margin: const EdgeInsetsDirectional.only(end: 10)),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
              Text(meta, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final selected = <String>{'c1', 'c2'};
  List<Map<String, dynamic>> contacts = [];

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).contacts().then((c) {
      if (mounted) setState(() => contacts = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final s = Copy.of(lang)['share'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientBackHeader(title: lang == 'ar' ? 'شاركي الزيارة' : 'Share visit', onBack: () => context.pop()),
              const SizedBox(height: 12),
              Text('${s['title']}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text('${s['body']}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ...contacts.map((c) {
                final id = '${c['id']}';
                final on = selected.contains(id);
                return InkWell(
                  onTap: () => setState(() => on ? selected.remove(id) : selected.add(id)),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: const Border(bottom: BorderSide(color: Client.line, width: Client.rule)),
                      color: on ? Client.plumTint : Client.bg,
                    ),
                    child: Row(
                      children: [
                        AvatarIni('${c['initials']}', size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Loc.fromJson(c['name']).of(lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              Ltr(child: Text('${c['phone']}', style: const TextStyle(fontSize: 11, color: Client.muted))),
                            ],
                          ),
                        ),
                        Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Colors.transparent)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text('${s['note']}', style: const TextStyle(fontSize: 12, height: 1.5, color: Client.muted)),
              const Spacer(),
              ClientPrimaryButton(
                label: '${s['cta']}',
                onTap: () async {
                  await ref.read(repoProvider).share(widget.bookingId, selected.toList());
                  if (context.mounted) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int stars = 0;
  final tags = <int>{};
  bool releasePay = true;
  bool busy = false;
  final photos = <Uint8List>[];
  BookingBundle? data;

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).booking(widget.bookingId).then((b) {
      if (mounted) setState(() => data = b);
    });
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => photos.add(Uint8List.fromList(bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final r = Copy.of(lang)['rate'] as Map;
    final tagList = (r['tags'] as List).cast<String>();
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientBackHeader(title: lang == 'ar' ? 'قيّمي الزيارة' : 'Rating', onBack: () => context.go('/home')),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text('${r['title']}', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 10),
                      Text('${r['sub']}', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 22),
                      Row(
                        children: List.generate(5, (i) {
                          final n = i + 1;
                          final on = stars >= n;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => setState(() => stars = n),
                                child: Container(
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Client.card),
                                  child: Text('$n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? Client.bg : Client.ink)),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      ClientKicker('${r['tagsTitle']}'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(tagList.length, (i) {
                          final on = tags.contains(i);
                          return InkWell(
                            onTap: () => setState(() => on ? tags.remove(i) : tags.add(i)),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.ink : Client.bg),
                              alignment: Alignment.center,
                              child: Text(tagList[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Client.bg : Client.ink)),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 22),
                      ClientKicker('${r['addPhotos']}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...photos.asMap().entries.map((e) => Stack(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                                    child: Image.memory(photos[e.key], fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: () => setState(() => photos.removeAt(e.key)),
                                      child: Container(color: T.danger, padding: const EdgeInsets.all(2), child: const Icon(Icons.close, size: 14, color: Client.bg)),
                                    ),
                                  ),
                                ],
                              )),
                          InkWell(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 72,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
                              child: const Text('+', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                      if (data?.booking.canReleasePay == true) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => setState(() => releasePay = !releasePay),
                          child: Row(
                            children: [
                              Container(width: 18, height: 18, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: releasePay ? Client.plum : Colors.transparent)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${r['releaseCta']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            ],
                          ),
                        ),
                        if (releasePay)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${r['releaseNote']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                          ),
                      ],
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
                        child: Text('${r['note']}', style: const TextStyle(fontSize: 12, height: 1.5)),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              ClientPrimaryButton(
                label: '${r['submit']}',
                enabled: stars > 0 && !busy,
                onTap: () async {
                  setState(() => busy = true);
                  try {
                    final repo = ref.read(repoProvider);
                    final urls = <String>[];
                    for (final bytes in photos) {
                      final url = await repo.uploadReviewPhoto(widget.bookingId, bytes);
                      if (url.isNotEmpty) urls.add(url);
                    }
                    await repo.rate(
                      widget.bookingId,
                      stars,
                      tags.map((i) => tagList[i]).toList(),
                      images: urls,
                      release: releasePay && (data?.booking.canReleasePay == true),
                    );
                    tapSuccess();
                    if (context.mounted) context.go('/home');
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CancelScreen extends ConsumerStatefulWidget {
  const CancelScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<CancelScreen> createState() => _CancelScreenState();
}

class _CancelScreenState extends ConsumerState<CancelScreen> {
  BookingBundle? data;
  String refundTo = 'card';

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).booking(widget.bookingId).then((b) {
      if (mounted) setState(() => data = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final c = Copy.of(lang)['cancel'] as Map;
    final b = data?.booking;
    final p = data?.preview;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientBackHeader(title: lang == 'ar' ? 'تلغي؟' : 'Cancel', onBack: () => context.pop()),
              const SizedBox(height: 12),
              Text('${c['title']}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              if (p != null)
                Text(
                  lang == 'ar' ? 'ده اللي هيرجعلك حسب الوقت دلوقتي.' : 'Here is exactly what you get back, based on the time now.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              if (p != null)
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                  child: Column(
                    children: [
                      _tier(lang == 'ar' ? 'إنتي هنا' : 'You are here', money(p.refundAmount, lang), p.tier == 'full' ? (lang == 'ar' ? 'قبل الزيارة بأكتر من ٤٨ ساعة.' : 'More than 48 hours before.') : p.tier == 'partial' ? (lang == 'ar' ? 'النص.' : 'Half, because her day is blocked.') : (lang == 'ar' ? 'مفيش رجوع.' : 'No refund.'), Client.olive, Client.bg),
                      _tier('12–48h', money((b?.total ?? 0) ~/ 2, lang), '', Client.bg, Client.ink),
                      _tier(lang == 'ar' ? 'أقل من ١٢ س' : 'Under 12h', lang == 'ar' ? 'مفيش رجوع' : 'No refund', '', T.dangerTint, Client.ink),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              ClientKicker('${c['refundTo']}'),
              const SizedBox(height: 10),
              _opt('card', '${c['card']}', '${c['cardNote']}'),
              const Spacer(),
              ClientPrimaryButton(
                label: lang == 'ar' ? 'الغي ورجّعي ${money(p?.refundAmount ?? 0, lang)}' : 'Cancel and refund ${money(p?.refundAmount ?? 0, lang)}',
                onTap: () async {
                  final r = await ref.read(repoProvider).cancel(widget.bookingId, refundTo);
                  tapSuccess();
                  if (context.mounted) context.go('/booking/${r.booking.id}');
                },
              ),
              const SizedBox(height: 4),
              ClientGhostButton(label: '${c['keep']}', onTap: () => context.pop()),
              if (b != null && !b.rescheduleUsed) ...[
                const SizedBox(height: 4),
                ClientGhostButton(label: '${c['reschedCta']}', onTap: () => context.push('/reschedule/${widget.bookingId}')),
              ],
              const SizedBox(height: 12),
              Text('${c['resched']}', style: const TextStyle(fontSize: 12, height: 1.5, color: Client.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tier(String when, String amount, String note, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: Client.ink, width: Client.rule)),
      ),
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(when, style: TextStyle(fontFamily: T.mono, fontSize: 11, color: fg))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                if (note.isNotEmpty) Text(note, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opt(String id, String name, String note) {
    final on = refundTo == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => refundTo = id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule), color: on ? Client.plumTint : Client.card),
          child: Row(
            children: [
              Container(width: 16, height: 16, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.plum : Colors.transparent)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(note, style: const TextStyle(fontSize: 12, color: Client.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderCancelScreen extends ConsumerWidget {
  const ProviderCancelScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final pc = Copy.of(lang)['pc'] as Map;
    return FutureBuilder<BookingBundle>(
      future: ref.read(repoProvider).booking(bookingId),
      builder: (context, snap) {
        final alt = snap.data?.replacement;
        return Scaffold(
          backgroundColor: Client.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClientBackHeader(title: lang == 'ar' ? 'المتخصصة لغت' : 'Provider cancelled', onBack: () => context.go('/home')),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: T.danger,
                    child: ClientKicker('${pc['badge']}', color: Client.bg),
                  ),
                  const SizedBox(height: 16),
                  Text('${pc['title']}', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  if (alt != null)
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(alignment: AlignmentDirectional.centerStart, child: ClientKicker('${pc['foundTitle']}', color: Client.plum)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Face(id: alt.provider.id, ini: alt.provider.initials.of(lang), size: 56, photo: alt.provider.photo),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(alt.provider.name(lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      Text(alt.provider.specialty.of(lang), style: const TextStyle(fontSize: 12, color: Client.muted)),
                                      Text(alt.delta.of(lang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Client.plum)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    await ref.read(repoProvider).acceptReplacement(bookingId);
                                    if (context.mounted) context.go('/visit/$bookingId');
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 52),
                                    color: Client.plum,
                                    alignment: AlignmentDirectional.centerStart,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('${pc['accept']}', style: const TextStyle(color: Client.bg, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    await ref.read(repoProvider).declineReplacement(bookingId);
                                    if (context.mounted) context.go('/booking/$bookingId');
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(minHeight: 52),
                                    alignment: AlignmentDirectional.centerStart,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: const BoxDecoration(
                                      color: Client.bg,
                                      border: Border(top: BorderSide(color: Client.ink, width: Client.rule)),
                                    ),
                                    child: Text('${pc['decline']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.oliveTint),
                    child: Row(
                      children: [
                        const Glyph(GlyphKind.shield, size: 16, color: Client.olive),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${pc['comp']}', style: const TextStyle(fontSize: 13, height: 1.45))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DisputeScreen extends ConsumerStatefulWidget {
  const DisputeScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  final reason = TextEditingController();
  bool busy = false;
  bool done = false;

  @override
  void initState() {
    super.initState();
    ref.read(repoProvider).booking(widget.bookingId).then((b) {
      if (mounted) setState(() => done = b.booking.status == 'disputed');
    });
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final d = Copy.of(lang)['dispute'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientBackHeader(title: lang == 'ar' ? 'اعتراض' : 'Dispute', onBack: () => context.pop()),
              const SizedBox(height: 12),
              Text('${d['title']}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(done ? '${d['done']}' : '${d['body']}', style: Theme.of(context).textTheme.bodyMedium),
              if (!done) ...[
                const SizedBox(height: 20),
                ClientKicker('${d['reason']}'),
                const SizedBox(height: 8),
                TextField(
                  controller: reason,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Client.card,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.ink, width: Client.rule)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Client.plum, width: Client.rule)),
                  ),
                ),
              ],
              const Spacer(),
              if (done)
                ClientPrimaryButton(label: lang == 'ar' ? 'تمام' : 'Done', onTap: () => context.go('/booking/${widget.bookingId}'))
              else
                ClientPrimaryButton(
                  label: '${d['cta']}',
                  enabled: !busy,
                  onTap: () async {
                    setState(() => busy = true);
                    try {
                      await ref.read(repoProvider).dispute(widget.bookingId, reason: reason.text);
                      tapSuccess();
                      if (mounted) setState(() => done = true);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RescheduleScreen extends ConsumerStatefulWidget {
  const RescheduleScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  BookingBundle? data;
  List<Map<String, dynamic>> days = [];
  int day = 1;
  int slot = 2;
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final b = await repo.booking(widget.bookingId);
    final av = b.provider == null ? <Map<String, dynamic>>[] : await repo.availability(b.provider!.id);
    if (!mounted) return;
    setState(() {
      data = b;
      days = av;
    });
  }

  DateTime slotTime() {
    if (days.isEmpty) return DateTime.now().toUtc();
    final dayMap = days[day] as Map<String, dynamic>;
    final slots = dayMap['slots'] as List;
    return availabilitySlotUtc(dayMap, slots[slot] as Map);
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final r = Copy.of(lang)['reschedule'] as Map;
    final used = data?.booking.rescheduleUsed == true;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientBackHeader(title: lang == 'ar' ? 'أجّلي الميعاد' : 'Reschedule', onBack: () => context.pop()),
              const SizedBox(height: 12),
              Text('${r['title']}', style: Theme.of(context).textTheme.headlineMedium),
              if (used) ...[
                const SizedBox(height: 12),
                Text('${r['used']}', style: const TextStyle(color: T.danger)),
              ],
              const SizedBox(height: 16),
              if (days.isNotEmpty && !used)
                Row(
                  children: List.generate(days.length.clamp(0, 5), (i) {
                    final on = day == i;
                    final date = DateTime.tryParse('${days[i]['date']}') ?? DateTime.now();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setState(() => day = i),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: on ? Client.ink : Client.card),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${date.day}'.padLeft(2, '0'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? Client.bg : Client.ink)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              const SizedBox(height: 12),
              if (days.isNotEmpty && !used)
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 2.2,
                  children: List.generate((days[day]['slots'] as List).length, (i) {
                    final s = (days[day]['slots'] as List)[i] as Map;
                    final avail = s['available'] != false;
                    final on = slot == i;
                    return Opacity(
                      opacity: avail ? 1 : 0.35,
                      child: InkWell(
                        onTap: avail ? () => setState(() => slot = i) : null,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: on ? Client.plum : Client.ink, width: Client.rule),
                            color: on ? Client.plum : Client.card,
                          ),
                          child: Text(availabilitySlotLabel(s, lang), style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w500, color: on ? Client.bg : Client.ink)),
                        ),
                      ),
                    );
                  }),
                ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: T.danger))),
              const Spacer(),
              ClientPrimaryButton(
                label: '${r['cta']}',
                enabled: !busy && !used && days.isNotEmpty,
                onTap: () async {
                  setState(() => busy = true);
                  try {
                    final b = await ref.read(repoProvider).reschedule(widget.bookingId, slotTime());
                    tapSuccess();
                    if (mounted) context.go('/booking/${b.booking.id}');
                  } catch (e) {
                    setState(() => err = friendlyError(e, lang));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
