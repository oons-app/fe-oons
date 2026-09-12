export 'package:oons/features/pro/pro_earnings_screens.dart' show ProEarningsScreen;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/geo.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/track_socket.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/auth/auth_screens.dart' show clearPendingRegistration, pendingRegistration;
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/features/pro/pro_tour.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';
import 'package:url_launcher/url_launcher.dart';

class ProRegisterScreen extends ConsumerStatefulWidget {
  const ProRegisterScreen({super.key, required this.phone, required this.code});
  final String phone;
  final String code;
  @override
  ConsumerState<ProRegisterScreen> createState() => _ProRegisterScreenState();
}

class _ProRegisterScreenState extends ConsumerState<ProRegisterScreen> {
  int step = 0;
  final first = TextEditingController();
  final last = TextEditingController();
  final legal = TextEditingController();
  final nid = TextEditingController();
  final birth = TextEditingController(text: '1995-01-01');
  final residence = TextEditingController();
  final specialty = TextEditingController();
  final years = TextEditingController(text: '3');
  final payout = TextEditingController();
  String service = 'beauty';
  final areas = <String>{'madinaty'};
  final consents = <String, bool>{'terms': false, 'data': false, 'backgroundCheck': false, 'womenOnly': false, 'tax': false};
  final selectedCategories = <String>{};
  List<Map<String, dynamic>> categoryOptions = [];
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
        if (areas.isEmpty) areas.add('madinaty');
      });
    }));
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['beauty', 'cleaning', 'chef'].map((id) {
                  final on = service == id;
                  return InkWell(
                    onTap: () async {
                      setState(() { service = id; selectedCategories.clear(); });
                      try {
                        final cats = await ref.read(repoProvider).categories(vertical: id, activeOnly: true);
                        if (mounted) setState(() => categoryOptions = cats);
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: on ? T.action : T.surface, border: Border.all(color: T.ink, width: T.rule)),
                      child: Text('${svc[id]}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? T.white : T.ink)),
                    ),
                  );
                }).toList(),
              ),

              if (categoryOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Kicker('${p['categories']}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryOptions.map((c) {
                    final id = '${c['id']}';
                    final on = selectedCategories.contains(id);
                    final name = c['name'] is Map ? Loc.fromJson(c['name'] as Map).of(lang) : '${c['name'] ?? c['slug']}';
                    return InkWell(
                      onTap: () => setState(() { if (on) selectedCategories.remove(id); else selectedCategories.add(id); }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: on ? T.action : T.surface, border: Border.all(color: T.ink, width: T.rule)),
                        child: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? T.white : T.ink)),
                      ),
                    );
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCatalogAreaIds().map((id) {
                  final on = areas.contains(id);
                  return InkWell(
                    onTap: () => setState(() {
                      if (on && areas.length > 1) {
                        areas.remove(id);
                      } else {
                        areas.add(id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: on ? T.action : T.surface, border: Border.all(color: T.ink, width: T.rule)),
                      child: Text(areaName(id, lang), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? T.white : T.ink)),
                    ),
                  );
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
                if (step == 1 && selectedCategories.isEmpty) {
                  setState(() => err = lang == 'ar' ? 'اختاري فئة واحدة واحدة على الأقل.' : 'Pick at least one category.');
                  return;
                }
                if (step < 3) {
                  if (step == 0) {
                    unawaited(AppAnalytics.providerIdInfoSubmitted());
                  }
                  if (step == 1) {
                    unawaited(AppAnalytics.providerCategorySelected(
                      vertical: service,
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
                  if (step == 1) {
                    // Load subcategory chips for the default vertical.
                    () async {
                      try {
                        final cats = await ref.read(repoProvider).categories(vertical: service, activeOnly: true);
                        if (mounted) setState(() => categoryOptions = cats);
                      } catch (_) {}
                    }();
                  }
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
                        service: service,
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
                borderRadius: BorderRadius.circular(6),
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

class ProJobsScreen extends ConsumerStatefulWidget {
  const ProJobsScreen({super.key});
  @override
  ConsumerState<ProJobsScreen> createState() => _ProJobsScreenState();
}

class _ProJobsScreenState extends ConsumerState<ProJobsScreen> {
  int tab = 0; // 0 upcoming, 1 past
  List<BookingBundle>? up;
  List<BookingBundle>? past;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    _load();
    poll = Timer.periodic(const Duration(seconds: 25), (_) => _load());
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    try {
      final jobs = await repo.proJobs();
      if (!mounted) return;
      setState(() {
        up = jobs.upcoming;
        past = jobs.past;
      });
    } catch (_) {
      // Offline / connection refused — keep last list; banner handles UX.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final b = Copy.of(lang)['bookings'] as Map;
    final p = Copy.of(lang)['pro'] as Map;
    final rows = tab == 0 ? (up ?? []) : (past ?? []);
    final loading = up == null || past == null;
    final today = DateTime.now();
    final todayN = (up ?? []).where((r) {
      final d = r.booking.slotStart.toLocal();
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
    final weekN = (up ?? []).length;
    final expected = (up ?? []).fold<int>(0, (n, r) => n + r.booking.serviceEarning);

    return ColoredBox(
      color: Pro.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${p['jobs']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: ProStatTile(label: lang == 'ar' ? 'النهاردة' : 'Today', value: '$todayN')),
                      const SizedBox(width: 8),
                      Expanded(child: ProStatTile(label: lang == 'ar' ? 'الأسبوع ده' : 'This week', value: '$weekN')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ProStatTile(
                          label: lang == 'ar' ? 'متوقّع' : 'Expected',
                          value: '${(expected / 100).round()}',
                          accent: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ProSegment(
                    labels: ['${b['upcoming']}', '${b['past']}'],
                    index: tab,
                    onChanged: (i) => setState(() => tab = i),
                  ),
                  const SizedBox(height: 10),
                  ProSectionWithHelp(
                    lang == 'ar' ? 'مساعدة سريعة' : 'Quick help',
                    help: '${Copy.of(lang)['svcMgmt']['tipVisit']}',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Pro.plum))
                : RefreshIndicator(
                    color: Pro.plum,
                    onRefresh: _load,
                    child: rows.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            children: [
                              SizedBox(height: 80, child: Center(child: Text('${p['emptyJobs']}', style: const TextStyle(color: Pro.muted)))),
                              if (tab == 0)
                                ProHintBanner(
                                  lang == 'ar'
                                      ? 'مفيش زيارات تانية الأسبوع ده. زوّدي مناطق أو ساعات حجز من خدماتي تزيدي فرصك.'
                                      : 'No more visits this week. Add areas or hours in Services to get more bookings.',
                                  dashed: true,
                                ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            itemCount: rows.length + (tab == 0 ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == rows.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ProHintBanner(
                                    lang == 'ar'
                                        ? 'مفيش زيارات تانية الأسبوع ده. زوّدي مناطق أو ساعات حجز من خدماتي تزيدي فرصك.'
                                        : 'No more visits this week. Add areas or hours in Services to get more bookings.',
                                    dashed: true,
                                  ),
                                );
                              }
                              final row = rows[i];
                              final bk = row.booking;
                              final states = Copy.of(lang)['states'] as Map;
                              final st = (states[bk.status] as Map?) ?? {};
                              final statusLabel = '${st['code'] ?? bk.status}';
                              final hot = bk.status == 'on_the_way' || bk.status == 'in_progress';
                              final name = row.clientLocked
                                  ? '${p['clientHidden']}'
                                  : (row.clientName?.of(lang) ?? (lang == 'ar' ? 'عميلة' : 'Client'));
                              final when = DateFormat(lang == 'ar' ? 'EEE · HH:mm' : 'EEE · HH:mm', lang == 'ar' ? 'ar' : 'en')
                                  .format(bk.slotStart.toLocal());
                              final area = row.clientArea ?? (bk.address?.area.isNotEmpty == true ? areaName(bk.address!.area, lang) : '');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ProCard(
                                  onTap: () => context.push('/pro/job/${bk.id}'),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ProAvatar(name),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pro.ink)),
                                                const SizedBox(height: 2),
                                                Text(bk.serviceName.of(lang), style: const TextStyle(fontSize: 12, color: Pro.muted)),
                                              ],
                                            ),
                                          ),
                                          Flexible(
                                            child: ProPill(statusLabel, hot: hot, soft: !hot),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1, color: Color(0xFFEFE7E1)),
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              area.isEmpty ? when : '$when  ·  $area',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: Pro.soft),
                                            ),
                                          ),
                                          Text(
                                            money(bk.serviceEarning, lang),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Pro.ink, fontFamily: T.mono),
                                          ),
                                        ],
                                      ),
                                      if (row.settlement != null) ...[
                                        const SizedBox(height: 8),
                                        _settlementChip(row.settlement!, lang),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

Widget _settlementChip(Map<String, dynamic> chip, String lang) {
  final st = '${chip['status'] ?? ''}';
  final note = '${lang == 'ar' ? chip['noteAr'] : chip['noteEn'] ?? ''}';
  String title;
  Color bg;
  Color fg;
  switch (st) {
    case 'ready':
      title = lang == 'ar' ? 'جاهز للتسوية' : 'Ready to settle';
      bg = const Color(0xFFEDE4FB);
      fg = Pro.plum;
      break;
    case 'held':
      title = lang == 'ar' ? 'مدفوع للانتظار' : 'Paid to hold';
      bg = const Color(0xFFFFF4DF);
      fg = const Color(0xFF8A5B00);
      break;
    case 'dispute':
      title = lang == 'ar' ? 'معلّق (نزاع)' : 'On hold (dispute)';
      bg = const Color(0xFFFFE4E4);
      fg = const Color(0xFF8B2D2D);
      break;
    case 'processing':
      title = lang == 'ar' ? 'قيد التنفيذ' : 'Processing';
      bg = const Color(0xFFE5F1FF);
      fg = const Color(0xFF1E5C9A);
      break;
    case 'settled':
      title = lang == 'ar' ? 'تمت التسوية' : 'Settled';
      bg = const Color(0xFFE7F5EA);
      fg = const Color(0xFF1F6B35);
      break;
    default:
      title = st;
      bg = Pro.sand;
      fg = Pro.soft;
  }
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        if (note.trim().isNotEmpty) Text(note, style: TextStyle(fontSize: 10.5, color: fg.withValues(alpha: 0.92))),
      ],
    ),
  );
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
                                  borderRadius: BorderRadius.circular(999),
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
      borderRadius: BorderRadius.circular(Pro.rSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Pro.rSm),
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
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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

class ProAccountScreen extends ConsumerStatefulWidget {
  const ProAccountScreen({super.key});
  @override
  ConsumerState<ProAccountScreen> createState() => _ProAccountScreenState();
}

class _ProAccountScreenState extends ConsumerState<ProAccountScreen> {
  late final specialty = TextEditingController();
  late final years = TextEditingController();
  late final payout = TextEditingController();
  late final bio = TextEditingController();
  bool primed = false;
  String? primedId;
  bool busy = false;
  double? uploadProgress;
  String? uploadLabel;
  String? docIssue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
    });
    // One-time notice: a document upload failed right after registration
    // (oversized photo, dropped connection) while the account itself was
    // created fine. Surface it once, here, where "ارفعي" can retry it.
    final prefs = Hive.box('prefs');
    final pending = prefs.get('pendingDocIssue') as String?;
    if (pending != null && pending.isNotEmpty) {
      docIssue = pending;
      prefs.delete('pendingDocIssue');
    }
  }

  void _prime(ProviderP? me) {
    if (me == null) return;
    if (primed && primedId == me.id) return;
    primed = true;
    primedId = me.id;
    specialty.text = me.specialty.ar.isNotEmpty ? me.specialty.ar : me.specialty.en;
    years.text = '${me.years}';
    payout.text = me.payoutHandle ?? '';
    bio.text = me.bio?.of('ar') ?? me.bio?.en ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['pro'] as Map;
    final profile = Copy.of(lang)['profile'] as Map;
    final me = ref.watch(sessionProvider).provider;
    _prime(me);
    // Her own upload manager — must show only what she actually uploaded.
    // (The stock/demo-shot fallback that used to exist for an empty
    // portfolio has been removed everywhere, including the customer-facing
    // browse/profile preview — it presented other providers' portraits and
    // generic stock photos as if they were a real provider's own work.)
    final shots = me?.portfolio ?? const <String>[];
    final vetted = me?.vetted == true;

    return ColoredBox(
      color: Pro.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          SafeArea(
            bottom: false,
            child: Text('${p['account']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Pro.ink)),
          ),
          if (docIssue != null) ...[
            const SizedBox(height: 14),
            ProCard(
              color: Pro.pendingBg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Pro.pendingInk, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang == 'ar'
                          ? 'اتسجل حسابك، بس في ورقة ما اترفعتش:\n$docIssue\nارفعيها تاني من "ورقك" تحت.'
                          : 'Your account is set up, but a document didn\'t upload:\n$docIssue\nUpload it again from "Papers" below.',
                      style: const TextStyle(fontSize: 12.5, color: Pro.pendingInk, height: 1.5),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => docIssue = null),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4, top: 2),
                      child: Icon(Icons.close, color: Pro.pendingInk, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ProCard(
            child: Row(
              children: [
                InkWell(
                  onTap: () => _pick(face: true),
                  child: ProAvatar(me?.initials.of(lang) ?? me?.name(lang) ?? '', size: 56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me?.name(lang) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Pro.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((me?.specialty.of(lang) ?? '').isNotEmpty) me!.specialty.of(lang),
                          if (me != null) lang == 'ar' ? '${me.years} سنين خبرة' : '${me.years} yrs',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Pro.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: vetted ? '${p['vetted']}' : '${p['pendingReview']}',
                  preferBelow: true,
                  waitDuration: const Duration(milliseconds: 200),
                  showDuration: const Duration(seconds: 5),
                  triggerMode: TooltipTriggerMode.tap,
                  child: Semantics(
                    button: true,
                    label: vetted ? '${p['vetted']}' : '${p['pendingReview']}',
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vetted ? const Color(0xFF2F7D4A) : Pro.pendingInk,
                          border: Border.all(
                            color: vetted ? const Color(0xFF1F5A35) : Pro.pendingLine,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ProCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProSectionWithHelp('${Copy.of(lang)['svcMgmt']['documents']}', help: '${Copy.of(lang)['svcMgmt']['tipVerify']}'),
                const SizedBox(height: 12),
                if (uploadProgress != null) ...[
                  Text(
                    uploadLabel ?? '${Copy.of(lang)['svcMgmt']['uploading']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pro.muted),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: uploadProgress!.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: Pro.plum,
                    backgroundColor: Pro.sand,
                  ),
                  const SizedBox(height: 12),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(Pro.rSm),
                  child: Column(
                    children: [
                      _docRow(
                        '${Copy.of(lang)['svcMgmt']['nidEditTitle']}',
                        () {
                          final sm = Copy.of(lang)['svcMgmt'] as Map;
                          final nid = me?.nationalId;
                          if (nid == null || nid.isEmpty) return '${sm['docMissing']}';
                          if (nid.length >= 4) return '${'•' * (nid.length - 4)}${nid.substring(nid.length - 4)}';
                          return nid;
                        }(),
                        ok: me?.nationalId != null && me!.nationalId!.length == 14,
                        onTap: () => _editNationalId(lang),
                        lang: lang,
                      ),
                      _docRow(
                        '${p['uploadId']}',
                        me?.idPhotoUrl != null && me!.idPhotoUrl!.isNotEmpty
                            ? (vetted ? '${Copy.of(lang)['svcMgmt']['docOnFile']}' : '${Copy.of(lang)['svcMgmt']['nidUnderReview']}')
                            : '${Copy.of(lang)['svcMgmt']['docMissingF']}',
                        ok: me?.idPhotoUrl != null && me!.idPhotoUrl!.isNotEmpty && vetted,
                        pending: me?.idPhotoUrl != null && me!.idPhotoUrl!.isNotEmpty && !vetted,
                        thumbUrl: me?.idPhotoUrl,
                        onTap: () => _pick(idCard: true),
                        lang: lang,
                      ),
                      _docRow(
                        '${p['uploadFish']}',
                        me?.fishPhotoUrl != null && me!.fishPhotoUrl!.isNotEmpty
                            ? (vetted ? '${Copy.of(lang)['svcMgmt']['docOnFile']}' : '${Copy.of(lang)['svcMgmt']['nidUnderReview']}')
                            : '${Copy.of(lang)['svcMgmt']['docMissingF']}',
                        ok: me?.fishPhotoUrl != null && me!.fishPhotoUrl!.isNotEmpty && vetted,
                        pending: me?.fishPhotoUrl != null && me!.fishPhotoUrl!.isNotEmpty && !vetted,
                        thumbUrl: me?.fishPhotoUrl,
                        onTap: () => _pick(fish: true),
                        lang: lang,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProSectionLabel(lang == 'ar' ? 'بياناتي' : 'My details'),
          const SizedBox(height: 10),
          ProCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang == 'ar' ? 'تخصصك المعتمد' : 'Approved specialty', style: const TextStyle(fontSize: 11, color: Pro.muted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Pro.chip,
                    borderRadius: BorderRadius.circular(Pro.rSm),
                    border: Border.all(color: const Color(0xFFE7DED7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          me?.specialty.of(lang) ?? specialty.text,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Pro.ink),
                        ),
                      ),
                      InkWell(
                        onTap: () => context.go('/pro/services'),
                        child: Text(
                          lang == 'ar' ? 'عدّلي من خدماتي' : 'Edit in Services',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pro.plum),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['years']}', style: const TextStyle(fontSize: 11, color: Pro.muted)),
                          const SizedBox(height: 6),
                          ProField(controller: years, mono: true, keyboard: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['payout']}', style: const TextStyle(fontSize: 11, color: Pro.muted)),
                          const SizedBox(height: 6),
                          ProField(controller: payout, mono: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${p['bio']}', style: const TextStyle(fontSize: 11, color: Pro.muted)),
                const SizedBox(height: 6),
                ProField(controller: bio),
                const SizedBox(height: 14),
                ProPrimaryButton(
                  label: '${p['saveProfile']}',
                  enabled: !busy && me != null,
                  onTap: () async {
                    if (me == null) return;
                    setState(() => busy = true);
                    try {
                      final r = await ref.read(repoProvider).patchPro({
                        'specialty': specialty.text.trim(),
                        'years': int.tryParse(years.text) ?? me.years,
                        'payoutHandle': payout.text.trim(),
                        'bio': bio.text.trim(),
                      });
                      if (r['provider'] is Map) {
                        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                      }
                      tapSuccess();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneSaveProfile']}')));
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProSectionLabel('${p['photos']}'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              ...shots.asMap().entries.map((e) => InkWell(
                    onTap: () => openGallery(context, shots, index: e.key),
                    onLongPress: () async {
                      if (me == null || e.key >= me.portfolio.length) return;
                      final lang = langOf(ref);
                      final r = await ref.read(repoProvider).deleteProPortfolio(e.key);
                      if (r['provider'] is Map) {
                        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${(Copy.of(lang)['pro'] as Map)['doneDeletePhoto']}')));
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: MediaThumb(e.value),
                    ),
                  )),
              InkWell(
                onTap: _pick,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9BCC4), style: BorderStyle.solid),
                  ),
                  child: Text(
                    lang == 'ar' ? '+ زودي' : '+ Add',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pro.plum),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProSectionLabel(lang == 'ar' ? 'قانوني' : 'Legal'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(Pro.rCard),
            child: Column(
              children: [
                _settingsRow('${profile['terms']}', '', () => openLegal(context, 'terms')),
                _settingsRow('${profile['privacy']}', '', () => openLegal(context, 'privacy')),
                _settingsRow('${profile['cancellation']}', '', () => openLegal(context, 'cancellation')),
                _settingsRow('${profile['providerTerms']}', '', () => openLegal(context, 'provider')),
                _settingsRow('${profile['consentGuide']}', '', () => openLegal(context, 'consents')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProSectionLabel(lang == 'ar' ? 'فريق العمل' : 'Team'),
          const SizedBox(height: 10),
          ProCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang == 'ar'
                        ? 'ضيفي أعضاء فريقك ووثّقيهم عشان تقدري تكلّفيهم بالحجوزات.'
                        : 'Add and vet your team members so you can assign them to bookings.',
                    style: const TextStyle(fontSize: 12.5, color: Pro.muted, height: 1.4),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => context.push('/pro/team'),
                  child: Text(
                    lang == 'ar' ? 'إدارة الفريق' : 'Manage team',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pro.plum),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProSectionLabel(lang == 'ar' ? 'كوبوناتي' : 'My coupons'),
          const SizedBox(height: 10),
          ProCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang == 'ar'
                        ? 'اعملي أكواد خصم خاصة بيكي لعميلاتك.'
                        : 'Create your own discount codes for your clients.',
                    style: const TextStyle(fontSize: 12.5, color: Pro.muted, height: 1.4),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => context.push('/pro/coupons'),
                  child: Text(
                    lang == 'ar' ? 'إدارة الكوبونات' : 'Manage coupons',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pro.plum),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ProSectionLabel(lang == 'ar' ? 'الإعدادات' : 'Settings'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(Pro.rCard),
            child: Column(
              children: [
                _settingsRow('${profile['notif']}', '', () => context.push('/me/notif')),
                _settingsRow(
                  lang == 'ar' ? 'أعيدي الجولة السريعة' : 'Replay quick tour',
                  '',
                  () async {
                    await resetProTour();
                    if (context.mounted) await showProTour(context, lang: lang);
                  },
                ),
                _settingsRow(
                  lang == 'ar' ? '${profile['langCtaEn']}' : '${profile['langCtaAr']}',
                  lang == 'ar' ? 'العربية' : 'English',
                  () => ref.read(localeProvider.notifier).toggle(),
                ),
                _settingsRow('${profile['signOut']}', '', () => ref.read(sessionProvider.notifier).signOut()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ProSoftButton(
            label: '${profile['delete']}',
            danger: true,
            onTap: () => ref.read(sessionProvider.notifier).deleteAccount(),
          ),
        ],
      ),
    );
  }

  Widget _docRow(
    String label,
    String value, {
    required bool ok,
    bool pending = false,
    String? thumbUrl,
    required VoidCallback onTap,
    required String lang,
  }) {
    final hasThumb = thumbUrl != null && thumbUrl.isNotEmpty && !thumbUrl.toLowerCase().endsWith('.pdf');
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFFBF8F5),
          border: Border(bottom: BorderSide(color: Color(0xFFEFE7E1))),
        ),
        child: Row(
          children: [
            if (hasThumb) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 44, height: 44, child: MediaThumb(thumbUrl)),
              ),
              const SizedBox(width: 10),
            ] else if (thumbUrl != null && thumbUrl.isNotEmpty) ...[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Pro.plumSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Pro.plum, size: 22),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Pro.ink)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 11, color: Pro.muted)),
                ],
              ),
            ),
            Text(
              ok
                  ? (lang == 'ar' ? 'تمّت ✓' : 'Done ✓')
                  : pending
                      ? (lang == 'ar' ? 'ارفعي' : 'Upload')
                      : (lang == 'ar' ? 'محتاجة مراجعة' : 'Needs review'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ok ? Pro.plum : (pending ? Pro.pendingInk : Pro.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFEFE7E1))),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Pro.ink))),
            if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left, size: 18, color: Color(0xFFC9BCC4)),
          ],
        ),
      ),
    );
  }

  Future<void> _editNationalId(String lang) async {
    final m = Copy.of(lang)['svcMgmt'] as Map;
    final ctrl = TextEditingController(text: ref.read(sessionProvider).provider?.nationalId ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${m['nidEditTitle']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ProField(
                controller: ctrl,
                hint: '${m['nidEditHint']}',
                mono: true,
                keyboard: TextInputType.number,
                onChanged: (v) {
                  final n = toWesternDigits(v).replaceAll(RegExp(r'[^0-9]'), '');
                  final clipped = n.length > 14 ? n.substring(0, 14) : n;
                  if (clipped != ctrl.text) {
                    ctrl.value = TextEditingValue(text: clipped, selection: TextSelection.collapsed(offset: clipped.length));
                  }
                },
              ),
              const SizedBox(height: 16),
              ProPrimaryButton(
                label: '${m['saveShort']}',
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
      },
    );
    final raw = toWesternDigits(ctrl.text).replaceAll(RegExp(r'[^0-9]'), '');
    ctrl.dispose();
    if (ok != true || !mounted) return;
    if (raw.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m['nidInvalid']}')));
      return;
    }
    setState(() => busy = true);
    try {
      final r = await ref.read(repoProvider).patchPro({'nationalId': raw});
      if (r['provider'] is Map) {
        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      }
      tapSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m['nidSaved']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pick({bool face = false, bool idCard = false, bool fish = false}) async {
    final lang = langOf(ref);
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      uploadProgress = 0;
      uploadLabel = fish
          ? (lang == 'ar' ? 'جارٍ رفع الفيش…' : 'Uploading criminal record…')
          : idCard
              ? (lang == 'ar' ? 'جارٍ رفع البطاقة…' : 'Uploading ID…')
              : (lang == 'ar' ? 'جارٍ الرفع…' : 'Uploading…');
    });
    try {
      final r = idCard
          ? await ref.read(repoProvider).uploadProID(bytes, filename: file.name, onProgress: (f) {
              if (mounted) setState(() => uploadProgress = f);
            })
          : fish
              ? await ref.read(repoProvider).uploadProFish(bytes, filename: file.name, onProgress: (f) {
                  if (mounted) setState(() => uploadProgress = f);
                })
              : face
                  ? await ref.read(repoProvider).uploadProPhoto(bytes, filename: file.name, onProgress: (f) {
                      if (mounted) setState(() => uploadProgress = f);
                    })
                  : await ref.read(repoProvider).uploadProPortfolio(bytes, filename: file.name, onProgress: (f) {
                      if (mounted) setState(() => uploadProgress = f);
                    });
      if (r['provider'] is Map) {
        ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
      }
      await ref.read(sessionProvider.notifier).refreshMe();
      if (!face && !idCard && !fish) {
        unawaited(AppAnalytics.providerPortfolioUploaded());
      }
      if (mounted) {
        final p = Copy.of(lang)['pro'] as Map;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p['doneSavePhoto']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
      }
    } finally {
      if (mounted) setState(() { uploadProgress = null; uploadLabel = null; });
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
