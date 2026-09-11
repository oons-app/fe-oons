import 'package:flutter/material.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/data/service_catalog.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/copy.dart';

class ProServiceDraft {
  ProServiceDraft({
    required this.id,
    this.categoryId,
    Loc? name,
    this.catalogItemId,
    this.kind = 'standard',
    this.duration = 60,
    int priceEgp = 0,
    int travelEgp = 0,
    this.active = true,
    this.sizeFromSqm = 120,
    this.sizeToSqm = 150,
    this.workerCount = 1,
    Set<String>? excludedTaskIds,
    this.approvalState = '',
  })  : name = name ?? const Loc('', ''),
        priceCtrl = TextEditingController(text: priceEgp > 0 ? '$priceEgp' : ''),
        travelCtrl = TextEditingController(text: travelEgp > 0 ? '$travelEgp' : ''),
        sizeFromCtrl = TextEditingController(text: '$sizeFromSqm'),
        sizeToCtrl = TextEditingController(text: sizeToSqm == null ? '' : '$sizeToSqm'),
        excludedTaskIds = excludedTaskIds ?? {};

  final String id;
  String? categoryId;
  Loc name;
  String? catalogItemId;
  String kind;
  int duration;
  bool active;
  int sizeFromSqm;
  int? sizeToSqm;
  int workerCount;
  final Set<String> excludedTaskIds;
  // Server-owned; "" for a not-yet-saved draft. copyAsNew() resets it since a
  // duplicate is a brand-new service and always starts pending review again.
  final String approvalState;
  final TextEditingController priceCtrl;
  final TextEditingController travelCtrl;
  final TextEditingController sizeFromCtrl;
  final TextEditingController sizeToCtrl;

  bool get isCleaning => kind == 'cleaning';
  bool get isPendingApproval => approvalState == 'pending';

  int get priceEgp => int.tryParse(toWesternDigits(priceCtrl.text.trim())) ?? 0;
  int get travelEgp => int.tryParse(toWesternDigits(travelCtrl.text.trim())) ?? 0;

  void syncSizeFromControls() {
    sizeFromSqm = int.tryParse(toWesternDigits(sizeFromCtrl.text.trim())) ?? 0;
    final toRaw = toWesternDigits(sizeToCtrl.text.trim());
    sizeToSqm = toRaw.isEmpty ? null : int.tryParse(toRaw);
  }

  void dispose() {
    priceCtrl.dispose();
    travelCtrl.dispose();
    sizeFromCtrl.dispose();
    sizeToCtrl.dispose();
  }

  ProServiceDraft copyAsNew(String newId) {
    syncSizeFromControls();
    return ProServiceDraft(
      id: newId,
      categoryId: categoryId,
      name: name,
      catalogItemId: catalogItemId,
      kind: kind,
      duration: duration,
      priceEgp: priceEgp,
      travelEgp: travelEgp,
      active: false, // duplicates start paused
      sizeFromSqm: sizeFromSqm,
      sizeToSqm: sizeToSqm,
      workerCount: workerCount,
      excludedTaskIds: Set.of(excludedTaskIds),
    );
  }

  Map<String, dynamic> toApiItem() {
    syncSizeFromControls();
    final en = name.en.isNotEmpty ? name.en : name.ar;
    final ar = name.ar.isNotEmpty ? name.ar : name.en;
    final idNum = int.tryParse(id);
    return {
      if (idNum != null) 'id': idNum,
      'name': {'en': en, 'ar': ar},
      'durationMin': duration,
      'price': priceEgp * 100,
      'categoryId': categoryId,
      if (catalogItemId != null && catalogItemId!.isNotEmpty) 'catalogItemId': catalogItemId,
      'kind': isCleaning ? 'cleaning' : 'standard',
      'active': active,
      if (travelEgp > 0) 'travelFee': travelEgp * 100,
      if (isCleaning) ...{
        'sizeFromSqm': sizeFromSqm,
        if (sizeToSqm != null) 'sizeToSqm': sizeToSqm,
        'workerCount': workerCount,
        'excludedTaskIds': excludedTaskIds.toList(),
      },
    };
  }
}

Future<ProServiceDraft?> showProServiceEditorSheet({
  required BuildContext context,
  required String lang,
  required List<Map<String, dynamic>> approvedCategories,
  required Repo repo,
  ProServiceDraft? existing,
  required Set<String> usedCategoryIds,
  Map<String, dynamic>? catalog,
  double commissionRate = 0.10,
}) {
  return showModalBottomSheet<ProServiceDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pro.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => _ProServiceEditorSheet(
      lang: lang,
      approvedCategories: approvedCategories,
      repo: repo,
      existing: existing,
      usedCategoryIds: usedCategoryIds,
      catalog: catalog ?? const {},
      commissionRate: commissionRate,
    ),
  );
}

class _ProServiceEditorSheet extends StatefulWidget {
  const _ProServiceEditorSheet({
    required this.lang,
    required this.approvedCategories,
    required this.repo,
    required this.existing,
    required this.usedCategoryIds,
    required this.catalog,
    required this.commissionRate,
  });

  final String lang;
  final List<Map<String, dynamic>> approvedCategories;
  final Repo repo;
  final ProServiceDraft? existing;
  final Set<String> usedCategoryIds;
  final Map<String, dynamic> catalog;
  final double commissionRate;

  @override
  State<_ProServiceEditorSheet> createState() => _ProServiceEditorSheetState();
}

class _ProServiceEditorSheetState extends State<_ProServiceEditorSheet> {
  late ProServiceDraft draft;
  List<Map<String, dynamic>> nameChips = [];
  bool loadingNames = false;
  bool deleteRequested = false;
  String? requestNameBusy;

  Map get m => Copy.of(widget.lang)['svcMgmt'] as Map;
  bool get isEdit => widget.existing != null;
  bool get ar => widget.lang == 'ar';

  List<Map<String, dynamic>> get cleaningRooms {
    final raw = widget.catalog['cleaningRooms'];
    if (raw is! List) return const [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  int get totalTasks {
    var n = 0;
    for (final r in cleaningRooms) {
      final tasks = r['tasks'];
      if (tasks is List) n += tasks.length;
    }
    return n == 0 ? 18 : n;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    draft = e != null
        ? ProServiceDraft(
            id: e.id,
            categoryId: e.categoryId,
            name: e.name,
            catalogItemId: e.catalogItemId,
            kind: e.kind,
            duration: e.duration,
            priceEgp: e.priceEgp,
            travelEgp: e.travelEgp,
            active: e.active,
            sizeFromSqm: e.sizeFromSqm,
            sizeToSqm: e.sizeToSqm,
            workerCount: e.workerCount,
            excludedTaskIds: Set.of(e.excludedTaskIds),
          )
        : ProServiceDraft(id: 'new');
    if (draft.categoryId != null) {
      _applyKindForCategory(draft.categoryId!);
      _loadNameChips(draft.categoryId!);
    }
  }

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  String _catLabel(Map c) {
    final n = c['name'];
    if (n is Map) return Loc.fromJson(n).of(widget.lang);
    return '${n ?? c['slug'] ?? ''}';
  }

  String _catId(Map c) => '${c['categoryId'] ?? c['id'] ?? ''}';

  bool _isCleaningCategory(Map c) {
    final kind = '${c['kind'] ?? ''}';
    if (kind == 'cleaning') return true;
    final v = c['vertical'];
    if (v == 2 || v == '2' || '$v' == 'cleaning') return true;
    final slug = '${c['slug'] ?? ''}'.toLowerCase();
    return slug.contains('clean') || slug.contains('تنظيف');
  }

  void _applyKindForCategory(String id) {
    final cat = widget.approvedCategories.cast<Map?>().firstWhere(
          (c) => c != null && _catId(c) == id,
          orElse: () => null,
        );
    final cleaning = cat != null && _isCleaningCategory(cat);
    draft.kind = cleaning ? 'cleaning' : 'standard';
    if (cleaning && draft.workerCount < 1) draft.workerCount = 1;
  }

  Future<void> _loadNameChips(String categoryId) async {
    setState(() => loadingNames = true);
    List<Map<String, dynamic>> children = [];
    try {
      children = await widget.repo.categories(parent: categoryId, activeOnly: true);
    } catch (_) {}
    if (!mounted) return;
    final base = widget.approvedCategories.where((c) => _catId(c) == categoryId).toList();
    final chips = <Map<String, dynamic>>[];
    if (children.isNotEmpty) {
      chips.addAll(children);
    } else if (base.isNotEmpty) {
      chips.add(base.first);
    }
    // Prefer catalog nameCatalog filtered by parent when present.
    final nc = widget.catalog['nameCatalog'];
    if (nc is List) {
      final fromCatalog = nc
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => '${e['parentId']}' == categoryId || '${e['id']}' == categoryId)
          .toList();
      if (fromCatalog.isNotEmpty) {
        chips
          ..clear()
          ..addAll(fromCatalog);
      }
    }
    setState(() {
      nameChips = chips;
      loadingNames = false;
    });
  }

  Future<void> _requestNewName() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pro.card,
        title: Text('${m['requestNameTitle'] ?? (ar ? 'اطلبي اسم خدمة جديدة' : 'Request a service name')}'),
        content: ProField(controller: ctrl, hint: ar ? 'اسم الخدمة' : 'Service name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('${m['deleteNo']}')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'أرسلي' : 'Send')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty || draft.categoryId == null) return;
    setState(() => requestNameBusy = name);
    try {
      await widget.repo.proRequestCatalogName(
        categoryId: draft.categoryId!,
        suggestedAr: name,
        suggestedEn: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${m['requestNameSent'] ?? (ar ? 'اتبعت الطلب لفريق أُنس' : 'Request sent to Oons')}')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ar ? 'مقدرناش نبعت الطلب' : 'Could not send request')),
        );
      }
    } finally {
      if (mounted) setState(() => requestNameBusy = null);
    }
  }

  bool get canSave {
    draft.syncSizeFromControls();
    final nameOk = draft.name.of(widget.lang).trim().isNotEmpty || draft.name.en.trim().isNotEmpty || draft.name.ar.trim().isNotEmpty;
    if (draft.categoryId == null || !nameOk || draft.priceEgp <= 0 || draft.duration < 15) return false;
    if (draft.isCleaning) {
      if (draft.sizeFromSqm <= 0) return false;
      if (draft.sizeToSqm != null && draft.sizeToSqm! < draft.sizeFromSqm) return false;
      if (draft.workerCount < 1 || draft.workerCount > 3) return false;
    }
    return true;
  }

  Widget _stepLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Pro.muted)),
      );

  Widget _chip({required String label, required bool on, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? Pro.ink : Pro.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? Pro.ink : Pro.line),
        ),
        child: Text(
          on ? '$label ✓' : label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : const Color(0xFF4E434A)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final price = draft.priceEgp;
    final travel = draft.travelEgp;
    final net = netAfterCommission(priceEgp: price, travelEgp: travel, commissionRate: widget.commissionRate);
    final included = totalTasks - draft.excludedTaskIds.length;
    final suggested = draft.isCleaning
        ? suggestCleaningDurationMin(sizeFromSqm: int.tryParse(toWesternDigits(draft.sizeFromCtrl.text)) ?? draft.sizeFromSqm, workers: draft.workerCount)
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Pro.lineSoft, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? '${m['sheetEdit']}' : '${m['sheetAdd']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Pro.muted)),
              ],
            ),
            const SizedBox(height: 12),
            _stepLabel('${m['stepCat']}'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: widget.approvedCategories.map((c) {
                final id = _catId(c);
                final on = draft.categoryId == id;
                return _chip(
                  label: _catLabel(c),
                  on: on,
                  onTap: () {
                    setState(() {
                      draft.categoryId = id;
                      draft.name = const Loc('', '');
                      draft.catalogItemId = null;
                      _applyKindForCategory(id);
                    });
                    _loadNameChips(id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (!draft.isCleaning) ...[
              _stepLabel('${m['stepName']}'),
              if (loadingNames)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
              else if (nameChips.isEmpty)
                Text(ar ? 'اختاري تخصص الأول' : 'Pick a specialty first', style: const TextStyle(fontSize: 13, color: Pro.muted))
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    ...nameChips.map((c) {
                      final n = c['name'] is Map ? Loc.fromJson(c['name'] as Map) : Loc('${c['name']}', '${c['name']}');
                      final label = n.of(widget.lang);
                      final on = draft.name.of(widget.lang) == label || (draft.name.en == n.en && n.en.isNotEmpty);
                      return _chip(
                        label: label,
                        on: on,
                        onTap: () => setState(() {
                          draft.name = n;
                          draft.catalogItemId = '${c['id'] ?? c['slug'] ?? ''}';
                        }),
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: requestNameBusy != null ? null : _requestNewName,
                child: Text('${m['requestName'] ?? (ar ? 'اطلبي اسم خدمة جديدة' : 'Request a new service name')}'),
              ),
              const SizedBox(height: 12),
              _stepLabel('${m['stepDur']}'),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: serviceDurations.map((min) {
                  final on = draft.duration == min;
                  return InkWell(
                    onTap: () => setState(() => draft.duration = min),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: on ? Pro.plum : Pro.chip, borderRadius: BorderRadius.circular(10)),
                      child: Text('$min', style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : Pro.muted)),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              _stepLabel('${m['stepSize'] ?? (ar ? '٣ · مساحة الوحدة وعدد العاملات' : '3 · Unit size & workers')}'),
              Text(ar ? 'من (م²)' : 'From (m²)', style: const TextStyle(fontSize: 12, color: Pro.muted)),
              const SizedBox(height: 6),
              ProField(
                controller: draft.sizeFromCtrl,
                hint: '120',
                mono: true,
                keyboard: TextInputType.number,
                onChanged: (v) {
                  draft.sizeFromCtrl.value = TextEditingValue(
                    text: normalizeMoneyInput(v),
                    selection: TextSelection.collapsed(offset: normalizeMoneyInput(v).length),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              Text(ar ? 'إلى (م²) — فاضي = أكبر من' : 'To (m²) — empty = no upper bound', style: const TextStyle(fontSize: 12, color: Pro.muted)),
              const SizedBox(height: 6),
              ProField(
                controller: draft.sizeToCtrl,
                hint: '150',
                mono: true,
                keyboard: TextInputType.number,
                onChanged: (v) {
                  final n = toWesternDigits(v).replaceAll(RegExp(r'[^0-9]'), '');
                  draft.sizeToCtrl.value = TextEditingValue(text: n, selection: TextSelection.collapsed(offset: n.length));
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [1, 2, 3].map((w) {
                  return _chip(
                    label: pluralWorkers(w, ar: ar),
                    on: draft.workerCount == w,
                    onTap: () => setState(() => draft.workerCount = w),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _stepLabel('${m['stepDur']}'),
              if (suggested != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${m['suggestedDur'] ?? (ar ? 'مقترح' : 'Suggested')}: ${toArabicDigits(suggested)} ${ar ? 'د' : 'min'}',
                    style: const TextStyle(fontSize: 12, color: Pro.muted),
                  ),
                ),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: serviceDurations.map((min) {
                  final on = draft.duration == min;
                  return InkWell(
                    onTap: () => setState(() => draft.duration = min),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: on ? Pro.plum : Pro.chip, borderRadius: BorderRadius.circular(10)),
                      child: Text('$min', style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : Pro.muted)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Cleaning uses category name as service name.
              Builder(builder: (_) {
                final cat = widget.approvedCategories.cast<Map?>().firstWhere(
                      (c) => c != null && _catId(c) == draft.categoryId,
                      orElse: () => null,
                    );
                if (cat != null) {
                  final n = cat['name'] is Map ? Loc.fromJson(cat['name'] as Map) : Loc('${cat['name']}', '${cat['name']}');
                  draft.name = n;
                }
                return const SizedBox.shrink();
              }),
            ],
            const SizedBox(height: 18),
            _stepLabel(draft.isCleaning ? '${m['stepTierPrice'] ?? (ar ? '٥ · سعر الشريحة' : '5 · Tier price')}' : '${m['stepPrice']}'),
            Text('${m['priceLabel']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(
              controller: draft.priceCtrl,
              hint: '350',
              mono: true,
              keyboard: TextInputType.number,
              onChanged: (v) {
                final n = normalizeMoneyInput(v);
                draft.priceCtrl.value = TextEditingValue(text: n, selection: TextSelection.collapsed(offset: n.length));
                setState(() {});
              },
            ),
            if (!draft.isCleaning) ...[
              const SizedBox(height: 12),
              Text('${m['travelOptional']}', style: const TextStyle(fontSize: 12, color: Pro.muted)),
              const SizedBox(height: 6),
              ProField(
                controller: draft.travelCtrl,
                hint: '0',
                mono: true,
                keyboard: TextInputType.number,
                onChanged: (v) {
                  final n = normalizeMoneyInput(v);
                  draft.travelCtrl.value = TextEditingValue(text: n, selection: TextSelection.collapsed(offset: n.length));
                  setState(() {});
                },
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Pro.plumSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(
                ar
                    ? 'العميلة بتدفع ${toArabicDigits(price + travel)} ج.م · بيوصلك ${toArabicDigits(net)} ج.م بعد عمولة أُنس ${(widget.commissionRate * 100).round()}٪'
                    : 'Client pays ${price + travel} EGP · you get $net after Oons ${(widget.commissionRate * 100).round()}% fee',
                style: const TextStyle(fontSize: 13, height: 1.4, color: Pro.ink),
              ),
            ),
            if (draft.isCleaning) ...[
              const SizedBox(height: 18),
              _stepLabel(
                '${m['stepTasks'] ?? (ar ? '٦ · الشغل اللي الباقة شاملته' : '6 · Package tasks')} · ${pluralTasks(included, ar: ar)}',
              ),
              ...cleaningRooms.map((room) {
                final tasks = ((room['tasks'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                final roomName = room['name'] is Map ? Loc.fromJson(room['name'] as Map).of(widget.lang) : '${room['name']}';
                final onCount = tasks.where((t) => !draft.excludedTaskIds.contains('${t['id']}')).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: Pro.cardDec(radius: Pro.rMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(roomName, style: const TextStyle(fontWeight: FontWeight.w700, color: Pro.ink))),
                            Text('${toArabicDigits(onCount)}/${toArabicDigits(tasks.length)}', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Pro.muted)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...tasks.map((t) {
                          final id = '${t['id']}';
                          final label = t['name'] is Map ? Loc.fromJson(t['name'] as Map).of(widget.lang) : '${t['name']}';
                          final on = !draft.excludedTaskIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: on,
                            activeColor: Pro.plum,
                            title: Text(label, style: const TextStyle(fontSize: 13)),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                draft.excludedTaskIds.remove(id);
                              } else {
                                draft.excludedTaskIds.add(id);
                              }
                            }),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['showClients']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: draft.active,
              activeColor: Pro.plum,
              onChanged: (v) => setState(() => draft.active = v),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  deleteRequested = true;
                  Navigator.pop(context, ProServiceDraft(id: draft.id, categoryId: '__delete__'));
                },
                child: Text('${m['deleteService']}', style: const TextStyle(color: Pro.danger)),
              ),
            ],
            const SizedBox(height: 16),
            ProPrimaryButton(
              label: canSave ? (isEdit ? '${m['save']}' : '${m['addService']}') : '${m['needNamePrice']}',
              enabled: canSave,
              onTap: () {
                draft.syncSizeFromControls();
                Navigator.pop(context, draft);
              },
            ),
          ],
        ),
      ),
    );
  }
}
