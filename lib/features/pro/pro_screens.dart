import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/track_socket.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/auth/auth_screens.dart' show clearPendingRegistration, pendingRegistration;
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';
import 'package:url_launcher/url_launcher.dart';

class ProRegisterScreen extends ConsumerStatefulWidget {
  const ProRegisterScreen({super.key, required this.phone, required this.code, @visibleForTesting this.initialStep = 0});
  final String phone;
  final String code;
  final int initialStep;
  @override
  ConsumerState<ProRegisterScreen> createState() => _ProRegisterScreenState();
}

class _ProRegisterScreenState extends ConsumerState<ProRegisterScreen> {
  late int step = widget.initialStep;
  final first = TextEditingController();
  final last = TextEditingController();
  final legal = TextEditingController();
  final nid = TextEditingController();
  final birth = TextEditingController(text: '1995-01-01');
  final residence = TextEditingController();
  final specialty = TextEditingController();
  final years = TextEditingController(text: '3');
  final payout = TextEditingController();
  // A provider can offer several categories (beauty, cleaning, chef), each with
  // its own specialties, in as many areas as she likes. None is pre-picked:
  // she has to say where she works.
  final services = <String>[];
  final areas = <String>{};
  final consents = <String, bool>{'terms': false, 'data': false, 'backgroundCheck': false, 'womenOnly': false, 'tax': false};
  final selectedCategories = <String>{};
  final catsByVertical = <String, List<Map<String, dynamic>>>{};
  final catsLoading = <String>{};
  final catsFailed = <String>{};
  List<int>? idBytes;
  String? idName;
  List<int>? fishBytes;
  String? fishName;
  double? uploadProgress; // 0..1 while posting ID/fish after register
  bool busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    final pending = pendingRegistration(widget.phone, widget.code);
    _phone = pending.phone;
    _code = pending.code;
    if (_phone.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
    }
    unawaited(AppAnalytics.providerRegistrationStarted());
    unawaited(refreshServiceCities(activeOnly: true, force: true).then((_) {
      if (!mounted) return;
      setState(() {
        areas.removeWhere((a) => !allCatalogAreaIds().contains(a));
      });
    }));
  }

  Future<void> _loadSpecialties(String vertical) async {
    if (catsByVertical.containsKey(vertical) || catsLoading.contains(vertical)) return;
    setState(() {
      catsLoading.add(vertical);
      catsFailed.remove(vertical);
    });
    try {
      final cats = await ref.read(repoProvider).categories(vertical: vertical, activeOnly: true);
      if (mounted) setState(() => catsByVertical[vertical] = cats);
    } catch (_) {
      if (mounted) setState(() => catsFailed.add(vertical));
    } finally {
      if (mounted) setState(() => catsLoading.remove(vertical));
    }
  }

  void _toggleService(String vertical) {
    setState(() {
      if (services.contains(vertical)) {
        services.remove(vertical);
        // Specialties belong to their category: unticking it drops them.
        for (final c in catsByVertical[vertical] ?? const <Map<String, dynamic>>[]) {
          selectedCategories.remove('${c['id']}');
        }
      } else {
        services.add(vertical);
      }
    });
    if (services.contains(vertical)) unawaited(_loadSpecialties(vertical));
  }

  /// Why step 2 ("your work") cannot continue yet, or null.
  String? _workError(Map p) {
    if (services.isEmpty) return '${p['needServices']}';
    for (final v in services) {
      final picked = (catsByVertical[v] ?? const <Map<String, dynamic>>[])
          .any((c) => selectedCategories.contains('${c['id']}'));
      if (!picked) return '${p['needSpecialties']}';
    }
    if (areas.isEmpty) return '${p['needAreas']}';
    return null;
  }

  late final String _phone;
  late final String _code;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    final svc = Copy.of(lang)['svc'] as Map;
    final titles = ['${p['stepId']}', '${p['stepWork']}', '${p['stepPay']}', '${p['stepLegal']}'];
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Kicker('${step + 1} / 4 · ${titles[step]}'),
            const SizedBox(height: 10),
            Text('${p['regTitle']}', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 10),
            Text('${p['regSub']}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (step == 0) ...[
              Kicker('${p['first']}'),
              const SizedBox(height: 8),
              _field(first),
              const SizedBox(height: 16),
              Kicker('${p['last']}'),
              const SizedBox(height: 8),
              _field(last),
              const SizedBox(height: 16),
              Kicker('${p['legalName']}'),
              const SizedBox(height: 8),
              _field(legal),
              const SizedBox(height: 16),
              Kicker('${p['nationalId']}'),
              const SizedBox(height: 8),
              _field(nid, digits: true),
              const SizedBox(height: 16),
              Kicker('${p['birth']}'),
              const SizedBox(height: 8),
              _field(birth),
              const SizedBox(height: 16),
              Kicker('${p['residence']}'),
              const SizedBox(height: 8),
              _field(residence),
              const SizedBox(height: 16),
              Kicker('${p['uploadId']}'),
              const SizedBox(height: 8),
              _docPickTile(
                lang: lang,
                emptyLabel: '${p['uploadId']}',
                readyLabel: '${p['idOnFile']}',
                bytes: idBytes,
                name: idName,
                onPick: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
                  if (file == null) return;
                  idBytes = await file.readAsBytes();
                  idName = file.name;
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Kicker('${p['uploadFish']}'),
              const SizedBox(height: 8),
              _docPickTile(
                lang: lang,
                emptyLabel: '${p['uploadFish']}',
                readyLabel: '${p['fishOnFile']}',
                bytes: fishBytes,
                name: fishName,
                onPick: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
                  if (file == null) return;
                  fishBytes = await file.readAsBytes();
                  fishName = file.name;
                  setState(() {});
                },
              ),
              if (uploadProgress != null) ...[
                const SizedBox(height: 16),
                Text(
                  lang == 'ar' ? 'جارٍ رفع الملفات…' : 'Uploading documents…',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: uploadProgress!.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: T.action,
                  backgroundColor: T.sand,
                ),
              ],
            ],
            if (step == 1) ...[
              Kicker('${p['service']}'),
              const SizedBox(height: 4),
              Text('${p['serviceHint']}', style: const TextStyle(fontSize: 12, color: T.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['beauty', 'cleaning', 'chef'].map((id) {
                  final on = services.contains(id);
                  return _choiceChip('${svc[id]}', on, () => _toggleService(id), size: 13);
                }).toList(),
              ),
              // Specialties, grouped under the category they belong to.
              for (final v in services) ...[
                const SizedBox(height: 16),
                Kicker('${p['specialtiesIn']} ${svc[v]}'),
                const SizedBox(height: 8),
                if (catsLoading.contains(v) && !catsByVertical.containsKey(v))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: T.action)),
                  )
                else if (catsFailed.contains(v))
                  InkWell(
                    onTap: () => unawaited(_loadSpecialties(v)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('${p['catsLoadFailed']}',
                          style: const TextStyle(fontSize: 13, color: T.danger, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (catsByVertical[v] ?? const <Map<String, dynamic>>[]).map((c) {
                      final id = '${c['id']}';
                      final on = selectedCategories.contains(id);
                      final name = c['name'] is Map ? Loc.fromJson(c['name'] as Map).of(lang) : '${c['name'] ?? c['slug']}';
                      return _choiceChip(name, on, () => setState(() {
                            if (on) {
                              selectedCategories.remove(id);
                            } else {
                              selectedCategories.add(id);
                            }
                          }));
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 16),
              Kicker('${p['specialtyHint']}'),
              const SizedBox(height: 8),
              _field(specialty),
              const SizedBox(height: 16),
              Kicker('${p['years']}'),
              const SizedBox(height: 8),
              _field(years, digits: true),
              const SizedBox(height: 16),
              Kicker('${p['areas']}'),
              const SizedBox(height: 4),
              Text('${p['areasHint']}', style: const TextStyle(fontSize: 12, color: T.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCatalogAreaIds().map((id) {
                  final on = areas.contains(id);
                  return _choiceChip(areaName(id, lang), on, () => setState(() {
                        if (on) {
                          areas.remove(id);
                        } else {
                          areas.add(id);
                        }
                      }), size: 13);
                }).toList(),
              ),
            ],
            if (step == 2) ...[
              Kicker('${p['payout']}'),
              const SizedBox(height: 8),
              _field(payout, digits: true),
            ],
            if (step == 3) ...[
              ...['terms', 'data', 'backgroundCheck', 'womenOnly', 'tax'].map((k) {
                final labels = {
                  'terms': '${p['cTerms']}',
                  'data': '${p['cData']}',
                  'backgroundCheck': '${p['cBg']}',
                  'womenOnly': '${p['cWomen']}',
                  'tax': '${p['cTax']}',
                };
                const docs = {
                  'terms': 'provider',
                  'data': 'privacy',
                  'backgroundCheck': 'provider',
                  'womenOnly': 'provider',
                  'tax': 'provider',
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LegalConsentRow(
                    lang: lang,
                    value: consents[k] == true,
                    onChanged: (v) => setState(() => consents[k] = v),
                    label: labels[k]!,
                    docId: docs[k],
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => openLegal(context, 'consents'),
                  child: Text(
                    '${p['viewConsents']}',
                    style: const TextStyle(fontSize: 12, color: T.action, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
            if (err != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(err!, style: const TextStyle(color: T.danger))),
            const SizedBox(height: 24),
            InkButton(
              label: step < 3 ? '${p['next']}' : '${p['regCta']}',
              enabled: !busy,
              onTap: () async {
                if (step == 0) {
                  if (first.text.trim().isEmpty || last.text.trim().isEmpty || legal.text.trim().isEmpty || nid.text.trim().length != 14 || residence.text.trim().isEmpty) {
                    setState(() => err = lang == 'ar' ? 'كمّلي الورق والرقم القومي ١٤ رقم.' : 'Finish your papers and 14-digit national ID.');
                    return;
                  }
                  if (idBytes == null) {
                    setState(() => err = '${p['needId']}');
                    return;
                  }
                  if (fishBytes == null) {
                    setState(() => err = '${p['needFish']}');
                    return;
                  }
                }
                if (step == 1) {
                  final problem = _workError(p);
                  if (problem != null) {
                    setState(() => err = problem);
                    return;
                  }
                }
                if (step < 3) {
                  if (step == 0) {
                    unawaited(AppAnalytics.providerIdInfoSubmitted());
                  }
                  if (step == 1) {
                    unawaited(AppAnalytics.providerCategorySelected(
                      vertical: services.join(','),
                      categoryCount: selectedCategories.length,
                    ));
                  }
                  if (step == 2) {
                    for (final key in consents.keys) {
                      unawaited(AppAnalytics.consentScreenViewed(consentType: key, role: 'provider'));
                    }
                  }
                  setState(() {
                    err = null;
                    step += 1;
                  });
                  return;
                }
                if (consents.values.any((v) => !v)) {
                  setState(() => err = '${p['needConsents']}');
                  return;
                }
                setState(() { busy = true; err = null; uploadProgress = 0; });
                try {
                  await ref.read(sessionProvider.notifier).registerProvider(
                        phone: _phone,
                        code: _code,
                        firstName: first.text.trim(),
                        lastName: last.text.trim(),
                        service: services.first,
                        services: services,
                        areas: areas.toList(),
                        specialty: specialty.text.trim().isEmpty ? null : specialty.text.trim(),
                        years: int.tryParse(years.text),
                        legalName: legal.text.trim().isEmpty ? null : legal.text.trim(),
                        nationalId: nid.text.trim().isEmpty ? null : nid.text.trim(),
                        birthDate: birth.text.trim().isEmpty ? null : birth.text.trim(),
                        residenceLine: residence.text.trim().isEmpty ? null : residence.text.trim(),
                        payoutHandle: payout.text.trim().isEmpty ? null : payout.text.trim(),
                        consents: consents,
                        categoryIds: selectedCategories.toList(),
                      );
                  clearPendingRegistration();
                  final repo = ref.read(repoProvider);
                  // Registration itself succeeded once we get here — the account
                  // exists. The two document uploads are best-effort follow-ups:
                  // one failing (oversized photo, a dropped connection) must not
                  // look like the whole signup failed, and must not stop the
                  // other upload from being attempted. Failures are surfaced on
                  // the account screen instead, where "ارفعي" can retry them.
                  final docIssues = <String>[];
                  if (idBytes != null) {
                    if (mounted) setState(() => uploadProgress = 0.05);
                    try {
                      final r = await repo.uploadProID(
                        idBytes!,
                        filename: idName ?? 'id.jpg',
                        onProgress: (f) {
                          if (mounted) setState(() => uploadProgress = 0.05 + f * 0.45);
                        },
                      );
                      if (r['provider'] is Map) {
                        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                      }
                    } catch (e) {
                      docIssues.add('${p['uploadId']}: ${friendlyError(e, lang)}');
                    }
                  }
                  if (fishBytes != null) {
                    if (mounted) setState(() => uploadProgress = 0.5);
                    try {
                      final r = await repo.uploadProFish(
                        fishBytes!,
                        filename: fishName ?? 'fish.jpg',
                        onProgress: (f) {
                          if (mounted) setState(() => uploadProgress = 0.5 + f * 0.45);
                        },
                      );
                      if (r['provider'] is Map) {
                        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                      }
                    } catch (e) {
                      docIssues.add('${p['uploadFish']}: ${friendlyError(e, lang)}');
                    }
                  }
                  if (mounted) setState(() => uploadProgress = 1);
                  await ref.read(sessionProvider.notifier).refreshMe();
                  if (docIssues.isNotEmpty) {
                    await Hive.box('prefs').put('pendingDocIssue', docIssues.join('\n'));
                  }
                  tapSuccess();
                  if (mounted) context.go('/pro/account');
                } catch (e) {
                  setState(() => err = friendlyError(e, lang));
                } finally {
                  if (mounted) setState(() { busy = false; uploadProgress = null; });
                }
              },
            ),
            if (step > 0) ...[
              const SizedBox(height: 8),
              GhostButton(label: lang == 'ar' ? 'رجوع' : 'Back', onTap: () => setState(() => step -= 1)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _docPickTile({
    required String lang,
    required String emptyLabel,
    required String readyLabel,
    required List<int>? bytes,
    required String? name,
    required VoidCallback onPick,
  }) {
    return InkWell(
      onTap: busy ? null : onPick,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: T.ink, width: T.rule),
          color: bytes == null ? T.surface : T.plumTint,
        ),
        child: Row(
          children: [
            if (bytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.description_outlined, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                bytes == null ? emptyLabel : (name?.trim().isNotEmpty == true ? name!.trim() : readyLabel),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (bytes != null)
              Text(
                lang == 'ar' ? 'تمّت ✓' : 'Ready ✓',
                style: const TextStyle(fontSize: 12, color: T.action, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String label, bool on, VoidCallback onTap, {double size = 12}) {
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: on ? T.action : T.surface, border: Border.all(color: T.ink, width: T.rule)),
          child: Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: on ? T.white : T.ink)),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, {bool digits = false}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule), color: T.surface),
      child: TextField(
        controller: c,
        // Use ASCII numpad — avoids Arabic-locale keyboards injecting ٠١٢٣
        keyboardType: digits
            ? const TextInputType.numberWithOptions(signed: false, decimal: false)
            : TextInputType.text,
        // Strip any Arabic-Indic digits that slip through
        inputFormatters: digits ? [_AsciiDigitFormatter()] : null,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      ),
    );
  }
}

/// Converts Arabic-Indic digits (٠١٢٣…) to ASCII digits so numeric fields
/// work correctly regardless of system keyboard locale.
class _AsciiDigitFormatter extends TextInputFormatter {
  static const _arabicZero = 0x0660;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue n) {
    final converted = n.text.replaceAllMapped(
      RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'),
      (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - (m.group(0)!.codeUnitAt(0) >= 0x06F0 ? 0x06F0 : _arabicZero) + 0x30),
    );
    if (converted == n.text) return n;
    return n.copyWith(
      text: converted,
      selection: n.selection.copyWith(
        baseOffset: n.selection.baseOffset.clamp(0, converted.length),
        extentOffset: n.selection.extentOffset.clamp(0, converted.length),
      ),
    );
  }
}

class ProJobScreen extends ConsumerStatefulWidget {
  const ProJobScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ProJobScreen> createState() => _ProJobScreenState();
}

class _ProJobScreenState extends ConsumerState<ProJobScreen> {
  BookingBundle? data;
  bool busy = false;
  Timer? poll;
  Timer? locPing;
  TrackSocket? track;
  StreamSubscription<Position>? locStream;

  @override
  void initState() {
    super.initState();
    _load();
    poll = Timer.periodic(const Duration(seconds: 25), (_) => _load());
  }

  @override
  void dispose() {
    poll?.cancel();
    locPing?.cancel();
    locStream?.cancel();
    track?.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final b = await ref.read(repoProvider).proBooking(widget.id);
    if (!mounted) return;
    setState(() => data = b);
    _syncPings(b.booking.status);
  }

  void _syncPings(String status) {
    final live = status == 'on_the_way' || status == 'in_progress';
    if (!live) {
      locPing?.cancel();
      locPing = null;
      locStream?.cancel();
      locStream = null;
      track?.stop();
      track = null;
      return;
    }
    final token = ref.read(sessionProvider).token;
    if (token != null && track == null) {
      track = TrackSocket(bookingId: widget.id, token: token, onFix: (_) {})..start();
    }
    locPing ??= Timer.periodic(const Duration(seconds: 20), (_) => _ping());
    locStream ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 12),
    ).listen((pos) {
      track?.sendPing(pos.latitude, pos.longitude);
    }, onError: (_) {});
    _ping();
  }

  Future<void> _ping() async {
    try {
      final pos = await currentPosition();
      if (track != null && track!.connected) {
        track!.sendPing(pos.latitude, pos.longitude);
        return;
      }
      await ref.read(repoProvider).pingLocation(widget.id, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    final states = Copy.of(lang)['states'] as Map;
    final row = data;
    if (row == null) {
      return const Scaffold(backgroundColor: Pro.bg, body: Center(child: CircularProgressIndicator(color: Pro.plum)));
    }
    final bk = row.booking;
    final st = (states[bk.status] as Map?) ?? {};
    final statusLabel = '${st['code'] ?? bk.status}';
    final locked = row.clientLocked;
    final name = locked
        ? '${p['clientHidden']}'
        : (row.clientName?.of(lang) ?? (lang == 'ar' ? 'عميلة' : 'Client'));
    final area = row.clientArea ?? (bk.address?.area.isNotEmpty == true ? areaName(bk.address!.area, lang) : '');
    final step = _visitStep(bk.status);
    final stepLabels = lang == 'ar'
        ? const ['مقبولة', 'في الطريق', 'بدأت', 'خلصت']
        : const ['Accepted', 'On the way', 'Started', 'Done'];

    return Scaffold(
      backgroundColor: Pro.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    child: Text(
                      lang == 'ar' ? '→ رجوع' : '← Back',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Pro.plum),
                    ),
                  ),
                  const Spacer(),
                  Text(bk.ref, style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: Pro.muted)),
                ],
              ),
            ),
            const Divider(height: 1, color: Pro.lineSoft),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Row(
                    children: [
                      ProAvatar(name, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Pro.ink)),
                            const SizedBox(height: 2),
                            Text(
                              [bk.serviceName.of(lang), if (area.isNotEmpty) area].join(' · '),
                              style: const TextStyle(fontSize: 12, color: Pro.muted),
                            ),
                          ],
                        ),
                      ),
                      ProPill(statusLabel, hot: true),
                    ],
                  ),
                  if (locked) ...[
                    const SizedBox(height: 12),
                    Text('${p['clientLocked']}', style: const TextStyle(fontSize: 13, color: Pro.muted, height: 1.45)),
                  ],
                  const SizedBox(height: 18),
                  ProCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ProSectionLabel(lang == 'ar' ? 'خطوات الزيارة' : 'Visit steps'),
                            const Spacer(),
                            Text(
                              lang == 'ar' ? '${_arDigit(step)} من ٤' : '$step of 4',
                              style: const TextStyle(fontSize: 11, color: Pro.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(4, (i) {
                            final on = i < step;
                            return Expanded(
                              child: Container(
                                height: 5,
                                margin: EdgeInsetsDirectional.only(end: i == 3 ? 0 : 6),
                                decoration: BoxDecoration(
                                  color: on ? Pro.plum : const Color(0xFFE6DDD6),
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(4, (i) {
                            final on = i < step;
                            return Text(
                              stepLabels[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                                color: on ? Pro.ink : Pro.muted,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (!locked && bk.address != null) ...[
                    const SizedBox(height: 12),
                    ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProSectionLabel(lang == 'ar' ? 'العنوان · البيت' : 'Address · home'),
                          const SizedBox(height: 6),
                          Text(bk.address!.line1.of(lang), style: const TextStyle(fontSize: 14, height: 1.7, color: Pro.ink)),
                          if (bk.address!.city.of(lang).trim().isNotEmpty)
                            Text(bk.address!.city.of(lang), style: const TextStyle(fontSize: 13, color: Pro.soft)),
                          if (bk.address!.reachNotes.of(lang).trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(bk.address!.reachNotes.of(lang), style: const TextStyle(fontSize: 13, height: 1.5, color: Pro.soft)),
                          ],
                          const SizedBox(height: 12),
                          _softAction(
                            lang == 'ar' ? 'افتحي الخريطة' : 'Open map',
                            () {
                              final q = Uri.encodeComponent('${bk.address!.line1.of(lang)} ${bk.address!.city.of(lang)}');
                              launchUrl(Uri.parse('https://maps.google.com/?q=$q'), mode: LaunchMode.externalApplication);
                            },
                          ),
                          if ((data!.clientPhone ?? data!.clientPhoneMasked)?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            _softAction(
                              data!.clientPhone != null
                                  ? (lang == 'ar' ? 'اتّصلي بالعميلة' : 'Call client')
                                  : (lang == 'ar'
                                      ? 'الموبايل ${data!.clientPhoneMasked} (بعد التأكيد)'
                                      : 'Phone ${data!.clientPhoneMasked} (after confirm)'),
                              data!.clientPhone != null
                                  ? () => launchUrl(Uri.parse('tel:${data!.clientPhone}'), mode: LaunchMode.externalApplication)
                                  : () {},
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!locked && (bk.status == 'paid' || bk.status == 'on_the_way' || bk.assignedWorkers.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProSectionLabel(lang == 'ar' ? 'الفريق المكلّف' : 'Assigned team'),
                          const SizedBox(height: 8),
                          if (bk.assignedWorkers.isEmpty)
                            Text(
                              lang == 'ar' ? 'لسه محددتيش مين هيروح.' : "You haven't picked who's going yet.",
                              style: const TextStyle(fontSize: 13, color: Pro.muted),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: bk.assignedWorkers.map((w) => ProPill(w.name, hot: true)).toList(),
                            ),
                          if (bk.status == 'paid' || bk.status == 'on_the_way') ...[
                            const SizedBox(height: 10),
                            _softAction(
                              bk.assignedWorkers.isEmpty
                                  ? (lang == 'ar' ? 'كلّفي الفريق' : 'Assign the team')
                                  : (lang == 'ar' ? 'عدّلي الفريق' : 'Edit team'),
                              () => _assignTeam(lang),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!locked && bk.timeline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ProCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProSectionLabel(lang == 'ar' ? 'خطوات الزيارة' : 'Visit timeline'),
                          const SizedBox(height: 8),
                          ...bk.timeline.map((ev) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(ev.done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: ev.done ? Pro.plum : Pro.muted),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(ev.key, style: TextStyle(fontSize: 13, color: ev.done ? Pro.ink : Pro.muted))),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  if (!locked && bk.notes != null && bk.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ProCard(
                      color: Pro.warnBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProSectionLabel(lang == 'ar' ? 'اللي كتبته العميلة' : 'Client notes'),
                          const SizedBox(height: 6),
                          Text(bk.notes!, style: const TextStyle(fontSize: 14, height: 1.8, color: Pro.ink)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ProCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProSectionLabel(lang == 'ar' ? 'الفلوس' : 'Payout'),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              money(bk.serviceEarning, lang),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Pro.ink, fontFamily: T.mono),
                            ),
                            const Spacer(),
                            Text('${p['held']}', style: const TextStyle(fontSize: 12, color: Pro.soft)),
                          ],
                        ),
                        if (paymentMethodLabel(bk.paymentMethod, lang).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            lang == 'ar'
                                ? 'دفعت بـ ${paymentMethodLabel(bk.paymentMethod, lang)}'
                                : 'Paid with ${paymentMethodLabel(bk.paymentMethod, lang)}',
                            style: const TextStyle(fontSize: 13, color: Pro.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(color: Pro.bg, border: Border(top: BorderSide(color: Pro.lineSoft))),
              child: Column(
                children: [
                  if ((bk.status == 'paid' || bk.status == 'rescheduled') && locked)
                    ProPrimaryButton(label: '${p['acceptJob']}', enabled: !busy, onTap: () => _act(() => ref.read(repoProvider).proAccept(widget.id), doneKey: 'doneAccept')),
                  if (bk.status == 'paid' && !locked)
                    ProPrimaryButton(label: '${p['depart']}', enabled: !busy, onTap: () => _act(() => ref.read(repoProvider).proDepart(widget.id), pingAfter: true, doneKey: 'doneDepart')),
                  if (bk.status == 'on_the_way' && bk.entryPhotoUrl != null && bk.entryPhotoUrl!.isNotEmpty && bk.providerCheckIn == null)
                    ProPrimaryButton(
                      label: '${p['scanHandshake']}',
                      enabled: !busy,
                      onTap: () async {
                        final ok = await context.push<bool>('/pro/handshake/${widget.id}');
                        if (ok == true) await _load();
                      },
                    )
                  else if (bk.status == 'on_the_way')
                    ProPrimaryButton(label: '${p['arrive']}', enabled: !busy, onTap: () => _arrive()),
                  if (bk.status == 'in_progress')
                    Text('${p['waitCheckout']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Pro.muted)),
                  if (bk.status == 'completed' && !bk.clientRated)
                    ProPrimaryButton(label: '${p['rateClient']}', enabled: !busy, onTap: () => context.push('/pro/rate/${widget.id}')),
                  if (bk.status == 'paid' || bk.status == 'on_the_way' || bk.status == 'in_progress') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: ProSoftButton(label: '${Copy.of(lang)['safety']['sos']}', onTap: () => _sos(lang))),
                        if (bk.status == 'paid' || bk.status == 'on_the_way') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ProSoftButton(
                              label: '${p['cancelJob']}',
                              danger: true,
                              onTap: () => _cancelWithReason(lang),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _softAction(String label, VoidCallback onTap) {
    return Material(
      color: Pro.chip,
      borderRadius: BorderRadius.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Pro.ink)),
        ),
      ),
    );
  }

  int _visitStep(String status) {
    switch (status) {
      case 'paid':
      case 'rescheduled':
        return 1;
      case 'on_the_way':
        return 2;
      case 'in_progress':
        return 3;
      case 'completed':
      case 'settled':
        return 4;
      default:
        return 1;
    }
  }

  String _arDigit(int n) {
    const map = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((c) => map[int.parse(c)]).join();
  }

  Future<void> _arrive() async {
    final lang = langOf(ref);
    if (data?.booking.entryPhotoUrl != null && data!.booking.entryPhotoUrl!.isNotEmpty) {
      return;
    }
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600);
    } catch (_) {
      // Camera capture on the web depends on the browser/device actually
      // supporting it and granting permission — when it doesn't, this used
      // to throw with nothing shown to her at all, which reads exactly like
      // "the button does nothing." Offer the one thing that reliably works
      // everywhere instead of leaving her stuck.
      if (!mounted) return;
      final useGallery = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(lang == 'ar' ? 'الكاميرا مش متاحة' : 'Camera unavailable'),
          content: Text(lang == 'ar'
              ? 'مقدرناش نفتح الكاميرا على الجهاز ده. تحبي ترفعي صورة بدل ما تاخديها دلوقتي؟'
              : "Couldn't open the camera on this device. Upload a photo instead?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang == 'ar' ? 'إلغاء' : 'Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lang == 'ar' ? 'ارفعي صورة' : 'Upload a photo')),
          ],
        ),
      );
      if (useGallery != true) return;
      try {
        file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e2, lang))));
        return;
      }
    }
    if (file == null) return;
    setState(() => busy = true);
    try {
      final pos = await currentPosition();
      final bytes = await file.readAsBytes();
      final b = await ref.read(repoProvider).proArriveProof(widget.id, bytes, pos.latitude, pos.longitude);
      tapSuccess();
      if (mounted) {
        setState(() => data = b);
        final p = Copy.of(lang)['pro'] as Map;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneArrive']}')));
      }
    } catch (e) {
      // GeoException (location off / permission denied) has its own clear,
      // actionable copy via geoMessage — friendlyError doesn't know about
      // it and was falling back to a generic "something went wrong", which
      // is how a plain "turn on Location Services" fix read as the whole
      // at-the-door flow being broken.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is GeoException ? geoMessage(e, lang) : friendlyError(e, lang))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _assignTeam(String lang) async {
    final ar = lang == 'ar';
    List<Map<String, dynamic>> roster = [];
    try {
      roster = await ref.read(repoProvider).proWorkers();
    } catch (_) {}
    // assignable covers both "fully vetted" and "under an active grace
    // period" — matches the actual gate assignWorkers enforces server-side.
    // Filtering on vetted alone here would silently hide grace-covered
    // workers from this picker even though the backend would accept them.
    final eligible = roster.where((w) => w['active'] == true && w['assignable'] == true).toList();
    if (!mounted) return;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        ar
            ? 'مفيش حد موثّق في فريق العمل لسه. ضيفي ووثّقي عضو من "فريق العمل" في حسابك.'
            : 'No vetted team members yet. Add and vet one from Team in your account.',
      )));
      return;
    }
    final currentIds = data?.booking.assignedWorkers.map((w) => w.workerId).toSet() ?? <String>{};
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => _TeamPickerSheet(lang: lang, roster: eligible, initiallySelected: currentIds),
    );
    if (selected == null || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(repoProvider).assignWorkers(widget.id, selected.toList());
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اتحدد الفريق ✓' : 'Team assigned ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
      await ref.read(repoProvider).proSos(widget.id, lat: lat, lng: lng);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${Copy.of(lang)['pro']['sosDone']}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
    }
  }

  Future<void> _cancelWithReason(String lang) async {
    final reasons = lang == 'ar'
        ? const ['ظرف طارئ', 'مفيش مواصلات', 'العميلة طلبت التأجيل', 'سبب تاني']
        : const ['Emergency', 'Transport issue', 'Client asked to postpone', 'Other'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(lang == 'ar' ? 'سبب إلغاء الزيارة' : 'Cancel reason', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...reasons.map((r) => ListTile(
                    title: Text(r),
                    onTap: () => Navigator.pop(ctx, r),
                  )),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _act(() => ref.read(repoProvider).proCancel(widget.id, reason: picked), doneKey: 'doneCancel');
  }

  Future<void> _act(Future<BookingBundle> Function() fn, {bool pingAfter = false, String? doneKey}) async {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    setState(() => busy = true);
    try {
      final b = await fn();
      tapSuccess();
      if (mounted) {
        setState(() => data = b);
        _syncPings(b.booking.status);
        if (pingAfter) _ping();
        final label = doneKey != null ? '${p[doneKey] ?? p['doneSave']}' : _statusDoneLabel(b.booking.status, p);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _statusDoneLabel(String status, Map p) {
    switch (status) {
      case 'paid': return '${p['doneAccept']}';
      case 'on_the_way': return '${p['doneDepart']}';
      case 'in_progress': return '${p['doneArrive']}';
      case 'cancelled': return '${p['doneCancel']}';
      default: return '${p['doneSave']}';
    }
  }
}

class ProRateScreen extends ConsumerStatefulWidget {
  const ProRateScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<ProRateScreen> createState() => _ProRateScreenState();
}

class _ProRateScreenState extends ConsumerState<ProRateScreen> {
  int stars = 0;
  final tags = <int>{};
  bool busy = false;
  final photos = <Uint8List>[];

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file == null) return;
    photos.add(Uint8List.fromList(await file.readAsBytes()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    final tagList = (p['clientTags'] as List).cast<String>();
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHead(title: '${p['rateClient']}', onBack: () => context.pop()),
              const SizedBox(height: 16),
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
                          decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule), color: on ? T.action : T.surface),
                          child: Text('$n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? T.white : T.ink)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(tagList.length, (i) {
                  final on = tags.contains(i);
                  return InkWell(
                    onTap: () => setState(() => on ? tags.remove(i) : tags.add(i)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule), color: on ? T.ink : T.bg),
                      child: Text(tagList[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? T.bg : T.ink)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Kicker('${Copy.of(lang)['rate']['addPhotos']}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ...photos.asMap().entries.map((e) => Image.memory(photos[e.key], width: 72, height: 72, fit: BoxFit.cover)),
                  InkWell(
                    onTap: _pickPhoto,
                    child: Container(width: 72, height: 72, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: T.ink, width: T.rule)), child: const Text('+')),
                  ),
                ],
              ),
              const Spacer(),
              InkButton(
                label: '${Copy.of(lang)['rate']['submit']}',
                enabled: stars > 0 && !busy,
                onTap: () async {
                  setState(() => busy = true);
                  try {
                    final repo = ref.read(repoProvider);
                    final urls = <String>[];
                    for (final bytes in photos) {
                      final url = await repo.uploadReviewPhoto(widget.bookingId, bytes, provider: true);
                      if (url.isNotEmpty) urls.add(url);
                    }
                    await repo.proRate(widget.bookingId, stars, tags.map((i) => tagList[i]).toList(), images: urls);
                    tapSuccess();
                    if (context.mounted) context.go('/pro/jobs');
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

/// Picker over a provider's active + vetted roster, for "assign the team" on
/// a confirmed booking. Returns the selected worker ids, or null if
/// cancelled.
class _TeamPickerSheet extends StatefulWidget {
  const _TeamPickerSheet({required this.lang, required this.roster, required this.initiallySelected});
  final String lang;
  final List<Map<String, dynamic>> roster;
  final Set<String> initiallySelected;

  @override
  State<_TeamPickerSheet> createState() => _TeamPickerSheetState();
}

class _TeamPickerSheetState extends State<_TeamPickerSheet> {
  late final selected = Set<String>.of(widget.initiallySelected);

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ar ? 'مين هيروح؟' : "Who's going?", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink)),
            const SizedBox(height: 4),
            Text(
              ar ? 'اختاري واحد أو أكتر من فريقك الموثّق.' : 'Pick one or more from your vetted team.',
              style: const TextStyle(fontSize: 13, color: Pro.muted),
            ),
            const SizedBox(height: 14),
            ...widget.roster.map((w) {
              final id = '${w['id']}';
              final name = '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim();
              final on = selected.contains(id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: on,
                activeColor: Pro.plum,
                title: Text(name.isEmpty ? (ar ? 'بدون اسم' : 'Unnamed') : name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: '${w['phone'] ?? ''}'.isEmpty ? null : Text('${w['phone']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(id);
                  } else {
                    selected.remove(id);
                  }
                }),
              );
            }),
            const SizedBox(height: 10),
            ProPrimaryButton(
              label: ar ? 'تأكيد' : 'Confirm',
              enabled: selected.isNotEmpty,
              onTap: () => Navigator.pop(context, selected),
            ),
          ],
        ),
      ),
    );
  }
}
