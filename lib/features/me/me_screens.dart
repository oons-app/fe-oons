import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/open_external.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/data/geocode.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/me/delivery_map.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing, this.returnResult = false});
  final Address? existing;
  /// When true (opened from booking), pop with the saved [Address] so the book screen can select it.
  final bool returnResult;
  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  late final label = TextEditingController(text: widget.existing?.label.en ?? '');
  late final line1 = TextEditingController(text: widget.existing?.line1.of('ar') ?? widget.existing?.line1.en ?? '');
  late final reachNotes = TextEditingController(text: widget.existing?.reachNotes.of('ar') ?? widget.existing?.reachNotes.en ?? '');
  final search = TextEditingController();
  late String area = widget.existing?.area ?? 'madinaty';
  late String city = areaIsGiza(widget.existing?.area ?? 'madinaty') ? 'giza' : 'cairo';
  late bool isDefault = widget.existing?.isDefault ?? false;
  late double lat = (widget.existing?.lat ?? 0) != 0 ? widget.existing!.lat : coordsForArea(widget.existing?.area ?? 'madinaty').$1;
  late double lng = (widget.existing?.lng ?? 0) != 0 ? widget.existing!.lng : coordsForArea(widget.existing?.area ?? 'madinaty').$2;
  final mapKey = GlobalKey<DeliveryPinMapState>();
  List<GeoHit> hits = [];
  bool busy = false;
  bool streetDirty = false;
  String? labelErr;
  String? streetErr;
  Timer? searchWait;
  Timer? reverseWait;

  @override
  void dispose() {
    searchWait?.cancel();
    reverseWait?.cancel();
    label.dispose();
    line1.dispose();
    reachNotes.dispose();
    search.dispose();
    super.dispose();
  }

  void _onMapMoved(LatLng p) {
    lat = p.latitude;
    lng = p.longitude;
    final next = areaFromCoords(lat, lng);
    setState(() {
      area = next;
      city = areaIsGiza(next) ? 'giza' : 'cairo';
    });
    reverseWait?.cancel();
    reverseWait = Timer(const Duration(milliseconds: 550), _reverse);
  }

  Future<void> _reverse() async {
    try {
      final hit = await ref.read(repoProvider).reverseGeocode(lat, lng);
      if (!mounted || hit == null) return;
      if (!streetDirty && hit.line.trim().isNotEmpty) {
        line1.text = hit.line;
      }
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    searchWait?.cancel();
    if (q.trim().length < 2) {
      setState(() => hits = []);
      return;
    }
    searchWait = Timer(const Duration(milliseconds: 400), () async {
      try {
        final list = await ref.read(repoProvider).searchPlaces(q.trim());
        if (mounted) setState(() => hits = list);
      } catch (_) {
        if (mounted) setState(() => hits = []);
      }
    });
  }

  Future<void> _myLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      streetDirty = false;
      mapKey.currentState?.moveTo(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _goToHit(GeoHit hit) {
    search.clear();
    setState(() {
      hits = [];
      streetDirty = false;
      if (hit.line.trim().isNotEmpty) line1.text = hit.line;
    });
    mapKey.currentState?.moveTo(hit.lat, hit.lng);
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(
              title: '${widget.existing == null ? p['addAddress'] : p['editAddress']}',
              onBack: () {
                if (widget.returnResult) {
                  Navigator.of(context).pop();
                } else {
                  context.pop();
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ClientKicker('${p['mapSearch']}'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
                    child: TextField(
                      controller: search,
                      onChanged: _search,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '${p['mapSearchPh']}',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                  ...hits.map((h) => InkWell(
                        onTap: () => _goToHit(h),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule)), color: Client.card),
                          child: Text(h.label, style: const TextStyle(fontSize: 13, height: 1.35)),
                        ),
                      )),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                    child: DeliveryPinMap(key: mapKey, lat: lat, lng: lng, onMoved: _onMapMoved),
                  ),
                  const SizedBox(height: 8),
                  Text('${p['pinHint']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.4)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: ClientGhostButton(label: '${p['myLocation']}', onTap: _myLocation)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClientGhostButton(
                          label: '${p['openGmaps']}',
                          onTap: () => openExternal(googleMapsUrl(lat, lng)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClientFieldLabel('${p['label']}', required: true),
                  const SizedBox(height: 8),
                  _box(label, errorText: labelErr, onChanged: (_) {
                    if (labelErr != null) setState(() => labelErr = null);
                  }),
                  const SizedBox(height: 16),
                  ClientFieldLabel('${p['street']}', required: true),
                  const SizedBox(height: 8),
                  _box(line1, lines: 2, errorText: streetErr, onChanged: (_) {
                    streetDirty = true;
                    if (streetErr != null) setState(() => streetErr = null);
                  }),
                  const SizedBox(height: 16),
                  ClientKicker('${p['reachNotes']}'),
                  const SizedBox(height: 6),
                  Text('${p['reachNotesHint']}', style: const TextStyle(fontSize: 12, color: Client.muted, height: 1.45)),
                  const SizedBox(height: 8),
                  _box(reachNotes, lines: 4),
                  const SizedBox(height: 16),
                  ClientKicker('${p['area']}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allCatalogAreaIds().map((id) {
                      final on = area == id;
                      return InkWell(
                        onTap: () {
                          final c = coordsForArea(id);
                          streetDirty = false;
                          setState(() {
                            area = id;
                            city = areaIsGiza(id) ? 'giza' : 'cairo';
                          });
                          mapKey.currentState?.moveTo(c.$1, c.$2);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: on ? Client.plum : Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                          child: Text(areaName(id, lang), style: TextStyle(fontWeight: FontWeight.w700, color: on ? Client.bg : Client.ink)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ClientKicker(lang == 'ar' ? 'المدينة' : 'City'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ['cairo', lang == 'ar' ? 'القاهرة' : 'Cairo'],
                      ['giza', lang == 'ar' ? 'الجيزة' : 'Giza'],
                    ].map((row) {
                      final on = city == row[0];
                      return InkWell(
                        onTap: () => setState(() => city = row[0]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: on ? Client.plum : Client.card, border: Border.all(color: Client.ink, width: Client.rule)),
                          child: Text(row[1], style: TextStyle(fontWeight: FontWeight.w700, color: on ? Client.bg : Client.ink)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => isDefault = !isDefault),
                    child: Row(
                      children: [
                        Container(width: 18, height: 18, decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: isDefault ? Client.plum : Colors.transparent)),
                        const SizedBox(width: 10),
                        Text('${p['setDefault']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClientPrimaryButton(
                    label: '${p['saveAddress']}',
                    enabled: !busy,
                    onTap: () async {
                      final labelEmpty = label.text.trim().isEmpty;
                      final streetEmpty = line1.text.trim().isEmpty;
                      if (labelEmpty || streetEmpty) {
                        setState(() {
                          labelErr = labelEmpty ? '${p['labelRequired']}' : null;
                          streetErr = streetEmpty ? '${p['streetRequired']}' : null;
                        });
                        return;
                      }
                      setState(() {
                        busy = true;
                        labelErr = null;
                        streetErr = null;
                      });
                      try {
                        final repo = ref.read(repoProvider);
                        final cityName = city == 'giza' ? (lang == 'ar' ? 'الجيزة' : 'Giza') : (lang == 'ar' ? 'القاهرة' : 'Cairo');
                        final UserMe u;
                        if (widget.existing == null) {
                          u = await repo.createAddress(
                            label: label.text.trim(),
                            line1: line1.text.trim(),
                            reachNotes: reachNotes.text,
                            area: area,
                            city: cityName,
                            isDefault: isDefault,
                            lat: lat,
                            lng: lng,
                          );
                        } else {
                          u = await repo.patchAddress(widget.existing!.id, {
                            'label': label.text.trim(),
                            'line1': line1.text.trim(),
                            'reachNotes': reachNotes.text,
                            'area': area,
                            'city': cityName,
                            'isDefault': isDefault,
                            'lat': lat,
                            'lng': lng,
                          });
                        }
                        ref.read(sessionProvider.notifier).setUser(u);
                        Address? saved;
                        if (widget.existing != null) {
                          for (final a in u.addresses) {
                            if (a.id == widget.existing!.id) {
                              saved = a;
                              break;
                            }
                          }
                        } else {
                          final labelKey = label.text.trim().toLowerCase();
                          final lineKey = line1.text.trim().toLowerCase();
                          for (final a in u.addresses.reversed) {
                            if (a.label.of('en').trim().toLowerCase() == labelKey ||
                                a.label.of('ar').trim().toLowerCase() == labelKey ||
                                a.line1.of('en').trim().toLowerCase() == lineKey ||
                                a.line1.of('ar').trim().toLowerCase() == lineKey) {
                              saved = a;
                              break;
                            }
                          }
                          saved ??= u.addresses.isNotEmpty ? u.addresses.last : null;
                        }
                        if (!mounted) return;
                        if (widget.returnResult) {
                          Navigator.of(context).pop(saved);
                        } else {
                          context.pop(saved);
                        }
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
          ],
        ),
      ),
    );
  }

  Widget _box(TextEditingController c, {int lines = 1, ValueChanged<String>? onChanged, String? errorText}) {
    final hasErr = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: hasErr ? T.danger : Client.ink, width: Client.rule), color: Client.card),
          child: TextField(
            controller: c,
            minLines: lines,
            maxLines: lines,
            onChanged: onChanged,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          ),
        ),
        if (hasErr)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(errorText, style: const TextStyle(color: T.danger, fontSize: 12.5, height: 1.35)),
          ),
      ],
    );
  }
}

class InstructionsScreen extends ConsumerStatefulWidget {
  const InstructionsScreen({super.key});
  @override
  ConsumerState<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends ConsumerState<InstructionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final list = ref.watch(sessionProvider).user?.instructions ?? [];
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p['instructions']}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(lang == 'ar' ? 'لسه مفيش تعليمات محفوظة.' : 'No saved instructions yet.', style: const TextStyle(color: Client.muted)),
                    ),
                  ...list.map((i) => Container(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Client.ink, width: Client.rule))),
                        child: ListTile(
                          title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(i.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () async {
                            await context.push('/me/instructions/${i.id}', extra: i);
                            if (mounted) await ref.read(sessionProvider.notifier).refreshMe();
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: T.danger),
                            onPressed: () async {
                              try {
                                final u = await ref.read(repoProvider).deleteInstruction(i.id);
                                ref.read(sessionProvider.notifier).setUser(u);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                                  lang == 'ar' ? 'اتشالت.' : 'Deleted.',
                                )));
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, lang))));
                              }
                            },
                          ),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClientPrimaryButton(
                      label: '${p['addInstr']}',
                      onTap: () async {
                        await context.push('/me/instructions/new');
                        if (mounted) await ref.read(sessionProvider.notifier).refreshMe();
                      },
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
}

class InstructionFormScreen extends ConsumerStatefulWidget {
  const InstructionFormScreen({super.key, this.existing, this.id, this.returnResult = false});
  final Instruction? existing;
  final String? id;
  final bool returnResult;
  @override
  ConsumerState<InstructionFormScreen> createState() => _InstructionFormScreenState();
}

class _InstructionFormScreenState extends ConsumerState<InstructionFormScreen> {
  late final title = TextEditingController(text: widget.existing?.title ?? '');
  late final body = TextEditingController(text: widget.existing?.body ?? '');
  bool busy = false;
  String? err;

  Instruction? get _hit {
    if (widget.existing != null) return widget.existing;
    final id = widget.id;
    if (id == null || id == 'new') return null;
    final list = ref.read(sessionProvider).user?.instructions ?? [];
    for (final i in list) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.existing != null) return;
      await ref.read(sessionProvider.notifier).refreshMe();
      final hit = _hit;
      if (hit != null && mounted && title.text.isEmpty && body.text.isEmpty) {
        title.text = hit.title;
        body.text = hit.body;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClientBackHeader(
              title: '${p['addInstr']}',
              onBack: () {
                if (widget.returnResult) {
                  Navigator.of(context).pop();
                } else {
                  context.pop();
                }
              },
            ),
            const SizedBox(height: 16),
            ClientKicker('${p['instrTitle']}'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
              child: TextField(controller: title, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))),
            ),
            const SizedBox(height: 16),
            ClientKicker('${p['instrBody']}'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
              child: TextField(controller: body, minLines: 4, maxLines: 6, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(err!, style: const TextStyle(color: T.danger))),
            const SizedBox(height: 24),
            ClientPrimaryButton(
              label: '${p['saveInstrBtn']}',
              enabled: !busy,
              onTap: () async {
                if (body.text.trim().isEmpty) {
                  setState(() => err = lang == 'ar' ? 'اكتبي التعليمات الأول.' : 'Write the instruction first.');
                  return;
                }
                setState(() {
                  busy = true;
                  err = null;
                });
                try {
                  final repo = ref.read(repoProvider);
                  final existing = _hit;
                  final UserMe u;
                  if (existing == null) {
                    u = await repo.createInstruction(title: title.text, body: body.text);
                  } else {
                    u = await repo.patchInstruction(existing.id, title: title.text, body: body.text);
                  }
                  ref.read(sessionProvider.notifier).setUser(u);
                  Instruction? saved;
                  if (existing != null) {
                    for (final i in u.instructions) {
                      if (i.id == existing.id) {
                        saved = i;
                        break;
                      }
                    }
                  } else {
                    saved = u.instructions.isNotEmpty ? u.instructions.last : null;
                    for (final i in u.instructions.reversed) {
                      if (i.body.trim() == body.text.trim()) {
                        saved = i;
                        break;
                      }
                    }
                  }
                  if (!mounted) return;
                  if (widget.returnResult) {
                    Navigator.of(context).pop(saved);
                  } else {
                    context.pop(saved);
                  }
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
    );
  }
}

class ClientIdentityScreen extends ConsumerStatefulWidget {
  const ClientIdentityScreen({super.key});
  @override
  ConsumerState<ClientIdentityScreen> createState() => _ClientIdentityScreenState();
}

class _ClientIdentityScreenState extends ConsumerState<ClientIdentityScreen> {
  late final TextEditingController nid;
  bool busy = false;
  String? err;
  String? okMsg;

  @override
  void initState() {
    super.initState();
    nid = TextEditingController(text: ref.read(sessionProvider).user?.nationalId ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refreshMe();
    });
  }

  @override
  void dispose() {
    nid.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool idPhoto}) async {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    setState(() {
      busy = true;
      err = null;
      okMsg = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final repo = ref.read(repoProvider);
      final u = idPhoto ? await repo.uploadClientID(bytes) : await repo.uploadClientPhoto(bytes);
      ref.read(sessionProvider.notifier).setUser(u);
      if (mounted) setState(() => okMsg = '${p['identitySaved']}');
    } catch (e) {
      if (mounted) setState(() => err = friendlyError(e, lang));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveNid() async {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final digits = nid.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      setState(() => err = '${p['nationalIdRequired']}');
      return;
    }
    if (digits.length != 14) {
      setState(() => err = '${p['nationalIdInvalid']}');
      return;
    }
    setState(() {
      busy = true;
      err = null;
      okMsg = null;
    });
    try {
      await ref.read(sessionProvider.notifier).patchMe(nationalId: digits);
      if (mounted) setState(() => okMsg = '${p['identitySaved']}');
    } catch (e) {
      if (mounted) setState(() => err = friendlyError(e, lang));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final p = Copy.of(lang)['profile'] as Map;
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: Column(
          children: [
            ClientBackHeader(title: '${p['identity']}', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('${p['identityTitle']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Client.ink)),
                  const SizedBox(height: 8),
                  Text('${p['identityBody']}', style: const TextStyle(fontSize: 14, height: 1.5, color: Client.body)),
                  const SizedBox(height: 24),
                  ClientFieldLabel('${p['profilePhoto']}', required: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.sand),
                        clipBehavior: Clip.hardEdge,
                        child: user?.hasPhoto == true
                            ? MediaThumb(user!.photo!)
                            : Center(child: Text(user?.initials.of(lang) ?? '·', style: const TextStyle(fontFamily: T.mono, fontWeight: FontWeight.w600))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ClientGhostButton(
                          label: user?.hasPhoto == true ? '${p['changePhoto']}' : '${p['uploadPhoto']}',
                          onTap: busy ? null : () => _pick(idPhoto: false),
                        ),
                      ),
                    ],
                  ),
                  if (user?.hasPhoto == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${p['photoOnFile']}', style: const TextStyle(fontSize: 12, color: Client.oliveInk)),
                    ),
                  const SizedBox(height: 24),
                  ClientFieldLabel('${p['nationalId']}', required: true),
                  const SizedBox(height: 8),
                  ClientTextField(
                    controller: nid,
                    keyboardType: TextInputType.number,
                    hint: '${p['nationalIdPh']}',
                    errorText: err != null && (err == p['nationalIdRequired'] || err == p['nationalIdInvalid']) ? err : null,
                    onChanged: (_) {
                      if (err != null) setState(() => err = null);
                    },
                  ),
                  const SizedBox(height: 10),
                  ClientGhostButton(label: '${p['saveIdentity']}', onTap: busy ? null : _saveNid),
                  const SizedBox(height: 24),
                  ClientFieldLabel('${p['idPhoto']}', required: true),
                  const SizedBox(height: 10),
                  if (user?.hasIdPhoto == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
                          child: MediaThumb(user!.idPhotoUrl!),
                        ),
                      ),
                    ),
                  ClientGhostButton(
                    label: user?.hasIdPhoto == true ? '${p['changeId']}' : '${p['uploadId']}',
                    onTap: busy ? null : () => _pick(idPhoto: true),
                  ),
                  if (user?.hasIdPhoto == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${p['idOnFile']}', style: const TextStyle(fontSize: 12, color: Client.oliveInk)),
                    ),
                  if (err != null && err != p['nationalIdRequired'] && err != p['nationalIdInvalid'])
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(err!, style: const TextStyle(color: T.danger, fontSize: 13)),
                    ),
                  if (okMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(okMsg!, style: const TextStyle(color: Client.oliveInk, fontSize: 13)),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularProgressIndicator(color: Client.plum)),
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
